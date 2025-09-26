#!/bin/bash

echo "⏳ Waiting for MySQL to be fully ready..."

max_attempts=120
attempt=0
sleep_time=5

# Wait for pod to be running
while [ $attempt -lt 60 ]; do
    POD_STATUS=$(kubectl get pods -n ml-infrastructure -l app=mysql -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    
    if [ "$POD_STATUS" = "Running" ]; then
        echo "✅ MySQL pod is running, checking database availability..."
        break
    fi
    
    echo "  Attempt $((attempt+1))/60 - Waiting for MySQL pod to start (Status: ${POD_STATUS:-Unknown})..."
    sleep $sleep_time
    attempt=$((attempt+1))
done

if [ $attempt -eq 60 ]; then
    echo "❌ MySQL pod did not start in time"
    exit 1
fi

# Wait for MySQL to be ready to accept connections
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if kubectl exec -n ml-infrastructure deployment/mysql -- \
       sh -c 'mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD' 2>/dev/null | grep -q "mysqld is alive"; then
        echo "✅ MySQL is ready and accepting connections!"
        
        # Create databases
        echo "Creating databases..."
        
        kubectl exec -n ml-infrastructure deployment/mysql -- \
          sh -c 'mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS mlpipeline;"' 2>/dev/null
        
        kubectl exec -n ml-infrastructure deployment/mysql -- \
          sh -c 'mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS katib;"' 2>/dev/null
        
        # Verify databases were created
        DATABASES=$(kubectl exec -n ml-infrastructure deployment/mysql -- \
          sh -c 'mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;"' 2>/dev/null)
        
        if echo "$DATABASES" | grep -q "mlpipeline" && echo "$DATABASES" | grep -q "katib"; then
            echo "✅ Databases created successfully!"
            exit 0
        else
            echo "⚠️  Database creation may have failed, retrying..."
        fi
    fi
    
    echo "  Attempt $((attempt+1))/$max_attempts - MySQL still initializing..."
    sleep $sleep_time
    attempt=$((attempt+1))
done

echo "❌ MySQL did not become ready in time"
exit 1
