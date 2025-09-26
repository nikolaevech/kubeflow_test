# 🚀 Kubeflow ML Platform on Minikube

Production-ready Kubeflow setup optimized for local development and testing with Minikube.

## 📋 Table of Contents

* [Architecture](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#architecture)
* [Prerequisites](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#prerequisites)
* [Quick Start](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#quick-start)
* [Components](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#components)
* [Access URLs](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#access-urls)
* [Usage Examples](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#usage-examples)
* [Troubleshooting](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#troubleshooting)
* [Advanced Configuration](https://claude.ai/chat/41d62664-e013-4c95-b54c-a6a38b4c21f2#advanced-configuration)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Custom Dashboard                      │
│                  (Unified Web Interface)                 │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌──────────────┐   ┌──────────────┐
│   Kubeflow    │   │    Katib     │   │  JupyterLab  │
│   Pipelines   │   │ (HPO/NAS)    │   │  Notebooks   │
└───────────────┘   └──────────────┘   └──────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
        ┌───────────────────────────────────────┐
        │           Infrastructure              │
        ├───────────────┬──────────────────────┤
        │    MinIO      │       MySQL          │
        │  (S3 Storage) │    (Metadata DB)     │
        └───────────────┴──────────────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   KServe     │
                    │ (Model Serve)│
                    └──────────────┘
```

### Key Features

* **Kubeflow Pipelines** : Orchestrate ML workflows with Argo Workflows
* **Katib** : Automated hyperparameter tuning
* **KServe** : Production model serving
* **JupyterLab** : Interactive development environment
* **MinIO** : S3-compatible object storage
* **MySQL** : Reliable metadata persistence
* **Custom Dashboard** : Unified access to all services

---

## 📦 Prerequisites

### Required Software

1. **Minikube** (v1.30+)
   ```bash
   # macOS
   brew install minikube

   # Linux
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   ```
2. **kubectl** (v1.28+)
   ```bash
   # macOS
   brew install kubectl

   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install kubectl /usr/local/bin/kubectl
   ```
3. **Docker** or other container runtime

### System Requirements

* **CPU** : 6+ cores
* **RAM** : 12GB minimum (16GB recommended)
* **Disk** : 50GB free space
* **OS** : macOS, Linux, or Windows with WSL2

---

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <your-repo>
cd kubeflow-platform

# Make scripts executable
chmod +x scripts/*.sh
chmod +x 00-prerequisites/*.sh
```

### 2. Deploy Everything

```bash
# One-command deployment
./scripts/deploy-all.sh
```

This will:

* ✅ Create Minikube cluster with proper resources
* ✅ Install Argo Workflows
* ✅ Deploy infrastructure (MinIO, MySQL)
* ✅ Deploy all Kubeflow components
* ✅ Setup custom dashboard

**Deployment takes ~10-15 minutes** depending on your internet speed.

### 3. Access Services

After deployment, access the dashboard:

```bash
# Get Minikube IP
minikube ip

# Access dashboard at:
http://<minikube-ip>:30080
```

Or use port forwarding for localhost access:

```bash
./scripts/port-forward.sh

# Access at:
# http://localhost:8080
```

---

## 🔧 Components

### Kubeflow Pipelines

 **Purpose** : Build and orchestrate ML workflows

 **Access** : Port 30888 (NodePort) or 8888 (port-forward)

 **Key Features** :

* Visual pipeline builder
* Argo Workflows backend
* MySQL persistence
* MinIO artifact storage

 **Example Pipeline** :

```python
from kfp import dsl

@dsl.pipeline(name='Basic Pipeline')
def my_pipeline(data_path: str):
    # Your pipeline steps here
    pass
```

### Katib

 **Purpose** : Hyperparameter optimization and NAS

 **Access** : Port 30777 (NodePort) or 8777 (port-forward)

 **Supported Algorithms** :

* Random Search
* Grid Search
* Bayesian Optimization
* Hyperband

 **Example Experiment** :

```yaml
apiVersion: kubeflow.org/v1beta1
kind: Experiment
metadata:
  name: random-experiment
spec:
  algorithm:
    algorithmName: random
  maxTrialCount: 10
  objective:
    type: maximize
    goal: 0.99
    objectiveMetricName: accuracy
  parameters:
  - name: lr
    parameterType: double
    feasibleSpace:
      min: "0.001"
      max: "0.1"
```

### JupyterLab

 **Purpose** : Interactive notebook development

 **Access** : Port 30666 (NodePort) or 8866 (port-forward)

 **Pre-installed Libraries** :

* TensorFlow
* PyTorch
* Scikit-learn
* Pandas, NumPy
* KFP SDK

 **S3 Access in Notebooks** :

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='http://minio-service.ml-infrastructure:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin123'
)

# List buckets
s3.list_buckets()
```

### KServe

 **Purpose** : Production model serving

 **Supported Frameworks** :

* Scikit-learn
* XGBoost
* PyTorch
* TensorFlow

 **Example InferenceService** :

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sklearn-iris
spec:
  predictor:
    sklearn:
      storageUri: s3://models/iris
```

### MinIO

 **Purpose** : S3-compatible object storage

 **Access** : Console at port 30900

 **Credentials** :

* Username: `minioadmin`
* Password: `minioadmin123`

 **Buckets** :

* `mlpipeline` - Pipeline artifacts
* `models` - Model storage
* `data` - Training datasets

### MySQL

 **Purpose** : Metadata persistence

 **Databases** :

* `mlpipeline` - Pipeline metadata
* `katib` - Experiment results

 **Access from pod** :

```bash
kubectl exec -it deployment/mysql -n ml-infrastructure -- mysql -uroot -prootpass123
```

---

## 🌐 Access URLs

### Using Minikube IP

```bash
MINIKUBE_IP=$(minikube ip)

# All services
echo "Dashboard:     http://${MINIKUBE_IP}:30080"
echo "Pipelines:     http://${MINIKUBE_IP}:30888"
echo "Katib:         http://${MINIKUBE_IP}:30777"
echo "JupyterLab:    http://${MINIKUBE_IP}:30666"
echo "MinIO:         http://${MINIKUBE_IP}:30900"
```

### Using Port Forwarding (Localhost)

```bash
./scripts/port-forward.sh

# Access at localhost
Dashboard:     http://localhost:8080
Pipelines:     http://localhost:8888
Katib:         http://localhost:8777
JupyterLab:    http://localhost:8866
MinIO:         http://localhost:9001
```

---

## 💡 Usage Examples

### Example 1: Run a Simple Pipeline

```python
# In JupyterLab
import kfp
import kfp.dsl as dsl

@dsl.component
def train_model():
    print("Training model...")
    return {"accuracy": 0.95}

@dsl.pipeline(name='Simple Training Pipeline')
def training_pipeline():
    train_task = train_model()

# Compile and run
client = kfp.Client(host='http://ml-pipeline.kubeflow:8888')
client.create_run_from_pipeline_func(training_pipeline, arguments={})
```

### Example 2: Hyperparameter Tuning with Katib

```yaml
apiVersion: kubeflow.org/v1beta1
kind: Experiment
metadata:
  name: xgboost-tuning
  namespace: kubeflow
spec:
  algorithm:
    algorithmName: bayesianoptimization
  maxTrialCount: 20
  parallelTrialCount: 3
  objective:
    type: maximize
    objectiveMetricName: f1-score
  parameters:
  - name: max_depth
    parameterType: int
    feasibleSpace:
      min: "3"
      max: "10"
  - name: learning_rate
    parameterType: double
    feasibleSpace:
      min: "0.01"
      max: "0.3"
  trialTemplate:
    primaryContainerName: training
    trialSpec:
      apiVersion: batch/v1
      kind: Job
      spec:
        template:
          spec:
            containers:
            - name: training
              image: your-training-image:latest
              command:
              - python
              - train.py
              - --max_depth=${trialParameters.max_depth}
              - --learning_rate=${trialParameters.learning_rate}
            restartPolicy: Never
```

### Example 3: Deploy Model with KServe

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sklearn-model
  namespace: kubeflow
spec:
  predictor:
    sklearn:
      storageUri: s3://models/sklearn-model
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 1
          memory: 1Gi
```

Test the model:

```bash
# Get service URL
kubectl get isvc sklearn-model -n kubeflow

# Send prediction request
curl -X POST \
  http://<service-url>/v1/models/sklearn-model:predict \
  -H 'Content-Type: application/json' \
  -d '{"instances": [[5.1, 3.5, 1.4, 0.2]]}'
```

---

## 🔍 Troubleshooting

### Check Pod Status

```bash
# All pods
kubectl get pods -A

# Specific namespace
kubectl get pods -n kubeflow

# Watch pods
kubectl get pods -n kubeflow -w
```

### View Logs

```bash
# Pipeline API logs
kubectl logs -f deployment/ml-pipeline -n kubeflow

# Katib controller logs
kubectl logs -f deployment/katib-controller -n kubeflow

# JupyterLab logs
kubectl logs -f deployment/jupyterlab -n kubeflow-user
```

### Common Issues

#### 1. Pods stuck in Pending

```bash
# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Check resources
kubectl top nodes
kubectl describe node minikube
```

 **Solution** : Increase Minikube resources

```bash
minikube delete
minikube start --cpus=8 --memory=16g --disk-size=60g
```

#### 2. Pipeline fails to start

```bash
# Check Argo Workflows
kubectl get pods -n argo

# Check pipeline configuration
kubectl get cm ml-pipeline-config -n kubeflow -o yaml
```

#### 3. MinIO connection issues

```bash
# Test MinIO connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://minio-service.ml-infrastructure:9000/minio/health/live
```

#### 4. Database connection errors

```bash
# Check MySQL status
kubectl exec -it deployment/mysql -n ml-infrastructure -- \
  mysql -uroot -prootpass123 -e "SHOW DATABASES;"
```

### Reset Everything

```bash
# Complete cleanup
./scripts/uninstall.sh

# Redeploy
./scripts/deploy-all.sh
```

---

## ⚙️ Advanced Configuration

### Increase Resources

Edit `00-prerequisites/minikube-setup.sh`:

```bash
minikube start \
  --cpus=8 \          # Increase CPU
  --memory=16g \      # Increase RAM
  --disk-size=100g \  # Increase disk
  ...
```

### Enable GPU Support

```bash
minikube start --driver=docker --gpus all

# Deploy GPU device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/main/nvidia-device-plugin.yml
```

### Configure Persistent Storage

Use hostPath for development:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: models-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: /data/models
```

### Add Monitoring (Prometheus + Grafana)

```bash
# Install Prometheus Operator
kubectl create namespace monitoring
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml

# Deploy ServiceMonitors for Kubeflow
kubectl apply -f monitoring/servicemonitors.yaml
```

### Customize Dashboard

Edit `06-custom-dashboard/dashboard-deployment.yaml`:

```yaml
data:
  index.html: |
    <!-- Your custom HTML -->
```

### Enable Istio (Optional)

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install
istioctl install --set profile=demo -y

# Enable sidecar injection
kubectl label namespace kubeflow istio-injection=enabled
```

---

## 📊 Performance Tips

1. **Pipeline Optimization**
   * Use caching for repeated operations
   * Parallelize independent tasks
   * Use appropriate resource requests/limits
2. **Storage Management**
   * Regularly clean up old artifacts
   * Use lifecycle policies in MinIO
   * Archive completed experiments
3. **Resource Allocation**
   ```yaml
   resources:
     requests:
       cpu: "500m"      # Guaranteed
       memory: "1Gi"
     limits:
       cpu: "2"         # Maximum
       memory: "4Gi"
   ```

---

## 🛡️ Security Considerations

### Production Checklist

* [ ] Change default passwords (MinIO, MySQL)
* [ ] Enable TLS/SSL for all services
* [ ] Implement RBAC policies
* [ ] Use secrets for credentials
* [ ] Enable network policies
* [ ] Regular security updates

### Example Secret Management

```bash
# Create secret from file
kubectl create secret generic model-creds \
  --from-file=credentials.json \
  -n kubeflow

# Use in pod
volumeMounts:
- name: creds
  mountPath: /secrets
  readOnly: true
volumes:
- name: creds
  secret:
    secretName: model-creds
```

---

## 📝 Additional Resources

* [Kubeflow Documentation](https://www.kubeflow.org/docs/)
* [Argo Workflows](https://argoproj.github.io/workflows/)
* [KServe Documentation](https://kserve.github.io/website/)
* [Katib Guide](https://www.kubeflow.org/docs/components/katib/)

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📄 License

MIT License - see LICENSE file for details

---

## 🙏 Acknowledgments

* Kubeflow Community
* Argo Project
* KServe Team
* Anthropic Claude for documentation assistance

---

**Happy ML Engineering!** 🚀🤖
