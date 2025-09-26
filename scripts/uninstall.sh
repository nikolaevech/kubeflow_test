#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "⚠️  WARNING: This will delete all Kubeflow components and data!"
read -p "Are you sure you want to continue? (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Uninstall cancelled."
    exit 0
fi

log_info "Starting cleanup process..."

# Delete Custom Dashboard
log_info "Removing Custom Dashboard..."
kubectl delete -f 06-custom-dashboard/ --ignore-not-found=true

# Delete JupyterLab
log_info "Removing JupyterLab..."
kubectl delete -f 05-jupyterlab/ --ignore-not-found=true

# Delete Katib
log_info "Removing Katib..."
kubectl delete -f 04-katib/ --ignore-not-found=true

# Delete KServe
log_info "Removing KServe..."
kubectl delete -f 03-kserve/ --ignore-not-found=true

# Delete Kubeflow Pipelines
log_info "Removing Kubeflow Pipelines..."
kubectl delete -f 02-kubeflow-pipelines/ --ignore-not-found=true

# Delete Infrastructure
log_info "Removing Infrastructure (MinIO, MySQL)..."
kubectl delete -f 01-infrastructure/minio/ --ignore-not-found=true
kubectl delete -f 01-infrastructure/mysql/ --ignore-not-found=true

# Delete Argo Workflows
log_info "Removing Argo Workflows..."
kubectl delete namespace argo --ignore-not-found=true

# Delete namespaces
log_info "Removing namespaces..."
kubectl delete -f 00-prerequisites/namespaces.yaml --ignore-not-found=true

# Option to delete Minikube cluster
read -p "Do you want to delete the entire Minikube cluster? (yes/no): " delete_minikube

if [ "$delete_minikube" = "yes" ]; then
    log_info "Deleting Minikube cluster..."
    minikube delete
    log_success "Minikube cluster deleted!"
else
    log_info "Minikube cluster preserved."
fi

log_success "Cleanup complete! 🧹"