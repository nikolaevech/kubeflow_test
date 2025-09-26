#!/bin/bash

# Fix Missing CRDs for Katib
# This script adds the missing Trial and Suggestion CRDs

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "╔══════════════════════════════════════════════════╗"
echo "║     Fixing Missing Katib CRDs                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Step 1: Check existing CRDs
log_info "Step 1: Checking existing CRDs..."
kubectl get crd | grep kubeflow.org || echo "No Kubeflow CRDs found yet"
echo ""

# Step 2: Create missing CRDs
log_info "Step 2: Creating missing Trial and Suggestion CRDs..."

cat <<EOF | kubectl apply -f -
---
# Trial CRD
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: trials.kubeflow.org
spec:
  group: kubeflow.org
  names:
    kind: Trial
    listKind: TrialList
    plural: trials
    singular: trial
    shortNames:
      - tr
  scope: Namespaced
  versions:
    - name: v1beta1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              x-kubernetes-preserve-unknown-fields: true
            status:
              type: object
              x-kubernetes-preserve-unknown-fields: true
      subresources:
        status: {}
---
# Suggestion CRD
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: suggestions.kubeflow.org
spec:
  group: kubeflow.org
  names:
    kind: Suggestion
    listKind: SuggestionList
    plural: suggestions
    singular: suggestion
    shortNames:
      - sg
  scope: Namespaced
  versions:
    - name: v1beta1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              x-kubernetes-preserve-unknown-fields: true
            status:
              type: object
              x-kubernetes-preserve-unknown-fields: true
      subresources:
        status: {}
EOF

log_success "CRDs created"
echo ""

# Step 3: Wait for CRDs to be established
log_info "Step 3: Waiting for CRDs to be established..."
kubectl wait --for condition=established --timeout=60s crd/trials.kubeflow.org
kubectl wait --for condition=established --timeout=60s crd/suggestions.kubeflow.org
log_success "CRDs are established"
echo ""

# Step 4: Verify CRDs
log_info "Step 4: Verifying all Kubeflow CRDs..."
kubectl get crd | grep kubeflow.org
echo ""

# Step 5: Delete and recreate katib-controller pods
log_info "Step 5: Restarting katib-controller pods..."

# Delete all katib-controller pods to force restart
kubectl delete pods -n kubeflow -l app=katib-controller

log_info "Waiting for new katib-controller pods to start..."
sleep 10

# Wait for at least one katib-controller to be ready
kubectl wait --for=condition=Ready pods -l app=katib-controller -n kubeflow --timeout=300s || {
  log_error "katib-controller still not ready after CRD fix"
  log_info "Checking logs..."
  kubectl logs -l app=katib-controller -n kubeflow --tail=30
  exit 1
}

log_success "katib-controller is now running"
echo ""

# Step 6: Check ml-pipeline
log_info "Step 6: Checking ml-pipeline status..."

if kubectl get endpoints ml-pipeline -n kubeflow -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q .; then
  log_success "ml-pipeline has endpoints"
else
  log_error "ml-pipeline has no endpoints - pod not passing readiness probe"
  log_info "Checking ml-pipeline logs..."
  kubectl logs -l app=ml-pipeline -n kubeflow --tail=30
  
  log_info "Restarting ml-pipeline..."
  kubectl delete pods -n kubeflow -l app=ml-pipeline
  sleep 10
  
  kubectl wait --for=condition=Ready pods -l app=ml-pipeline -n kubeflow --timeout=300s || {
    log_error "ml-pipeline still not ready"
    exit 1
  }
fi

log_success "ml-pipeline is healthy"
echo ""

# Step 7: Restart persistenceagent
log_info "Step 7: Restarting ml-pipeline-persistenceagent..."
kubectl delete pods -n kubeflow -l app=ml-pipeline-persistenceagent
sleep 5

kubectl wait --for=condition=Ready pods -l app=ml-pipeline-persistenceagent -n kubeflow --timeout=180s || {
  log_error "persistenceagent still not ready"
  log_info "This might be normal if ml-pipeline is still initializing"
}

echo ""

# Step 8: Final status
log_info "Step 8: Final deployment status..."
echo ""

echo "Kubeflow pods:"
kubectl get pods -n kubeflow
echo ""

RUNNING=$(kubectl get pods -n kubeflow --no-headers | grep -c "Running.*1/1" || echo "0")
CRASH=$(kubectl get pods -n kubeflow --no-headers | grep -c "CrashLoopBackOff" || echo "0")

echo "═══════════════════════════════════════════════════"
echo "Summary:"
echo "  Running pods: $RUNNING"
echo "  CrashLoopBackOff: $CRASH"
echo "═══════════════════════════════════════════════════"
echo ""

if [ "$CRASH" -eq 0 ]; then
  log_success "All pods are healthy! 🎉"
  echo ""
  MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "UNKNOWN")
  echo "Access your services:"
  echo "  Dashboard:     http://${MINIKUBE_IP}:30080"
  echo "  Pipelines:     http://${MINIKUBE_IP}:30888"
  echo "  Katib:         http://${MINIKUBE_IP}:30777"
  echo "  JupyterLab:    http://${MINIKUBE_IP}:30666"
  echo "  MinIO Console: http://${MINIKUBE_IP}:30900"
else
  log_error "Some pods still have issues"
  echo ""
  echo "Check logs with:"
  echo "  kubectl logs <pod-name> -n kubeflow"
  echo ""
  echo "Or run full diagnostics:"
  echo "  ./scripts/diagnose-deployment.sh"
fi

echo ""
log_success "CRD fix completed!"