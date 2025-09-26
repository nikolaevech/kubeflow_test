#!/bin/bash

# Kubeflow Platform Quick Start
# This script sets everything up from scratch

set -e

cat << "EOF"
╔══════════════════════════════════════════════════╗
║     Kubeflow ML Platform - Quick Start          ║
║              Powered by Minikube                 ║
╚══════════════════════════════════════════════════╝
EOF

echo ""
echo "🚀 Starting automated deployment..."
echo ""

# Check if running in project directory
if [ ! -f "scripts/deploy-all.sh" ]; then
    echo "❌ Error: Must run from project root directory"
    exit 1
fi

# Step 1: Prerequisites check
echo "📋 Step 1/4: Checking prerequisites..."
command -v minikube >/dev/null 2>&1 || { 
    echo "❌ Minikube not found. Install: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
}
command -v kubectl >/dev/null 2>&1 || { 
    echo "❌ kubectl not found. Install: https://kubernetes.io/docs/tasks/tools/"
    exit 1
}
echo "✅ Prerequisites OK"

# Step 2: Make scripts executable
echo ""
echo "🔧 Step 2/4: Preparing scripts..."
chmod +x scripts/*.sh
chmod +x 00-prerequisites/*.sh
echo "✅ Scripts ready"

# Step 3: Deploy
echo ""
echo "🚢 Step 3/4: Deploying Kubeflow platform (this takes ~10-15 minutes)..."
./scripts/deploy-all.sh

# Step 4: Setup port forwarding
echo ""
echo "🔗 Step 4/4: Setting up port forwarding..."
./scripts/port-forward.sh &
PORT_FORWARD_PID=$!

sleep 5

# Display final info
MINIKUBE_IP=$(minikube ip)

cat << EOF

╔══════════════════════════════════════════════════╗
║          🎉 Deployment Successful! 🎉           ║
╚══════════════════════════════════════════════════╝

📍 Access Methods:

Option 1: Minikube IP (Recommended for external access)
   Dashboard:     http://${MINIKUBE_IP}:30080
   Pipelines:     http://${MINIKUBE_IP}:30888
   Katib:         http://${MINIKUBE_IP}:30777
   JupyterLab:    http://${MINIKUBE_IP}:30666
   MinIO Console: http://${MINIKUBE_IP}:30900

Option 2: Localhost (via port-forward, already running)
   Dashboard:     http://localhost:8080
   Pipelines:     http://localhost:8888
   Katib:         http://localhost:8777
   JupyterLab:    http://localhost:8866
   MinIO Console: http://localhost:9001

🔑 Default Credentials:
   MinIO:  minioadmin / minioadmin123
   MySQL:  root / rootpass123

📚 Quick Commands:
   kubectl get pods -A              # View all pods
   minikube dashboard               # Open K8s dashboard
   ./scripts/port-forward.sh        # Restart port forwarding
   ./scripts/uninstall.sh           # Clean everything

📖 Full Documentation: README.md

🎓 Next Steps:
   1. Open the Dashboard: http://localhost:8080
   2. Try JupyterLab: http://localhost:8866
   3. Create your first pipeline!

Press Ctrl+C to stop port forwarding (services remain running)
EOF

# Keep script running to maintain port forwards
wait $PORT_FORWARD_PID