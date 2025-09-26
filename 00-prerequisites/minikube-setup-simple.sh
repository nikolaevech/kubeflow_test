#!/bin/bash

set -e

echo "🚀 Starting Minikube with Kubeflow configuration..."

# Останавливаем существующий кластер если есть
minikube delete 2>/dev/null || true

# Создаем Minikube кластер с достаточными ресурсами
minikube start \
  --cpus=6 \
  --memory=12g \
  --disk-size=50g \
  --kubernetes-version=v1.28.0 \
  --driver=docker \
  --addons=metrics-server,storage-provisioner

echo "✅ Minikube started successfully"

# Включаем metrics-server
minikube addons enable metrics-server

echo "📦 Installing Argo Workflows (required for Kubeflow Pipelines)..."
kubectl create namespace argo 2>/dev/null || true
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.5/install.yaml

echo ""
echo "⏳ Argo Workflows is installing in background..."
echo "   Check status with: kubectl get pods -n argo"
echo ""
echo "🎉 Minikube setup complete!"
echo ""
echo "Cluster Info:"
minikube status
kubectl version --short 2>/dev/null || kubectl version --client
kubectl get nodes

echo ""
echo "📝 Next steps:"
echo "   1. Wait ~1 minute for Argo to be ready: kubectl get pods -n argo -w"
echo "   2. Deploy Kubeflow: make deploy (or ./scripts/deploy-all.sh)"
echo ""