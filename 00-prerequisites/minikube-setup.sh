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
  --addons=ingress,metrics-server,storage-provisioner

echo "✅ Minikube started successfully"

# Включаем необходимые аддоны
minikube addons enable ingress
minikube addons enable metrics-server

echo "📦 Installing Argo Workflows (required for Kubeflow Pipelines)..."
kubectl create namespace argo 2>/dev/null || true
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.5/install.yaml

echo "⏳ Waiting for Argo Workflows..."
# Подождать немного, чтобы поды начали создаваться
sleep 10

# Проверить наличие подов
if kubectl get pods -n argo 2>/dev/null | grep -q argo; then
    kubectl wait --for=condition=Ready pods --all -n argo --timeout=300s || {
        echo "⚠️  Argo Workflows pods are still starting, but you can continue"
        echo "Check status later with: kubectl get pods -n argo"
    }
else
    echo "⚠️  Argo Workflows installing in background"
    echo "Check status with: kubectl get pods -n argo"
fi

echo "🎉 Minikube setup complete!"
echo ""
echo "Cluster Info:"
minikube status
kubectl version --short
kubectl get nodes