#!/bin/bash

# Fix Katib Controller - Generate TLS Certificates and Configure Webhooks
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

cat << "EOF"
╔══════════════════════════════════════════════════╗
║   Fixing Katib Controller Webhook Certificates  ║
╚══════════════════════════════════════════════════╝
EOF

echo ""

NAMESPACE="kubeflow"
SERVICE_NAME="katib-controller"
SECRET_NAME="katib-webhook-cert"

# Step 1: Create certificate generation script
log_info "Step 1: Creating certificate generation script..."

cat > /tmp/generate-katib-certs.sh << 'CERTGEN'
#!/bin/bash

NAMESPACE=$1
SERVICE_NAME=$2
SECRET_NAME=$3

# Create temporary directory
TMPDIR=$(mktemp -d)
cd $TMPDIR

# Generate CA
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=katib-ca" -days 3650 -out ca.crt

# Generate server certificate
cat > server.conf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${SERVICE_NAME}
DNS.2 = ${SERVICE_NAME}.${NAMESPACE}
DNS.3 = ${SERVICE_NAME}.${NAMESPACE}.svc
DNS.4 = ${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local
EOF

openssl genrsa -out tls.key 2048
openssl req -new -key tls.key -subj "/CN=${SERVICE_NAME}.${NAMESPACE}.svc" -out server.csr -config server.conf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt -days 3650 -extensions v3_req -extfile server.conf

# Create or update secret
kubectl create secret generic ${SECRET_NAME} \
  --from-file=tls.key=tls.key \
  --from-file=tls.crt=tls.crt \
  --from-file=ca.crt=ca.crt \
  -n ${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# Get CA bundle for webhook configs
CA_BUNDLE=$(cat ca.crt | base64 | tr -d '\n')
echo $CA_BUNDLE > /tmp/ca-bundle.txt

# Cleanup
cd /
rm -rf $TMPDIR

echo "Certificates generated successfully!"
CERTGEN

chmod +x /tmp/generate-katib-certs.sh

# Step 2: Generate certificates
log_info "Step 2: Generating TLS certificates..."
bash /tmp/generate-katib-certs.sh $NAMESPACE $SERVICE_NAME $SECRET_NAME
log_success "Certificates generated"

# Get CA bundle
CA_BUNDLE=$(cat /tmp/ca-bundle.txt)

# Step 3: Create webhook service if not exists
log_info "Step 3: Ensuring webhook service exists..."

kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  namespace: ${NAMESPACE}
spec:
  selector:
    app: katib-controller
  ports:
    - name: webhook
      port: 443
      targetPort: 8443
EOF

log_success "Service configured"

# Step 4: Update Katib deployment with cert volume
log_info "Step 4: Updating Katib controller deployment..."

kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: katib-controller
  namespace: ${NAMESPACE}
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
          args:
            - --webhook-port=8443
            - --trial-resources=Job.v1.batch
            - --webhook-service-name=${SERVICE_NAME}
          env:
            - name: KATIB_CORE_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - containerPort: 8443
              name: webhook
              protocol: TCP
            - containerPort: 8080
              name: metrics
              protocol: TCP
          volumeMounts:
            - name: cert
              mountPath: /tmp/cert
              readOnly: true
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
      volumes:
        - name: cert
          secret:
            secretName: ${SECRET_NAME}
            items:
              - key: tls.crt
                path: tls.crt
              - key: tls.key
                path: tls.key
EOF

log_success "Deployment updated with certificates"

# Step 5: Configure webhooks
log_info "Step 5: Configuring ValidatingWebhookConfiguration..."

kubectl apply -f - << EOF
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: katib-validating-webhook-config
webhooks:
  - name: validator.experiment.katib.kubeflow.org
    admissionReviewVersions: ["v1", "v1beta1"]
    clientConfig:
      service:
        name: ${SERVICE_NAME}
        namespace: ${NAMESPACE}
        path: /validate-experiment
      caBundle: ${CA_BUNDLE}
    rules:
      - apiGroups: ["kubeflow.org"]
        apiVersions: ["v1beta1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["experiments"]
    failurePolicy: Fail
    sideEffects: None
EOF

log_success "ValidatingWebhookConfiguration created"

log_info "Step 6: Configuring MutatingWebhookConfiguration..."

kubectl apply -f - << EOF
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: katib-mutating-webhook-config
webhooks:
  - name: mutator.experiment.katib.kubeflow.org
    admissionReviewVersions: ["v1", "v1beta1"]
    clientConfig:
      service:
        name: ${SERVICE_NAME}
        namespace: ${NAMESPACE}
        path: /mutate-experiment
      caBundle: ${CA_BUNDLE}
    rules:
      - apiGroups: ["kubeflow.org"]
        apiVersions: ["v1beta1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["experiments"]
    failurePolicy: Fail
    sideEffects: None
  - name: mutator.pod.katib.kubeflow.org
    admissionReviewVersions: ["v1", "v1beta1"]
    clientConfig:
      service:
        name: ${SERVICE_NAME}
        namespace: ${NAMESPACE}
        path: /mutate-pod
      caBundle: ${CA_BUNDLE}
    rules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
    failurePolicy: Ignore
    sideEffects: None
    namespaceSelector:
      matchLabels:
        katib.kubeflow.org/metrics-collector-injection: enabled
EOF

log_success "MutatingWebhookConfiguration created"

# Step 7: Restart controller pods
log_info "Step 7: Restarting Katib controller pods..."
kubectl delete pods -n ${NAMESPACE} -l app=katib-controller --ignore-not-found=true
log_info "Waiting for new pods to start..."
sleep 10

# Step 8: Wait for pods to be ready
log_info "Step 8: Waiting for Katib controller to be ready (timeout: 120s)..."
if kubectl wait --for=condition=Ready pods -l app=katib-controller -n ${NAMESPACE} --timeout=120s 2>/dev/null; then
    log_success "Katib controller is ready!"
else
    log_warning "Controller taking longer than expected"
    log_info "Current status:"
    kubectl get pods -n ${NAMESPACE} -l app=katib-controller
    echo ""
    log_info "Recent logs:"
    kubectl logs -n ${NAMESPACE} -l app=katib-controller --tail=20
fi

# Step 9: Verify webhooks
log_info "Step 9: Verifying webhook configurations..."
echo ""
echo "ValidatingWebhookConfiguration:"
kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io katib-validating-webhook-config -o jsonpath='{.webhooks[0].clientConfig.service}' 2>/dev/null && echo " ✓" || echo " ✗"

echo "MutatingWebhookConfiguration:"
kubectl get mutatingwebhookconfigurations.admissionregistration.k8s.io katib-mutating-webhook-config -o jsonpath='{.webhooks[0].clientConfig.service}' 2>/dev/null && echo " ✓" || echo " ✗"

# Step 10: Final verification
echo ""
log_info "Step 10: Final verification..."
echo ""
echo "Katib Pods Status:"
kubectl get pods -n ${NAMESPACE} -l app=katib-controller

echo ""
echo "Katib Service:"
kubectl get svc -n ${NAMESPACE} ${SERVICE_NAME}

echo ""
echo "Webhook Secret:"
kubectl get secret -n ${NAMESPACE} ${SECRET_NAME}

# Cleanup
rm -f /tmp/generate-katib-certs.sh /tmp/ca-bundle.txt

echo ""
cat << "EOF"
╔══════════════════════════════════════════════════╗
║              Fix Complete!                       ║
╚══════════════════════════════════════════════════╝

✓ TLS certificates generated
✓ Webhook configurations created
✓ Katib controller updated
✓ Services configured

Next steps:
1. Check controller logs: kubectl logs -f -n kubeflow -l app=katib-controller
2. Test with an experiment: kubectl apply -f examples/experiment.yaml
3. Monitor status: kubectl get experiments -A

If issues persist:
- Check webhook endpoints: kubectl get validatingwebhookconfigurations
- Verify certificates: kubectl get secret katib-webhook-cert -n kubeflow
- Review logs: kubectl logs -n kubeflow -l app=katib-controller
EOF

echo ""