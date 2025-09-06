# Gitea Runner Internal Registry Configuration - Complete Solution

## Problem Summary

From our previous testing, we confirmed:
- ✅ **External registry (git.xuperson.org)** works for small images but fails for large images due to Cloudflare limitations
- ✅ **Internal registry (10.42.2.16:3000)** works perfectly for all image sizes without TLS issues
- 🎯 **Current Need**: Configure Gitea runners to use the internal registry endpoint to avoid TLS problems

## Current Runner Configuration Analysis

### 1. DinD Runner Configuration (`gitea-runner-dind.yaml`)

**Current Setup:**
```yaml
# Uses external domain for Gitea instance
- name: GITEA_INSTANCE_URL
  value: https://git.xuperson.org

# Docker daemon with insecure port 2375
args:
- --host=tcp://0.0.0.0:2375
- --host=unix:///var/run/docker.sock

# No TLS for DinD
- name: DOCKER_TLS_CERTDIR
  value: ""
```

### 2. Rootless Runner Configuration (`gitea-runner-rootless-docker.yaml`) 

**Current Setup:**
```yaml
# Uses TLS-enabled Docker daemon
- name: DOCKER_HOST
  value: tcp://localhost:2376
- name: DOCKER_TLS_VERIFY
  value: "1"

# External Gitea instance
- name: GITEA_INSTANCE_URL
  value: "https://git.xuperson.org"
```

## Solutions for Internal Registry Access

### Solution 1: Modify DinD Runner (Recommended)

The DinD runner is already configured for insecure Docker daemon access. We need to add insecure registry configuration:

```yaml
# Enhanced DinD configuration
containers:
- name: daemon
  image: docker:23.0.6-dind
  env:
  - name: DOCKER_TLS_CERTDIR
    value: ""
  - name: DOCKER_DRIVER
    value: overlay2
  # Add insecure registry configuration
  args:
  - --host=tcp://0.0.0.0:2375
  - --host=unix:///var/run/docker.sock
  - --insecure-registry=10.42.2.16:3000
  - --insecure-registry=gitea-http.gitea.svc.cluster.local:3000
```

### Solution 2: ConfigMap Approach for daemon.json

Create a ConfigMap with Docker daemon configuration:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: docker-daemon-config
  namespace: gitea
data:
  daemon.json: |
    {
      "insecure-registries": [
        "10.42.2.16:3000",
        "gitea-http.gitea.svc.cluster.local:3000"
      ],
      "hosts": ["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"]
    }
```

Then mount it in the DinD container:

```yaml
containers:
- name: daemon
  image: docker:23.0.6-dind
  volumeMounts:
  - name: docker-daemon-config
    mountPath: /etc/docker/daemon.json
    subPath: daemon.json
volumes:
- name: docker-daemon-config
  configMap:
    name: docker-daemon-config
```

### Solution 3: Environment Variables for Docker Client

Add environment variables to configure the Docker client in the runner container:

```yaml
containers:
- name: runner
  image: gitea/act_runner:nightly-dind
  env:
  # Existing vars...
  - name: DOCKER_HOST
    value: unix:///var/run/docker.sock
  - name: GITEA_REGISTRY_INSECURE
    value: "true"  
  # Custom env var to pass to workflows
  - name: INTERNAL_REGISTRY
    value: "10.42.2.16:3000"
```

### Solution 4: Internal Service DNS (Most Elegant)

Use Kubernetes DNS instead of IP addresses:

```yaml
# Add to both runner configurations
- name: INTERNAL_REGISTRY_HOST
  value: "gitea-http.gitea.svc.cluster.local:3000"
```

Configure Docker daemon with DNS name:
```bash
--insecure-registry=gitea-http.gitea.svc.cluster.local:3000
```

## Complete Implementation

### Updated DinD Runner Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: docker-daemon-config
  namespace: gitea
data:
  daemon.json: |
    {
      "insecure-registries": [
        "10.42.2.16:3000",
        "gitea-http.gitea.svc.cluster.local:3000"
      ],
      "storage-driver": "overlay2"
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: act-runner
  namespace: gitea
spec:
  template:
    spec:
      containers:
      - name: runner
        image: gitea/act_runner:nightly-dind
        env:
        - name: DOCKER_HOST
          value: unix:///var/run/docker.sock
        - name: GITEA_INSTANCE_URL
          value: https://git.xuperson.org  # Keep for web UI
        - name: INTERNAL_REGISTRY
          value: "gitea-http.gitea.svc.cluster.local:3000"
        # ... other existing env vars
        
      - name: daemon
        image: docker:23.0.6-dind
        env:
        - name: DOCKER_TLS_CERTDIR
          value: ""
        args:
        - dockerd
        - --host=tcp://0.0.0.0:2375
        - --host=unix:///var/run/docker.sock
        - --insecure-registry=10.42.2.16:3000
        - --insecure-registry=gitea-http.gitea.svc.cluster.local:3000
        volumeMounts:
        - name: docker-daemon-config
          mountPath: /etc/docker/daemon.json
          subPath: daemon.json
          
      volumes:
      - name: docker-daemon-config
        configMap:
          name: docker-daemon-config
```

## Workflow Usage Examples

### Example 1: Build and Push to Internal Registry

```yaml
name: Build and Push
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Login to Internal Registry
      run: |
        echo "${{ secrets.GITEA_PASSWORD }}" | docker login \
          $INTERNAL_REGISTRY -u ${{ secrets.GITEA_USERNAME }} --password-stdin
          
    - name: Build and Push
      run: |
        docker build -t $INTERNAL_REGISTRY/giteaadmin/myapp:${{ github.sha }} .
        docker push $INTERNAL_REGISTRY/giteaadmin/myapp:${{ github.sha }}
```

### Example 2: Pull from Internal Registry

```yaml
name: Deploy
on: [push]  
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Login and Pull
      run: |
        echo "${{ secrets.GITEA_PASSWORD }}" | docker login \
          $INTERNAL_REGISTRY -u ${{ secrets.GITEA_USERNAME }} --password-stdin
        docker pull $INTERNAL_REGISTRY/giteaadmin/myapp:latest
        docker run $INTERNAL_REGISTRY/giteaadmin/myapp:latest
```

## Alternative: LoadBalancer for External Access

If you need external access without Cloudflare issues:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: gitea-registry-external
  namespace: gitea
spec:
  type: LoadBalancer
  loadBalancerIP: "192.168.80.110"  # Pick available IP
  ports:
  - name: registry
    port: 5000
    targetPort: 3000
  selector:
    app.kubernetes.io/name: gitea
```

Then configure runners with:
```yaml
- name: EXTERNAL_REGISTRY
  value: "192.168.80.110:5000"
```

## Testing Commands

```bash
# Test internal registry access from runner
kubectl exec -n gitea deployment/act-runner -c runner -- \
  docker pull hello-world

kubectl exec -n gitea deployment/act-runner -c runner -- \
  docker tag hello-world:latest gitea-http.gitea.svc.cluster.local:3000/giteaadmin/test:latest

kubectl exec -n gitea deployment/act-runner -c runner -- \
  docker push gitea-http.gitea.svc.cluster.local:3000/giteaadmin/test:latest
```

## Implementation Checklist

### Phase 1: Basic Configuration
- [ ] Create `docker-daemon-config` ConfigMap
- [ ] Update runner deployment with insecure registry args
- [ ] Add `INTERNAL_REGISTRY` environment variable
- [ ] Test Docker daemon connectivity

### Phase 2: Runner Testing  
- [ ] Deploy updated runner configuration
- [ ] Test basic container operations
- [ ] Test internal registry login
- [ ] Test image push/pull operations

### Phase 3: Workflow Integration
- [ ] Create test workflow using internal registry
- [ ] Add secrets for registry authentication
- [ ] Verify end-to-end functionality
- [ ] Document usage patterns

## Security Considerations

1. **Insecure Registry**: Only accessible within cluster network
2. **Authentication**: Still required for registry operations
3. **Network Isolation**: Internal traffic only via cluster DNS
4. **Privilege Requirements**: DinD container needs privileged mode

## Performance Benefits

- **No Cloudflare Latency**: Direct internal network access
- **No Size Limits**: Bypasses Cloudflare 500MB layer restrictions  
- **Reliable Uploads**: No PATCH request body dropping issues
- **Fast Operations**: Local cluster network speeds

This solution provides a complete workaround for the TLS/Cloudflare issues while maintaining security and performance within your Kubernetes cluster.