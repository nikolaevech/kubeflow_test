#!/bin/bash

echo "🔗 Setting up port forwarding for all services..."
echo "Press Ctrl+C to stop all port forwards"
echo ""

# Функция для запуска port-forward в фоне
forward_port() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local target_port=$4
    local name=$5
    
    echo "Forwarding $name: localhost:$local_port -> $service:$target_port"
    kubectl port-forward -n $namespace svc/$service $local_port:$target_port --address=0.0.0.0 &
}

# Forward all services
forward_port "custom-dashboard" "kubeflow" "8080" "80" "Dashboard"
forward_port "ml-pipeline-ui" "kubeflow" "8888" "80" "Pipelines UI"
forward_port "katib-ui" "kubeflow" "8777" "80" "Katib UI"
forward_port "jupyterlab" "kubeflow-user" "8866" "80" "JupyterLab"
forward_port "minio-console" "ml-infrastructure" "9001" "9001" "MinIO Console"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║        Services available at localhost:                ║"
echo "╠════════════════════════════════════════════════════════╣"
echo "║  Dashboard:     http://localhost:8080                  ║"
echo "║  Pipelines:     http://localhost:8888                  ║"
echo "║  Katib:         http://localhost:8777                  ║"
echo "║  JupyterLab:    http://localhost:8866                  ║"
echo "║  MinIO Console: http://localhost:9001                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "ℹ️  Keep this terminal open. Press Ctrl+C to stop."

# Wait for user interrupt
wait