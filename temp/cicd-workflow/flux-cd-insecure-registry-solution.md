# Flux CD Internal Registry Solution - Complete Implementation

## Problem Analysis

**Current Issue**: Flux CD deployed the nginx-test successfully, but Kubernetes nodes cannot pull images from the internal registry due to:
1. **TLS/HTTPS requirement**: Kubernetes requires HTTPS for registry communication by default
2. **Node-level configuration**: Each Kubernetes node needs to trust the insecure registry
3. **Container runtime configuration**: Docker/containerd on each node needs insecure registry configuration

## Current Test Status

✅ **Flux CD Deployment**: Successfully applied manifests  
✅ **Service Creation**: LoadBalancer IP assigned (192.168.80.120)  
✅ **Ingress Creation**: nginx-test.xuperson.org configured  
❌ **Image Pull**: Failed due to "http: server gave HTTP response to HTTPS client"

## Solutions for Node-Level Configuration

### Solution 1: Docker Daemon Configuration (K3s with Docker)

Since your nodes are running Docker, configure `/etc/docker/daemon.json` on each node:

```bash
# On each Kubernetes node (k3s-worker-1, k3s-worker-2, k3s-worker-3, k3s-control-*)
sudo cat > /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": [
    "10.42.2.16:3000",
    "gitea-http.gitea.svc.cluster.local:3000"
  ],
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker
```

### Solution 2: K3s Configuration (Recommended)

K3s provides a built-in way to configure registry mirrors and insecure registries:

```bash
# On each K3s node, create /etc/rancher/k3s/registries.yaml
sudo mkdir -p /etc/rancher/k3s
sudo cat > /etc/rancher/k3s/registries.yaml << 'EOF'
configs:
  "10.42.2.16:3000":
    tls:
      insecure_skip_verify: true
  "gitea-http.gitea.svc.cluster.local:3000":
    tls:
      insecure_skip_verify: true
    auth:
      username: giteaadmin
      password: KZnIBgzglHRXYuFqiQe3rCKxPwenfbfuyxrc+Si2O0E=
EOF

# Restart K3s on each node
sudo systemctl restart k3s  # On control nodes
sudo systemctl restart k3s-agent  # On worker nodes
```

### Solution 3: Containerd Configuration (Alternative)

If using containerd directly:

```bash
# On each node, edit /etc/containerd/config.toml
sudo cat >> /etc/containerd/config.toml << 'EOF'

[plugins."io.containerd.grpc.v1.cri".registry.configs."10.42.2.16:3000".tls]
  insecure_skip_verify = true
  
[plugins."io.containerd.grpc.v1.cri".registry.configs."gitea-http.gitea.svc.cluster.local:3000".tls]
  insecure_skip_verify = true

[plugins."io.containerd.grpc.v1.cri".registry.configs."gitea-http.gitea.svc.cluster.local:3000".auth]
  username = "giteaadmin"
  password = "KZnIBgzglHRXYuFqiQe3rCKxPwenfbfuyxrc+Si2O0E="
EOF

sudo systemctl restart containerd
```

## Alternative: LoadBalancer Service for Registry

Create a dedicated LoadBalancer service for the registry to avoid TLS issues:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: gitea-registry-external
  namespace: gitea
  labels:
    app: gitea-registry-external
spec:
  type: LoadBalancer
  loadBalancerIP: "192.168.80.119"  # Pick available IP
  ports:
  - name: registry
    port: 5000
    targetPort: 3000
    protocol: TCP
  selector:
    app.kubernetes.io/name: gitea
    app.kubernetes.io/instance: gitea
```

Then configure nodes for this external IP:

```bash
# On each K3s node
sudo cat > /etc/rancher/k3s/registries.yaml << 'EOF'
configs:
  "192.168.80.119:5000":
    tls:
      insecure_skip_verify: true
    auth:
      username: giteaadmin  
      password: KZnIBgzglHRXYuFqiQe3rCKxPwenfbfuyxrc+Si2O0E=
EOF
```

## Updated Test Deployment

### Using External LoadBalancer Registry

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: nginx-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: 192.168.80.119:5000/giteaadmin/internal-test-nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
      # No imagePullSecrets needed if configured in K3s registries.yaml
```

## Implementation Steps

### Phase 1: Node Configuration
```bash
# SSH to each node and run:
for node in k3s-control-1 k3s-control-2 k3s-worker-1 k3s-worker-2 k3s-worker-3; do
  echo "Configuring node: $node"
  ssh $node 'sudo mkdir -p /etc/rancher/k3s && sudo cat > /etc/rancher/k3s/registries.yaml << "EOF"
configs:
  "10.42.2.16:3000":
    tls:
      insecure_skip_verify: true
  "gitea-http.gitea.svc.cluster.local:3000":
    tls:
      insecure_skip_verify: true
    auth:
      username: giteaadmin
      password: KZnIBgzglHRXYuFqiQe3rCKxPwenfbfuyxrc+Si2O0E=
EOF'
done

# Restart K3s services
for node in k3s-control-1 k3s-control-2; do
  ssh $node 'sudo systemctl restart k3s'
done

for node in k3s-worker-1 k3s-worker-2 k3s-worker-3; do  
  ssh $node 'sudo systemctl restart k3s-agent'
done
```

### Phase 2: Test Image Pull
```bash
# Test pulling image directly on a node
ssh k3s-worker-3 'sudo docker pull 10.42.2.16:3000/giteaadmin/internal-test-nginx:latest'

# Or using crictl (if containerd)  
ssh k3s-worker-3 'sudo crictl pull 10.42.2.16:3000/giteaadmin/internal-test-nginx:latest'
```

### Phase 3: Deploy Updated Manifest
```bash
# Delete existing failed pod
kubectl delete pod -n nginx-test --all

# Flux will recreate the pod, which should now succeed
```

## Verification Commands

```bash
# Check node configuration
for node in k3s-worker-1 k3s-worker-2 k3s-worker-3; do
  echo "=== Node: $node ==="
  ssh $node 'cat /etc/rancher/k3s/registries.yaml'
  ssh $node 'sudo systemctl status k3s-agent'
done

# Check pod status
kubectl get pods -n nginx-test
kubectl describe pod -n nginx-test

# Check service and ingress
kubectl get svc,ingress -n nginx-test

# Test external access
curl -I http://192.168.80.120  # LoadBalancer IP
curl -I https://nginx-test.xuperson.org  # Ingress
```

## Expected Results

After proper configuration:

✅ **Image Pull**: Successful from internal registry  
✅ **Pod Status**: Running  
✅ **LoadBalancer**: Accessible at 192.168.80.120  
✅ **Ingress**: Accessible at nginx-test.xuperson.org  
✅ **Flux CD**: Demonstrating end-to-end GitOps with internal registry

## Automation Script

```bash
#!/bin/bash
# configure-k3s-insecure-registry.sh

REGISTRY_HOST="10.42.2.16:3000"
REGISTRY_DNS="gitea-http.gitea.svc.cluster.local:3000"
REGISTRY_USER="giteaadmin"
REGISTRY_PASS="KZnIBgzglHRXYuFqiQe3rCKxPwenfbfuyxrc+Si2O0E="

NODES=(
  "k3s-control-1"
  "k3s-control-2" 
  "k3s-worker-1"
  "k3s-worker-2"
  "k3s-worker-3"
)

CONTROL_NODES=("k3s-control-1" "k3s-control-2")
WORKER_NODES=("k3s-worker-1" "k3s-worker-2" "k3s-worker-3")

echo "🔧 Configuring K3s insecure registry on all nodes..."

for node in "${NODES[@]}"; do
  echo "📝 Configuring node: $node"
  ssh "$node" "sudo mkdir -p /etc/rancher/k3s && sudo cat > /etc/rancher/k3s/registries.yaml << 'EOF'
configs:
  \"$REGISTRY_HOST\":
    tls:
      insecure_skip_verify: true
    auth:
      username: $REGISTRY_USER
      password: $REGISTRY_PASS
  \"$REGISTRY_DNS\":
    tls:
      insecure_skip_verify: true
    auth:
      username: $REGISTRY_USER
      password: $REGISTRY_PASS
EOF"
done

echo "🔄 Restarting K3s services..."

for node in "${CONTROL_NODES[@]}"; do
  echo "🔄 Restarting k3s on control node: $node"
  ssh "$node" 'sudo systemctl restart k3s'
  sleep 10
done

for node in "${WORKER_NODES[@]}"; do
  echo "🔄 Restarting k3s-agent on worker node: $node"
  ssh "$node" 'sudo systemctl restart k3s-agent'
  sleep 5  
done

echo "✅ Configuration complete! Testing image pull..."

# Test image pull on one worker node
ssh "${WORKER_NODES[0]}" "sudo docker pull $REGISTRY_HOST/giteaadmin/internal-test-nginx:latest"

echo "🚀 Ready to deploy applications using internal registry!"
```

This comprehensive solution addresses the TLS issues and enables Flux CD to successfully deploy applications using your internal Gitea registry.