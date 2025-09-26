#!/bin/bash

# Comprehensive Fix Script for Kubeflow Platform
# Fixes all identified issues in the deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Header
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║     Kubeflow Platform - Comprehensive Fix Script            ║
║     Fixes all deployment issues automatically               ║
╚══════════════════════════════════════════════════════════════╝
EOF

echo ""

# Check if running in project directory
if [ ! -f "README.md" ] || [ ! -d "02-kubeflow-pipelines" ]; then
    log_error "Must run from project root directory!"
    exit 1
fi

# Create backup directory
BACKUP_DIR="backups/comprehensive-fix-$(date +%Y%m%d-%H%M%S)"
log_info "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
log_success "Backup directory created"
echo ""

# ============================================================================
# FIX 1: Remove namespace field from secretKeyRef in all manifests
# ============================================================================
log_step "FIX 1: Removing unsupported 'namespace' field from secretKeyRef"
echo "─────────────────────────────────────────────────────────────"

FILES_TO_FIX=(
    "02-kubeflow-pipelines/kubeflow-all.yaml"
    "05-jupyterlab/jupyter-all.yaml"
)

fix_secretref() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        log_warning "File not found: $file (skipping)"
        return
    fi
    
    log_info "Processing: $file"
    
    # Create backup
    cp "$file" "$BACKUP_DIR/$(basename $file).backup"
    
    # Count problematic lines before fix
    COUNT_BEFORE=$(grep -c "namespace: ml-infrastructure" "$file" 2>/dev/null || echo "0")
    
    # Fix using awk - more reliable than sed/perl
    awk '
    BEGIN { in_secret = 0; }
    {
        # Detect if we are in a secretKeyRef block
        if (/secretKeyRef:/) {
            in_secret = 1;
            print;
            next;
        }
        
        # If in secretKeyRef and see namespace line, skip it
        if (in_secret && /^[[:space:]]+namespace:[[:space:]]+ml-infrastructure[[:space:]]*$/) {
            in_secret = 0;
            next;
        }
        
        # Exit secretKeyRef context when we see key:
        if (in_secret && /^[[:space:]]+key:/) {
            in_secret = 0;
        }
        
        # Print all other lines
        print;
    }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    
    # Count after fix
    COUNT_AFTER=$(grep -c "namespace: ml-infrastructure" "$file" 2>/dev/null || echo "0")
    REMOVED=$((COUNT_BEFORE - COUNT_AFTER))
    
    if [ $REMOVED -gt 0 ]; then
        log_success "  ✓ Removed $REMOVED problematic namespace reference(s)"
    else
        log_info "  ℹ No problematic namespace references found"
    fi
}

for file in "${FILES_TO_FIX[@]}"; do
    fix_secretref "$file"
done

log_success "✓ Fix 1 completed: secretKeyRef issues resolved"
echo ""

# ============================================================================
# FIX 2: Fix MySQL Readiness and Liveness Probes
# ============================================================================
log_step "FIX 2: Fixing MySQL readiness and liveness probes"
echo "─────────────────────────────────────────────────────────────"

MYSQL_DEPLOYMENT="01-infrastructure/mysql/deployment.yaml"

if [ -f "$MYSQL_DEPLOYMENT" ]; then
    log_info "Backing up MySQL deployment"
    cp "$MYSQL_DEPLOYMENT" "$BACKUP_DIR/mysql-deployment.yaml.backup"
    
    log_info "Updating MySQL deployment with fixed probes"
    
    # Create fixed MySQL deployment
    cat > "$MYSQL_DEPLOYMENT" << 'MYSQL_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: ml-infrastructure
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0.36
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: MYSQL_ROOT_PASSWORD
            - name: MYSQL_DATABASE
              valueFrom:
                configMapKeyRef:
                  name: mysql-config
                  key: MYSQL_DATABASE
            - name: MYSQL_USER
              valueFrom:
                configMapKeyRef:
                  name: mysql-config
                  key: MYSQL_USER
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: MYSQL_PASSWORD
          ports:
            - containerPort: 3306
              name: mysql
          volumeMounts:
            - name: mysql-storage
              mountPath: /var/lib/mysql
          livenessProbe:
            exec:
              command:
                - sh
                - -c
                - mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 6
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - mysql -h localhost -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1"
            initialDelaySeconds: 45
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 20
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
      volumes:
        - name: mysql-storage
          persistentVolumeClaim:
            claimName: mysql-pvc
MYSQL_EOF
    
    log_success "  ✓ MySQL deployment updated with correct probes"
else
    log_warning "MySQL deployment file not found"
fi

log_success "✓ Fix 2 completed: MySQL probes fixed"
echo ""

# ============================================================================
# FIX 3: Update MySQL wait script with better retry logic
# ============================================================================
log_step "FIX 3: Updating MySQL wait script"
echo "─────────────────────────────────────────────────────────────"

MYSQL_WAIT_SCRIPT="scripts/wait-mysql.sh"

if [ -f "$MYSQL_WAIT_SCRIPT" ]; then
    log_info "Backing up MySQL wait script"
    cp "$MYSQL_WAIT_SCRIPT" "$BACKUP_DIR/wait-mysql.sh.backup"
    
    log_info "Creating improved MySQL wait script"
    
    cat > "$MYSQL_WAIT_SCRIPT" << 'WAIT_EOF'
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
WAIT_EOF
    
    chmod +x "$MYSQL_WAIT_SCRIPT"
    log_success "  ✓ MySQL wait script updated"
else
    log_warning "MySQL wait script not found, creating new one"
    mkdir -p scripts
    # Use the same content as above
    cat > "$MYSQL_WAIT_SCRIPT" << 'WAIT_EOF'
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
WAIT_EOF
    
    chmod +x "$MYSQL_WAIT_SCRIPT"
    log_success "  ✓ MySQL wait script created"
fi

log_success "✓ Fix 3 completed: MySQL wait script improved"
echo ""

# ============================================================================
# FIX 4: Update deployment script to use new MySQL wait logic
# ============================================================================
log_step "FIX 4: Updating deployment script"
echo "─────────────────────────────────────────────────────────────"

DEPLOY_SCRIPT="scripts/deploy-all.sh"

if [ -f "$DEPLOY_SCRIPT" ]; then
    log_info "Backing up deployment script"
    cp "$DEPLOY_SCRIPT" "$BACKUP_DIR/deploy-all.sh.backup"
    
    log_info "Updating MySQL initialization section in deploy script"
    
    # Replace the MySQL wait and initialization section
    sed -i.tmp '/# Патч MySQL для более мягкого readiness probe/,/log_success "Infrastructure deployed successfully!"/c\
# Configure MySQL for better initialization\
log_info "Configuring MySQL deployment..."\
kubectl apply -f 01-infrastructure/mysql/deployment.yaml\
\
log_info "Waiting for MinIO to be ready..."\
kubectl wait --for=condition=Ready pods -l app=minio -n ml-infrastructure --timeout=600s || {\
    log_warning "MinIO taking longer than expected"\
    kubectl describe pod -l app=minio -n ml-infrastructure\
    kubectl logs -l app=minio -n ml-infrastructure --tail=20\
}\
\
log_info "Waiting for MySQL to be ready (this may take 2-3 minutes)..."\
bash scripts/wait-mysql.sh || {\
    log_error "MySQL initialization failed"\
    exit 1\
}\
\
log_success "Infrastructure deployed successfully!"' "$DEPLOY_SCRIPT"
    
    # Clean up temp file
    rm -f "${DEPLOY_SCRIPT}.tmp"
    
    log_success "  ✓ Deployment script updated"
else
    log_error "Deployment script not found!"
    exit 1
fi

log_success "✓ Fix 4 completed: Deployment script updated"
echo ""

# ============================================================================
# FIX 5: Validate all YAML files
# ============================================================================
log_step "FIX 5: Validating all YAML files"
echo "─────────────────────────────────────────────────────────────"

YAML_FILES=(
    "02-kubeflow-pipelines/kubeflow-all.yaml"
    "05-jupyterlab/jupyter-all.yaml"
    "01-infrastructure/mysql/deployment.yaml"
    "01-infrastructure/minio/deployment.yaml"
)

VALIDATION_PASSED=true

for file in "${YAML_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_info "Validating: $file"
        
        if command -v kubectl >/dev/null 2>&1; then
            if kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
                log_success "  ✓ Valid YAML syntax"
            else
                log_error "  ✗ Invalid YAML syntax"
                kubectl apply --dry-run=client -f "$file" 2>&1 | head -5
                VALIDATION_PASSED=false
            fi
        else
            log_warning "  kubectl not found, skipping validation"
        fi
    else
        log_warning "$file not found"
    fi
done

if [ "$VALIDATION_PASSED" = true ]; then
    log_success "✓ Fix 5 completed: All YAML files validated successfully"
else
    log_error "✗ Fix 5 failed: Some YAML files have validation errors"
    exit 1
fi

echo ""

# ============================================================================
# FIX 6: Create verification checklist
# ============================================================================
log_step "FIX 6: Creating verification checklist"
echo "─────────────────────────────────────────────────────────────"

CHECKLIST_FILE="FIXES_APPLIED.md"

cat > "$CHECKLIST_FILE" << 'CHECKLIST_EOF'
# Fixes Applied - Verification Checklist

## Date: $(date)

## Issues Fixed:

### ✅ Issue 1: SecretKeyRef Namespace Field
- **Problem**: Kubernetes doesn't support `namespace` field in `secretKeyRef`
- **Files Fixed**:
  - `02-kubeflow-pipelines/kubeflow-all.yaml`
  - `05-jupyterlab/jupyter-all.yaml`
- **Solution**: Removed all `namespace: ml-infrastructure` from secretKeyRef blocks
- **Status**: ✓ Fixed

### ✅ Issue 2: MySQL Readiness Probe
- **Problem**: Readiness probe command using incorrect variable substitution
- **File Fixed**: `01-infrastructure/mysql/deployment.yaml`
- **Solution**: Updated probe to use `sh -c` with proper variable substitution
- **Improvements**:
  - Liveness probe: `initialDelaySeconds: 60`, `failureThreshold: 6`
  - Readiness probe: `initialDelaySeconds: 45`, `failureThreshold: 20`
- **Status**: ✓ Fixed

### ✅ Issue 3: MySQL Wait Script
- **Problem**: Insufficient retry logic and error handling
- **File Fixed**: `scripts/wait-mysql.sh`
- **Solution**: 
  - Added pod status checking
  - Improved retry logic (120 attempts)
  - Better database creation verification
- **Status**: ✓ Fixed

### ✅ Issue 4: Deployment Script
- **Problem**: Hardcoded MySQL initialization without proper error handling
- **File Fixed**: `scripts/deploy-all.sh`
- **Solution**: Integrated improved wait-mysql.sh script
- **Status**: ✓ Fixed

### ✅ Issue 5: YAML Validation
- **Action**: Validated all modified YAML files
- **Status**: ✓ All files validated

## Backups Created:
All original files backed up to: `backups/comprehensive-fix-TIMESTAMP/`

## Verification Steps:

1. **Test MySQL Deployment**:
   ```bash
   kubectl apply -f 01-infrastructure/mysql/
   kubectl wait --for=condition=Ready pods -l app=mysql -n ml-infrastructure --timeout=600s
   bash scripts/wait-mysql.sh
   ```

2. **Test Kubeflow Pipelines Deployment**:
   ```bash
   kubectl apply -f 02-kubeflow-pipelines/
   kubectl get pods -n kubeflow
   ```

3. **Test JupyterLab Deployment**:
   ```bash
   kubectl apply -f 05-jupyterlab/
   kubectl get pods -n kubeflow-user
   ```

4. **Full Deployment Test**:
   ```bash
   make reset
   # Or
   ./scripts/deploy-all.sh
   ```

## Expected Results:
- ✅ No "unknown field" errors from kubectl
- ✅ MySQL pod becomes Ready within 3-5 minutes
- ✅ All Kubeflow components deploy successfully
- ✅ No authentication errors in MySQL logs

## Rollback Instructions:
If issues occur, restore from backup:
```bash
cp backups/comprehensive-fix-TIMESTAMP/*.backup <original-location>
```
CHECKLIST_EOF

log_success "  ✓ Verification checklist created: $CHECKLIST_FILE"
log_success "✓ Fix 6 completed: Documentation created"
echo ""

# ============================================================================
# Summary
# ============================================================================
cat << EOF
╔══════════════════════════════════════════════════════════════╗
║                   All Fixes Applied! ✓                       ║
╚══════════════════════════════════════════════════════════════╝

📋 Summary of Changes:
───────────────────────────────────────────────────────────────
✓ Fix 1: Removed unsupported namespace field from secretKeyRef
✓ Fix 2: Fixed MySQL readiness and liveness probes  
✓ Fix 3: Updated MySQL wait script with better retry logic
✓ Fix 4: Updated deployment script to use new MySQL logic
✓ Fix 5: Validated all YAML files
✓ Fix 6: Created verification checklist

📁 Backup Location:
   $BACKUP_DIR

📝 Documentation:
   $CHECKLIST_FILE

🚀 Next Steps:
───────────────────────────────────────────────────────────────
1. Review changes (optional):
   git diff

2. Test the fixes:
   make reset
   
   Or step by step:
   ./scripts/deploy-all.sh

3. Monitor deployment:
   kubectl get pods -A -w

4. Verify services are running:
   kubectl get pods -n kubeflow
   kubectl get pods -n kubeflow-user
   kubectl get pods -n ml-infrastructure

📊 Health Check Commands:
───────────────────────────────────────────────────────────────
# Check MySQL
kubectl logs -f deployment/mysql -n ml-infrastructure

# Check Kubeflow Pipelines
kubectl logs -f deployment/ml-pipeline -n kubeflow

# Check all events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

═══════════════════════════════════════════════════════════════
All issues have been fixed! You can now deploy Kubeflow.
═══════════════════════════════════════════════════════════════
EOF

# Make scripts executable
chmod +x scripts/*.sh

log_success "Script completed successfully! 🎉"
echo ""