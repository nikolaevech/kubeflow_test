#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check prerequisites
log_info "Checking prerequisites..."
command -v minikube >/dev/null 2>&1 || { log_error "minikube is not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is not installed. Aborting."; exit 1; }

log_success "Prerequisites check passed!"

# Setup Minikube
log_info "Setting up Minikube cluster..."
# Проверяем, запущен ли Minikube
if minikube status >/dev/null 2>&1; then
    log_success "Minikube already running"
else
    bash 00-prerequisites/minikube-setup.sh || {
        log_warning "Minikube setup had issues, but cluster may be running. Checking..."
        if kubectl get nodes >/dev/null 2>&1; then
            log_success "Kubernetes cluster is accessible, continuing..."
        else
            log_error "Cannot access Kubernetes cluster. Please fix Minikube and retry."
            exit 1
        fi
    }
fi

# Create namespaces
log_info "Creating namespaces..."
kubectl apply -f 00-prerequisites/namespaces.yaml
log_success "Namespaces created!"

# Deploy Infrastructure (MinIO, MySQL)
log_info "Deploying infrastructure components..."
kubectl apply -f 01-infrastructure/minio/
kubectl apply -f 01-infrastructure/mysql/

# Патч MySQL для более мягкого readiness probe
log_info "Configuring MySQL readiness probe..."
kubectl patch deployment mysql -n ml-infrastructure --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/readinessProbe/failureThreshold",
    "value": 20
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/readinessProbe/initialDelaySeconds",
    "value": 45
  }
]' 2>/dev/null || log_warning "Could not patch MySQL readiness probe"

log_info "Waiting for MinIO to be ready..."
kubectl wait --for=condition=Ready pods -l app=minio -n ml-infrastructure --timeout=600s || {
    log_warning "MinIO taking longer than expected"
    kubectl describe pod -l app=minio -n ml-infrastructure
    kubectl logs -l app=minio -n ml-infrastructure --tail=20
}

log_info "Waiting for MySQL to be ready (this may take 2-3 minutes)..."
# Увеличиваем таймаут и добавляем диагностику
kubectl wait --for=condition=Ready pods -l app=mysql -n ml-infrastructure --timeout=600s || {
    log_warning "MySQL taking longer than expected. Checking status..."
    echo ""
    echo "MySQL Pod Status:"
    kubectl get pods -l app=mysql -n ml-infrastructure
    echo ""
    echo "MySQL Pod Details:"
    kubectl describe pod -l app=mysql -n ml-infrastructure | tail -30
    echo ""
    echo "MySQL Logs:"
    kubectl logs -l app=mysql -n ml-infrastructure --tail=30 2>/dev/null || echo "No logs yet"
    echo ""
    
    # Проверяем, запустился ли под вообще
    if kubectl get pods -l app=mysql -n ml-infrastructure | grep -q "Running\|ContainerCreating"; then
        log_warning "MySQL pod is starting but not ready yet. Waiting additional 3 minutes..."
        kubectl wait --for=condition=Ready pods -l app=mysql -n ml-infrastructure --timeout=180s || {
            log_error "MySQL still not ready. Please check the logs above."
            read -p "Do you want to continue anyway? (yes/no): " continue_deploy
            if [ "$continue_deploy" != "yes" ]; then
                exit 1
            fi
        }
    else
        log_error "MySQL pod failed to start. Check the details above."
        exit 1
    fi
}

# Initialize MySQL databases
log_info "Initializing MySQL databases..."

# Подождать, пока MySQL полностью запустится
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if kubectl exec -n ml-infrastructure deployment/mysql -- mysqladmin ping -h localhost -uroot -prootpass123 2>/dev/null | grep -q "mysqld is alive"; then
        log_success "MySQL is ready!"
        break
    fi
    echo "  Waiting for MySQL to be fully ready... ($((attempt+1))/$max_attempts)"
    sleep 5
    attempt=$((attempt+1))
done

if [ $attempt -eq $max_attempts ]; then
    log_error "MySQL did not become ready in time"
    exit 1
fi

# Теперь создаем базы данных
log_info "Creating databases..."
kubectl exec -n ml-infrastructure deployment/mysql -- mysql -uroot -prootpass123 -e "CREATE DATABASE IF NOT EXISTS mlpipeline;" || {
    log_error "Failed to create mlpipeline database"
    exit 1
}
kubectl exec -n ml-infrastructure deployment/mysql -- mysql -uroot -prootpass123 -e "CREATE DATABASE IF NOT EXISTS katib;" || {
    log_error "Failed to create katib database"
    exit 1
}
log_success "Infrastructure deployed successfully!"

# Copy secrets to other namespaces
log_info "Copying secrets to kubeflow namespaces..."
kubectl get secret minio-secret -n ml-infrastructure -o yaml | \
  sed 's/namespace: ml-infrastructure/namespace: kubeflow/' | \
  kubectl apply -f - >/dev/null 2>&1

kubectl get secret mysql-secret -n ml-infrastructure -o yaml | \
  sed 's/namespace: ml-infrastructure/namespace: kubeflow/' | \
  kubectl apply -f - >/dev/null 2>&1

kubectl get secret minio-secret -n ml-infrastructure -o yaml | \
  sed 's/namespace: ml-infrastructure/namespace: kubeflow-user/' | \
  kubectl apply -f - >/dev/null 2>&1

log_success "Secrets copied!"

# Initialize MinIO buckets
log_info "Creating MinIO buckets..."
kubectl exec -n ml-infrastructure deployment/minio -- sh -c "
  mc alias set myminio http://localhost:9000 minioadmin minioadmin123
  mc mb myminio/mlpipeline --ignore-existing
  mc mb myminio/models --ignore-existing
  mc mb myminio/data --ignore-existing
" || log_warning "MinIO buckets may already exist"

# Deploy Kubeflow Pipelines
log_info "Deploying Kubeflow Pipelines..."
kubectl apply -f 02-kubeflow-pipelines/

log_info "Waiting for Kubeflow Pipelines to be ready..."
sleep 30
kubectl wait --for=condition=Ready pods -l app=ml-pipeline -n kubeflow --timeout=300s || log_warning "Pipelines may need more time"
kubectl wait --for=condition=Ready pods -l app=ml-pipeline-ui -n kubeflow --timeout=300s || log_warning "Pipeline UI may need more time"

log_success "Kubeflow Pipelines deployed!"

# Deploy KServe
log_info "Deploying KServe..."
kubectl apply -f 03-kserve/

log_info "Waiting for KServe controller..."
sleep 20
kubectl wait --for=condition=Ready pods -l app=kserve-controller-manager -n kubeflow --timeout=300s || log_warning "KServe may need more time"

log_success "KServe deployed!"

# Deploy Katib
log_info "Deploying Katib..."
kubectl apply -f 04-katib/

log_info "Waiting for Katib components..."
sleep 20
kubectl wait --for=condition=Ready pods -l app=katib-controller -n kubeflow --timeout=300s || log_warning "Katib may need more time"
kubectl wait --for=condition=Ready pods -l app=katib-ui -n kubeflow --timeout=300s || log_warning "Katib UI may need more time"

log_success "Katib deployed!"

# Deploy JupyterLab
log_info "Deploying JupyterLab..."
kubectl apply -f 05-jupyterlab/

log_info "Waiting for JupyterLab to be ready..."
sleep 30
kubectl wait --for=condition=Ready pods -l app=jupyterlab -n kubeflow-user --timeout=300s || log_warning "JupyterLab may need more time"

log_success "JupyterLab deployed!"

# Deploy Custom Dashboard
log_info "Deploying Custom Dashboard..."
kubectl apply -f 06-custom-dashboard/

log_info "Waiting for Dashboard to be ready..."
kubectl wait --for=condition=Ready pods -l app=custom-dashboard -n kubeflow --timeout=180s

log_success "Custom Dashboard deployed!"

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Display access information
echo ""
echo "=========================================="
echo "🎉 Kubeflow Platform Deployment Complete!"
echo "=========================================="
echo ""
echo "📍 Access URLs (using Minikube IP: ${MINIKUBE_IP}):"
echo ""
echo "🎨 Custom Dashboard:       http://${MINIKUBE_IP}:30080"
echo "📊 Kubeflow Pipelines UI:  http://${MINIKUBE_IP}:30888"
echo "🔬 Katib UI:               http://${MINIKUBE_IP}:30777"
echo "📓 JupyterLab:             http://${MINIKUBE_IP}:30666"
echo "💾 MinIO Console:          http://${MINIKUBE_IP}:30900"
echo ""
echo "🔑 Credentials:"
echo "   MinIO:  minioadmin / minioadmin123"
echo "   MySQL:  root / rootpass123"
echo ""
echo "📋 Useful Commands:"
echo "   kubectl get pods -A                    # View all pods"
echo "   kubectl logs -f <pod> -n <namespace>   # View logs"
echo "   minikube dashboard                     # Open K8s dashboard"
echo "   ./scripts/port-forward.sh              # Setup port forwarding"
echo ""
echo "🔧 Troubleshooting:"
echo "   kubectl get events -A --sort-by='.lastTimestamp'"
echo "   kubectl describe pod <pod-name> -n <namespace>"
echo ""
log_success "Happy ML Engineering! 🚀"