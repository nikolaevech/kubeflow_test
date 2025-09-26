#!/bin/bash

# Katib Diagnostic Script
# Comprehensive check of Katib installation

set -e

NAMESPACE="kubeflow"

echo "╔══════════════════════════════════════════════════╗"
echo "║          Katib Diagnostic Report                ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# 1. Check CRDs
echo "1️⃣  Custom Resource Definitions (CRDs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CRDS=$(kubectl get crds | grep kubeflow.org | wc -l)
echo "Found ${CRDS} Katib CRDs:"
kubectl get crds | grep kubeflow.org || echo "  ❌ No Katib CRDs found"
echo ""

# 2. Check ServiceAccount & RBAC
echo "2️⃣  ServiceAccount & RBAC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get serviceaccount katib-controller -n ${NAMESPACE} >/dev/null 2>&1 && \
  echo "✅ ServiceAccount: katib-controller exists" || \
  echo "❌ ServiceAccount: katib-controller NOT found"

kubectl get clusterrole katib-controller >/dev/null 2>&1 && \
  echo "✅ ClusterRole: katib-controller exists" || \
  echo "❌ ClusterRole: katib-controller NOT found"

kubectl get clusterrolebinding katib-controller >/dev/null 2>&1 && \
  echo "✅ ClusterRoleBinding: katib-controller exists" || \
  echo "❌ ClusterRoleBinding: katib-controller NOT found"
echo ""

# 3. Check Deployments
echo "3️⃣  Deployments Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Katib Controller:"
kubectl get deployment katib-controller -n ${NAMESPACE} -o wide 2>/dev/null || echo "  ❌ Not found"

echo ""
echo "Katib DB Manager:"
kubectl get deployment katib-db-manager -n ${NAMESPACE} -o wide 2>/dev/null || echo "  ❌ Not found"

echo ""
echo "Katib UI:"
kubectl get deployment katib-ui -n ${NAMESPACE} -o wide 2>/dev/null || echo "  ❌ Not found"
echo ""

# 4. Check Pods
echo "4️⃣  Pod Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n ${NAMESPACE} -l 'app in (katib-controller,katib-ui,katib-db-manager)' 2>/dev/null || \
  echo "❌ No Katib pods found"
echo ""

# 5. Check Services
echo "5️⃣  Services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get svc -n ${NAMESPACE} | grep katib || echo "❌ No Katib services found"
echo ""

# 6. Check Webhooks
echo "6️⃣  Webhook Configurations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ValidatingWebhookConfiguration:"
kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io katib-validating-webhook-config >/dev/null 2>&1 && \
  echo "  ✅ Exists" || echo "  ❌ Not found"

echo "MutatingWebhookConfiguration:"
kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io katib-mutating-webhook-config >/dev/null 2>&1 && \
  echo "  ✅ Exists" || echo "  ❌ Not found"
echo ""

# 7. Check Secrets
echo "7️⃣  Secrets"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get secret katib-webhook-cert -n ${NAMESPACE} >/dev/null 2>&1 && \
  echo "✅ Webhook cert secret exists" || echo "❌ Webhook cert secret NOT found"
echo ""

# 8. Check Katib Controller Logs
echo "8️⃣  Recent Controller Logs (last 30 lines)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CONTROLLER_POD=$(kubectl get pods -n ${NAMESPACE} -l app=katib-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$CONTROLLER_POD" ]; then
    echo "Pod: ${CONTROLLER_POD}"
    echo ""
    kubectl logs -n ${NAMESPACE} ${CONTROLLER_POD} --tail=30 2>&1 | head -30
else
    echo "❌ No controller pod found"
fi
echo ""

# 9. Check for Common Errors
echo "9️⃣  Error Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$CONTROLLER_POD" ]; then
    LOGS=$(kubectl logs -n ${NAMESPACE} ${CONTROLLER_POD} --tail=100 2>&1)
    
    # Check for specific errors
    if echo "$LOGS" | grep -q "no such file or directory"; then
        echo "❌ FOUND: Certificate/file not found error"
        echo "$LOGS" | grep "no such file" | head -3
        echo ""
    fi
    
    if echo "$LOGS" | grep -q "failed to get informer"; then
        echo "❌ FOUND: Informer sync errors (CRD issues)"
        echo ""
    fi
    
    if echo "$LOGS" | grep -q "flag provided but not defined"; then
        echo "❌ FOUND: Invalid command-line flags"
        echo "$LOGS" | grep "flag provided" | head -3
        echo ""
    fi
    
    if echo "$LOGS" | grep -q "connection refused"; then
        echo "❌ FOUND: Connection issues"
        echo ""
    fi
    
    # Check for success indicators
    if echo "$LOGS" | grep -q "Starting workers"; then
        echo "✅ Controller started workers successfully"
    fi
    
    if echo "$LOGS" | grep -q "Starting Controller"; then
        echo "✅ Controllers initialized"
    fi
else
    echo "❌ Cannot analyze - no controller pod running"
fi
echo ""

# 10. Resource Status
echo "🔟  Resource Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Experiments:"
kubectl get experiments -A 2>/dev/null | wc -l | xargs echo "  Count:" || echo "  ❌ Cannot check"

echo "Trials:"
kubectl get trials -A 2>/dev/null | wc -l | xargs echo "  Count:" || echo "  ❌ Cannot check"

echo "Suggestions:"
kubectl get suggestions -A 2>/dev/null | wc -l | xargs echo "  Count:" || echo "  ❌ Cannot check"
echo ""

# 11. Recommended Actions
echo "📋 Recommended Actions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Analyze pod status
if [ -n "$CONTROLLER_POD" ]; then
    POD_STATUS=$(kubectl get pod ${CONTROLLER_POD} -n ${NAMESPACE} -o jsonpath='{.status.phase}')
    READY_STATUS=$(kubectl get pod ${CONTROLLER_POD} -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    
    if [ "$POD_STATUS" = "Running" ] && [ "$READY_STATUS" = "True" ]; then
        echo "✅ Katib controller is healthy!"
        echo ""
        echo "Test with:"
        echo "  kubectl apply -f test-katib-experiment.yaml"
    elif [ "$POD_STATUS" = "CrashLoopBackOff" ] || [ "$POD_STATUS" = "Error" ]; then
        echo "🔧 Controller is crashing. Try:"
        echo ""
        echo "1. Simplify deployment (remove webhooks):"
        echo "   ./scripts/disable-katib-webhooks.sh"
        echo ""
        echo "2. Check deployment configuration:"
        echo "   kubectl describe deployment katib-controller -n kubeflow"
        echo ""
        echo "3. View full logs:"
        echo "   kubectl logs ${CONTROLLER_POD} -n kubeflow --previous"
    else
        echo "⏳ Controller is starting..."
        echo ""
        echo "Wait a moment and check again:"
        echo "  kubectl get pods -n kubeflow -l app=katib-controller -w"
    fi
else
    echo "❌ No controller pod exists!"
    echo ""
    echo "Deploy Katib:"
    echo "  kubectl apply -f 04-katib/"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnostic complete!"
echo ""