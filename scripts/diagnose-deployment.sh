#!/bin/bash

# Deployment Diagnostics Script
# Diagnoses issues with Kubeflow deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
}

cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║        Kubeflow Deployment Diagnostics                      ║
╚══════════════════════════════════════════════════════════════╝
EOF

echo ""

# ============================================================================
# Check 1: Pod Status
# ============================================================================
log_section "CHECK 1: Pod Status"

log_info "Checking pods in kubeflow namespace..."
kubectl get pods -n kubeflow
echo ""

log_info "Checking pods in kubeflow-user namespace..."
kubectl get pods -n kubeflow-user
echo ""

log_info "Checking pods in ml-infrastructure namespace..."
kubectl get pods -n ml-infrastructure
echo ""

# ============================================================================
# Check 2: Problematic Pods Logs
# ============================================================================
log_section "CHECK 2: Problematic Pods Analysis"

# ML Pipeline
log_info "Analyzing ml-pipeline pod..."
ML_PIPELINE_POD=$(kubectl get pods -n kubeflow -l app=ml-pipeline -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$ML_PIPELINE_POD" ]; then
    echo "Pod: $ML_PIPELINE_POD"
    
    POD_STATUS=$(kubectl get pod $ML_PIPELINE_POD -n kubeflow -o jsonpath='{.status.phase}')
    echo "Status: $POD_STATUS"
    
    if [ "$POD_STATUS" != "Running" ]; then
        log_warning "Pod is not running. Checking events..."
        kubectl describe pod $ML_PIPELINE_POD -n kubeflow | tail -20
    fi
    
    log_info "Last 30 lines of logs:"
    kubectl logs $ML_PIPELINE_POD -n kubeflow --tail=30 2>&1 || log_warning "Could not fetch logs"
else
    log_error "ml-pipeline pod not found"
fi

echo ""

# Katib Controller
log_info "Analyzing katib-controller pod..."
KATIB_POD=$(kubectl get pods -n kubeflow -l app=katib-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$KATIB_POD" ]; then
    echo "Pod: $KATIB_POD"
    
    POD_STATUS=$(kubectl get pod $KATIB_POD -n kubeflow -o jsonpath='{.status.phase}')
    echo "Status: $POD_STATUS"
    
    if [ "$POD_STATUS" != "Running" ]; then
        log_warning "Pod is not running. Checking events..."
        kubectl describe pod $KATIB_POD -n kubeflow | tail -20
    fi
    
    log_info "Last 30 lines of logs:"
    kubectl logs $KATIB_POD -n kubeflow --tail=30 2>&1 || log_warning "Could not fetch logs"
else
    log_error "katib-controller pod not found"
fi

echo ""

# JupyterLab
log_info "Analyzing jupyterlab pod..."
JUPYTER_POD=$(kubectl get pods -n kubeflow-user -l app=jupyterlab -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$JUPYTER_POD" ]; then
    echo "Pod: $JUPYTER_POD"
    
    POD_STATUS=$(kubectl get pod $JUPYTER_POD -n kubeflow-user -o jsonpath='{.status.phase}')
    echo "Status: $POD_STATUS"
    
    if [ "$POD_STATUS" != "Running" ]; then
        log_warning "Pod is not running. Checking events..."
        kubectl describe pod $JUPYTER_POD -n kubeflow-user | tail -20
    fi
    
    log_info "Last 30 lines of logs:"
    kubectl logs $JUPYTER_POD -n kubeflow-user --tail=30 2>&1 || log_warning "Could not fetch logs"
else
    log_error "jupyterlab pod not found"
fi

echo ""

# ============================================================================
# Check 3: Secrets Verification
# ============================================================================
log_section "CHECK 3: Secrets Verification"

log_info "Checking secrets in kubeflow namespace..."
kubectl get secrets -n kubeflow | grep -E "minio-secret|mysql-secret" || log_warning "Required secrets not found"
echo ""

log_info "Checking secrets in kubeflow-user namespace..."
kubectl get secrets -n kubeflow-user | grep -E "minio-secret" || log_warning "Required secrets not found"
echo ""

log_info "Checking secrets in ml-infrastructure namespace..."
kubectl get secrets -n ml-infrastructure | grep -E "minio-secret|mysql-secret"
echo ""

# ============================================================================
# Check 4: Database Connectivity
# ============================================================================
log_section "CHECK 4: Database Connectivity"

log_info "Testing MySQL connectivity..."
kubectl exec -n ml-infrastructure deployment/mysql -- \
    sh -c 'mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;"' 2>/dev/null && \
    log_success "MySQL is accessible" || \
    log_error "MySQL connectivity issue"

echo ""

log_info "Testing MinIO connectivity..."
kubectl exec -n ml-infrastructure deployment/minio -- \
    sh -c 'mc alias set myminio http://localhost:9000 minioadmin minioadmin123 && mc ls myminio' 2>/dev/null && \
    log_success "MinIO is accessible" || \
    log_error "MinIO connectivity issue"

echo ""

# ============================================================================
# Check 5: Recent Events
# ============================================================================
log_section "CHECK 5: Recent Cluster Events"

log_info "Recent events in kubeflow namespace:"
kubectl get events -n kubeflow --sort-by='.lastTimestamp' | tail -15

echo ""

log_info "Recent events in kubeflow-user namespace:"
kubectl get events -n kubeflow-user --sort-by='.lastTimestamp' | tail -10

echo ""

# ============================================================================
# Check 6: Service Endpoints
# ============================================================================
log_section "CHECK 6: Service Endpoints"

log_info "Checking service endpoints..."
kubectl get endpoints -n kubeflow -l 'app in (ml-pipeline,katib-controller,katib-db-manager)'
kubectl get endpoints -n kubeflow-user -l app=jupyterlab

echo ""

# ============================================================================
# Check 7: Container Images
# ============================================================================
log_section "CHECK 7: Container Images Status"

log_info "Checking if images are pulling correctly..."

# Check ml-pipeline
if [ -n "$ML_PIPELINE_POD" ]; then
    IMAGE_STATUS=$(kubectl get pod $ML_PIPELINE_POD -n kubeflow -o jsonpath='{.status.containerStatuses[0].state}')
    echo "ml-pipeline image status: $IMAGE_STATUS"
fi

# Check katib
if [ -n "$KATIB_POD" ]; then
    IMAGE_STATUS=$(kubectl get pod $KATIB_POD -n kubeflow -o jsonpath='{.status.containerStatuses[0].state}')
    echo "katib-controller image status: $IMAGE_STATUS"
fi

# Check jupyter
if [ -n "$JUPYTER_POD" ]; then
    IMAGE_STATUS=$(kubectl get pod $JUPYTER_POD -n kubeflow-user -o jsonpath='{.status.containerStatuses[0].state}')
    echo "jupyterlab image status: $IMAGE_STATUS"
fi

echo ""

# ============================================================================
# Recommendations
# ============================================================================
log_section "RECOMMENDATIONS"

echo "Based on the diagnostics above, here are potential fixes:"
echo ""
echo "1. If pods are in ImagePullBackOff:"
echo "   - Check internet connectivity"
echo "   - Verify image names in deployments"
echo "   - Consider using minikube cache: minikube cache add <image>"
echo ""
echo "2. If pods are in CrashLoopBackOff:"
echo "   - Check logs above for specific errors"
echo "   - Verify secrets are correctly copied"
echo "   - Check database connectivity"
echo ""
echo "3. If secrets are missing:"
echo "   - Run: make deploy (will recreate secrets)"
echo "   - Or manually copy: kubectl get secret <name> -n ml-infrastructure -o yaml | sed 's/namespace: ml-infrastructure/namespace: kubeflow/' | kubectl apply -f -"
echo ""
echo "4. If database issues:"
echo "   - Restart MySQL: kubectl rollout restart deployment/mysql -n ml-infrastructure"
echo "   - Check MySQL logs: kubectl logs -f deployment/mysql -n ml-infrastructure"
echo ""
echo "5. Quick fixes to try:"
echo "   - Restart problematic deployments:"
echo "     kubectl rollout restart deployment/ml-pipeline -n kubeflow"
echo "     kubectl rollout restart deployment/katib-controller -n kubeflow"
echo "     kubectl rollout restart deployment/jupyterlab -n kubeflow-user"
echo ""

# ============================================================================
# Summary
# ============================================================================
log_section "SUMMARY"

# Count pods by status
RUNNING_COUNT=$(kubectl get pods -A | grep -c "Running" || echo "0")
PENDING_COUNT=$(kubectl get pods -A | grep -c "Pending" || echo "0")
ERROR_COUNT=$(kubectl get pods -A | grep -E "CrashLoopBackOff|Error|ImagePullBackOff" | wc -l || echo "0")

echo "Total Running Pods: $RUNNING_COUNT"
echo "Total Pending Pods: $PENDING_COUNT"
echo "Total Error Pods: $ERROR_COUNT"
echo ""

if [ "$ERROR_COUNT" -gt 0 ] || [ "$PENDING_COUNT" -gt 3 ]; then
    log_warning "There are issues that need attention. Review the diagnostics above."
    echo ""
    echo "Quick commands:"
    echo "  kubectl get pods -A                              # View all pods"
    echo "  kubectl describe pod <pod-name> -n <namespace>   # Detailed pod info"
    echo "  kubectl logs <pod-name> -n <namespace>           # View logs"
    echo "  ./scripts/diagnose-deployment.sh                 # Re-run diagnostics"
else
    log_success "Deployment looks healthy!"
fi

echo ""