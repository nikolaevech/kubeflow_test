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

echo "⏳ Waiting for Argo Workflows..."
kubectl wait --for=condition=Ready pods --all -n argo --timeout=300s

# Опционально: Ingress (можно включить позже если нужен)
read -p "Do you want to enable Ingress addon? (yes/no, default: no): " enable_ingress
if [ "$enable_ingress" = "yes" ]; then
    echo "Enabling Ingress (this may take a few minutes)..."
    minikube addons enable ingress --wait=10m || echo "⚠️  Ingress failed to enable, but you can continue without it"
fi

echo "🎉 Minikube setup complete!"
echo ""
echo "Cluster Info:"
minikube status
kubectl version --short
kubectl get nodes

echo ""
echo "📝 Note: Ingress is not required for Kubeflow. Services are accessible via NodePort."