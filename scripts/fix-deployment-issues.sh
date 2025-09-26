#!/bin/bash

# Automatic Fix Script for Kubeflow Deployment Issues
# Attempts to fix common deployment problems

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║        Kubeflow Deployment Auto-Fix Script                  ║
╚══════════════════════════════════════════════════════════════╝
EOF

echo ""

# ============================================================================
# Fix 1: Ensure secrets are copied to all namespaces
# ============================================================================
log_info "Fix 1: Copying secrets to all namespaces..."

# Copy minio-secret to kubeflow
kubectl get secret minio-secret -n ml-infrastructure -o json | \
    jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.metadata.creationTimestamp)' | \
    jq '.metadata.namespace = "kubeflow"' | \
    kubectl apply -f - 2>/dev/null && \
    log_success "  ✓ minio-secret copied to kubeflow" || \
    log_warning "  Could not copy minio-secret to kubeflow"

# Copy mysql-secret to kubeflow
kubectl get secret mysql-secret -n ml-infrastructure -o json | \
    jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.metadata.creationTimestamp)' | \
    jq '.metadata.namespace = "kubeflow"' | \
    kubectl apply -f - 2>/dev/null && \
    log_success "  ✓ mysql-secret copied to kubeflow" || \
    log_warning "  Could not copy mysql-secret to kubeflow"

# Copy minio-secret to kubeflow-user
kubectl get secret minio-secret -n ml-infrastructure -o json | \
    jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.metadata.creationTimestamp)' | \
    jq '.metadata.namespace = "kubeflow-user"' | \
    kubectl apply -f - 2>/dev/null && \
    log_success "  ✓ minio-secret copied to kubeflow-user" || \
    log_warning "  Could not copy minio-secret to kubeflow-user"

echo ""

# ============================================================================
# Fix 2: Restart problematic deployments
# ============================================================================
log_info "Fix 2: Restarting problematic deployments..."

# Check and restart ml-pipeline if not ready
if ! kubectl wait --for=condition=Ready pods -l app=ml-pipeline -n kubeflow --timeout=5s 2>/dev/null; then
    log_info "  Restarting ml-pipeline..."
    kubectl rollout restart deployment/ml-pipeline -n kubeflow
    sleep 5
    log_success "  ✓ ml-pipeline restarted"
fi

# Check and restart katib-controller if not ready
if ! kubectl wait --for=condition=Ready pods -l app=katib-controller -n kubeflow --timeout=5s 2>/dev/null; then
    log_info "  Restarting katib-controller..."
    kubectl rollout restart deployment/katib-controller -n kubeflow
    sleep 5
    log_success "  ✓ katib-controller restarted"
fi

# Check and restart jupyterlab if not ready
if ! kubectl wait --for=condition=Ready pods -l app=jupyterlab -n kubeflow-user --timeout=5s 2>/dev/null; then
    log_info "  Restarting jupyterlab..."
    kubectl rollout restart deployment/jupyterlab -n kubeflow-user
    sleep 5
    log_success "  ✓ jupyterlab restarted"
fi

echo ""

# ============================================================================
# Fix 3: Deploy Custom Dashboard if missing
# ============================================================================
log_info "Fix 3: Checking Custom Dashboard..."

if ! kubectl get deployment custom-dashboard -n kubeflow >/dev/null 2>&1; then
    log_info "  Custom Dashboard not found, deploying..."
    
    if [ -f "06-custom-dashboard/dashboard-all.yaml" ]; then
        kubectl apply -f 06-custom-dashboard/dashboard-all.yaml
        log_success "  ✓ Custom Dashboard deployed"
    else
        log_error "  Custom Dashboard manifest not found"
    fi
else
    log_success "  ✓ Custom Dashboard already exists"
fi

echo ""

# ============================================================================
# Fix 4: Wait for pods to become ready
# ============================================================================
log_info "Fix 4: Waiting for pods to become ready (up to 5 minutes)..."

# Wait for ml-pipeline
log_info "  Waiting for ml-pipeline..."
if kubectl wait --for=condition=Ready pods -l app=ml-pipeline -n kubeflow --timeout=300s 2>/dev/null; then
    log_success "  ✓ ml-pipeline is ready"
else
    log_warning "  ml-pipeline still not ready, check logs: kubectl logs -l app=ml-pipeline -n kubeflow"
fi

# Wait for katib-controller
log_info "  Waiting for katib-controller..."
if kubectl wait --for=condition=Ready pods -l app=katib-controller -n kubeflow --timeout=300s 2>/dev/null; then
    log_success "  ✓ katib-controller is ready"
else
    log_warning "  katib-controller still not ready, check logs: kubectl logs -l app=katib-controller -n kubeflow"
fi

# Wait for jupyterlab
log_info "  Waiting for jupyterlab..."
if kubectl wait --for=condition=Ready pods -l app=jupyterlab -n kubeflow-user --timeout=300s 2>/dev/null; then
    log_success "  ✓ jupyterlab is ready"
else
    log_warning "  jupyterlab still not ready, check logs: kubectl logs -l app=jupyterlab -n kubeflow-user"
fi

# Wait for custom-dashboard
log_info "  Waiting for custom-dashboard..."
if kubectl wait --for=condition=Ready pods -l app=custom-dashboard -n kubeflow --timeout=180s 2>/dev/null; then
    log_success "  ✓ custom-dashboard is ready"
else
    log_warning "  custom-dashboard still not ready"
fi

echo ""

# ============================================================================
# Fix 5: Verify database connections
# ============================================================================
log_info "Fix 5: Verifying database connections..."

# Check MySQL
if kubectl exec -n ml-infrastructure deployment/mysql -- \
    sh -c 'mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 1"' >/dev/null 2>&1; then
    log_success "  ✓ MySQL is accessible"
else
    log_error "  MySQL is not accessible"
    log_info "  Attempting to restart MySQL..."
    kubectl rollout restart deployment/mysql -n ml-infrastructure
    sleep 10
fi

# Check MinIO
if kubectl exec -n ml-infrastructure deployment/minio -- \
    sh -c 'mc alias set test http://localhost:9000 minioadmin minioadmin123' >/dev/null 2>&1; then
    log_success "  ✓ MinIO is accessible"
else
    log_error "  MinIO is not accessible"
    log_info "  Attempting to restart MinIO..."
    kubectl rollout restart deployment/minio -n ml-infrastructure
    sleep 10
fi

echo ""

# ============================================================================
# Fix 6: Check and fix katib database connection
# ============================================================================
log_info "Fix 6: Checking Katib database..."

# Ensure katib database exists
kubectl exec -n ml-infrastructure deployment/mysql -- \
    sh -c 'mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS katib;"' 2>/dev/null && \
    log_success "  ✓ Katib database verified" || \
    log_warning "  Could not verify Katib database"

# Restart katib-db-manager if exists
if kubectl get deployment katib-db-manager -n kubeflow >/dev/null 2>&1; then
    log_info "  Restarting katib-db-manager..."
    kubectl rollout restart deployment/katib-db-manager -n kubeflow
    sleep 5
    log_success "  ✓ katib-db-manager restarted"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
log_info "Generating status summary..."
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                    DEPLOYMENT STATUS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check all pods
echo "Pod Status by Namespace:"
echo ""
echo "ml-infrastructure:"
kubectl get pods -n ml-infrastructure 2>/dev/null || echo "  No pods found"
echo ""
echo "kubeflow:"
kubectl get pods -n kubeflow 2>/dev/null || echo "  No pods found"
echo ""
echo "kubeflow-user:"
kubectl get pods -n kubeflow-user 2>/dev/null || echo "  No pods found"
echo ""

# Get Minikube IP
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "UNKNOWN")

echo "═══════════════════════════════════════════════════════════════"
echo "                    ACCESS INFORMATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Minikube IP: $MINIKUBE_IP"
echo ""
echo "Service URLs:"
echo "  Dashboard:     http://${MINIKUBE_IP}:30080"
echo "  Pipelines:     http://${MINIKUBE_IP}:30888"
echo "  Katib:         http://${MINIKUBE_IP}:30777"
echo "  JupyterLab:    http://${MINIKUBE_IP}:30666"
echo "  MinIO Console: http://${MINIKUBE_IP}:30900"
echo ""
echo "Credentials:"
echo "  MinIO:  minioadmin / minioadmin123"
echo "  MySQL:  root / rootpass123"
echo ""

# Count ready pods
TOTAL_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
READY_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep "Running" | grep -E "1/1|2/2|3/3" | wc -l)

echo "═══════════════════════════════════════════════════════════════"
echo "Ready Pods: $READY_PODS / $TOTAL_PODS"

if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    log_success "All pods are ready! ✓"
elif [ "$READY_PODS" -gt $((TOTAL_PODS * 2 / 3)) ]; then
    log_warning "Most pods are ready, some may need more time"
    echo ""
    echo "Pods not ready:"
    kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running.*1/1\|Running.*2/2"
else
    log_error "Many pods are not ready"
    echo ""
    echo "Run diagnostics: ./scripts/diagnose-deployment.sh"
    echo "Check logs: kubectl logs <pod-name> -n <namespace>"
fi

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Next steps
echo "Next Steps:"
echo "  1. Check deployment status: kubectl get pods -A"
echo "  2. Run diagnostics: ./scripts/diagnose-deployment.sh"
echo "  3. View specific logs: kubectl logs <pod> -n <namespace>"
echo "  4. Access services at URLs above"
echo ""
echo "If issues persist:"
echo "  - Full redeploy: make reset"
echo "  - Check events: kubectl get events -A --sort-by='.lastTimestamp'"
echo ""

log_success "Fix script completed!"