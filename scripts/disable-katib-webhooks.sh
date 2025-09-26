#!/bin/bash

# Simplified Katib Deployment - Without Webhooks
# This is the most reliable approach for local/development setups

set -e

NAMESPACE="kubeflow"

echo "╔══════════════════════════════════════════════════╗"
echo "║   Deploying Simplified Katib (No Webhooks)      ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Remove webhook configurations
echo "[INFO] Removing webhook configurations..."
kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io katib-validating-webhook-config --ignore-not-found=true
kubectl delete mutatingwebhookconfigurations.admissionregistration.k8s.io katib-mutating-webhook-config --ignore-not-found=true
echo "[✓] Webhook configurations removed"

# Remove any existing deployments
echo ""
echo "[INFO] Cleaning up existing Katib controller..."
kubectl delete deployment katib-controller -n ${NAMESPACE} --ignore-not-found=true
sleep 5

# Deploy simplified Katib controller
echo ""
echo "[INFO] Deploying simplified Katib controller..."

kubectl apply -f - << 'EOF'
---
# Katib Controller Deployment (Simplified - No Webhooks)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: katib-controller
  namespace: kubeflow
  labels:
    app: katib-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: katib-controller
  template:
    metadata:
      labels:
        app: katib-controller
    spec:
      serviceAccountName: katib-controller
      containers:
        - name: katib-controller
          image: docker.io/kubeflowkatib/katib-controller:v0.16.0
          command:
            - ./katib-controller
          env:
            - name: KATIB_CORE_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            # Disable webhook server
            - name: KATIB_DISABLE_WEBHOOK
              value: "true"
          ports:
            - containerPort: 8080
              name: metrics
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /metrics
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /metrics
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
EOF

echo "[✓] Deployment created"

# Wait for ready
echo ""
echo "[INFO] Waiting for controller to be ready (timeout: 180s)..."
sleep 10

if kubectl wait --for=condition=Ready pods -l app=katib-controller -n ${NAMESPACE} --timeout=180s 2>/dev/null; then
    echo "[✓] Katib controller is ready!"
    
    echo ""
    echo "Controller status:"
    kubectl get pods -n ${NAMESPACE} -l app=katib-controller
    
    echo ""
    echo "Recent logs (checking for errors):"
    kubectl logs -n ${NAMESPACE} -l app=katib-controller --tail=20
    
else
    echo "[⚠] Controller taking longer than expected"
    echo ""
    echo "Current status:"
    kubectl get pods -n ${NAMESPACE} -l app=katib-controller
    
    echo ""
    echo "Deployment details:"
    kubectl describe deployment katib-controller -n ${NAMESPACE} | tail -20
    
    echo ""
    echo "Pod logs:"
    kubectl logs -n ${NAMESPACE} -l app=katib-controller --tail=50
    
    echo ""
    echo "[INFO] Checking if it's still starting..."
    POD_STATUS=$(kubectl get pods -n ${NAMESPACE} -l app=katib-controller -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
    echo "Pod phase: ${POD_STATUS}"
    
    if [ "$POD_STATUS" = "Running" ]; then
        echo ""
        echo "[INFO] Pod is Running but not Ready. Checking readiness probe..."
        kubectl get pods -n ${NAMESPACE} -l app=katib-controller -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")]}' | jq .
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        Simplified Katib Deployed                ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "✅ Configuration:"
echo "   - Webhooks: Disabled"
echo "   - Validation: Basic only"
echo "   - Metrics Collection: Manual"
echo ""
echo "📊 Available Components:"
kubectl get pods -n ${NAMESPACE} -l 'app in (katib-controller,katib-ui,katib-db-manager)' 2>/dev/null || echo "   Checking components..."
echo ""
echo "🧪 Test Commands:"
echo "   # Check logs"
echo "   kubectl logs -f -n kubeflow -l app=katib-controller"
echo ""
echo "   # List CRDs"
echo "   kubectl get experiments,trials,suggestions -A"
echo ""
echo "   # Apply test experiment"
echo "   kubectl apply -f test-katib-experiment.yaml"
echo ""
echo "   # Watch experiments"
echo "   kubectl get experiments -A -w"
echo ""