#!/bin/bash

echo "⏳ Waiting for MySQL to be fully ready..."

max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if kubectl exec -n ml-infrastructure deployment/mysql -- \
       mysqladmin ping -h localhost -uroot -prootpass123 2>/dev/null | grep -q "mysqld is alive"; then
        echo "✅ MySQL is ready!"
        
        # Создать базы данных
        echo "Creating databases..."
        kubectl exec -n ml-infrastructure deployment/mysql -- \
          mysql -uroot -prootpass123 -e "CREATE DATABASE IF NOT EXISTS mlpipeline;"
        kubectl exec -n ml-infrastructure deployment/mysql -- \
          mysql -uroot -prootpass123 -e "CREATE DATABASE IF NOT EXISTS katib;"
        
        echo "✅ Databases created!"
        exit 0
    fi
    
    echo "  Attempt $((attempt+1))/$max_attempts - MySQL still initializing..."
    sleep 3
    attempt=$((attempt+1))
done

echo "❌ MySQL did not become ready in time"
exit 1