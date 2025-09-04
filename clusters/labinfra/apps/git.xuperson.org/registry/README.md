# Container Registry Service

Internal container registry integrated with Gitea for CI/CD workflows.

## Overview

A Docker-compatible container registry running in the Gitea namespace for:
- Storing container images built by Gitea Actions
- Internal distribution of application images
- Integration with BuildKit for seamless build-push workflows
- Private image hosting for the development team

## Architecture

- **Deployment**: Docker Registry v2.8 in `gitea` namespace
- **Service**: ClusterIP for internal access only (no external exposure)
- **Storage**: 10Gi Longhorn persistent volume for image storage
- **Integration**: Direct access from Gitea Actions runners and BuildKit

## Access

- **Internal Service**: `registry.gitea.svc.cluster.local:5000`
- **Protocol**: HTTP (internal cluster communication)
- **Access**: Internal cluster only - no external LoadBalancer

## Usage in Gitea Actions

### Push Images from Actions

```yaml
name: Build and Push
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build and Push to Registry
      run: |
        # Build with docker
        docker build -t registry.gitea.svc.cluster.local:5000/myproject:${{ github.sha }} .
        
        # Push to internal registry
        docker push registry.gitea.svc.cluster.local:5000/myproject:${{ github.sha }}
```

### Pull Images in Actions

```yaml
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Deploy Application
      run: |
        # Pull from internal registry
        docker pull registry.gitea.svc.cluster.local:5000/myproject:latest
        
        # Deploy or run containers
        docker run -d registry.gitea.svc.cluster.local:5000/myproject:latest
```

## Integration with BuildKit

BuildKit can directly push to the registry:

```bash
# Build and push in one command
buildctl build \
  --frontend dockerfile.v0 \
  --local context=. \
  --output type=image,name=registry.gitea.svc.cluster.local:5000/myproject:latest,push=true
```

## Registry API Usage

### List Repositories

```bash
# From within cluster
curl http://registry.gitea.svc.cluster.local:5000/v2/_catalog
```

### List Tags

```bash
# List tags for a repository
curl http://registry.gitea.svc.cluster.local:5000/v2/myproject/tags/list
```

### Delete Images

```bash
# Delete is enabled - get digest first
DIGEST=$(curl -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://registry.gitea.svc.cluster.local:5000/v2/myproject/manifests/latest \
  | grep Docker-Content-Digest | cut -d' ' -f2)

# Delete the manifest
curl -X DELETE http://registry.gitea.svc.cluster.local:5000/v2/myproject/manifests/$DIGEST
```

## Storage Management

The registry uses a 10Gi Longhorn persistent volume:

```bash
# Check storage usage
kubectl exec -it deployment/registry -n gitea -- df -h /var/lib/registry

# Check PVC status
kubectl get pvc registry-pvc -n gitea
```

## Scaling

The registry runs as a single replica due to storage constraints:

```bash
# Current configuration (single replica)
kubectl get deployment registry -n gitea

# For multiple replicas, consider using object storage backend
```

## Monitoring

```bash
# Check deployment status
kubectl get pods -n gitea -l app.kubernetes.io/name=registry
kubectl get svc -n gitea registry

# View logs
kubectl logs -n gitea deployment/registry

# Check registry health
kubectl exec -it deployment/registry -n gitea -- \
  wget -q --spider http://localhost:5000/v2/

# Check resource usage
kubectl top pods -n gitea -l app.kubernetes.io/name=registry
```

## Troubleshooting

### Common Issues

1. **Storage Full**
   - Check PVC usage: `kubectl exec deployment/registry -n gitea -- df -h`
   - Clean up old images using registry API
   - Consider increasing PVC size

2. **Push/Pull Failures**
   - Verify service DNS: `registry.gitea.svc.cluster.local:5000`
   - Check pod readiness: `kubectl get pods -n gitea -l app=registry`
   - Test connectivity from runner pods

3. **Persistent Volume Issues**
   - Check PVC status: `kubectl get pvc registry-pvc -n gitea`
   - Verify Longhorn storage class availability

### Debug Commands

```bash
# Test registry API from within cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Inside pod:
# apk add --no-cache curl
# curl http://registry.gitea.svc.cluster.local:5000/v2/

# Check registry configuration
kubectl exec -it deployment/registry -n gitea -- cat /etc/docker/registry/config.yml

# View registry storage
kubectl exec -it deployment/registry -n gitea -- \
  find /var/lib/registry -type f -name "*.json" | head -10
```

## Configuration

Current registry configuration:
- **Storage**: Filesystem at `/var/lib/registry`
- **Delete**: Enabled for image cleanup
- **Health checks**: HTTP endpoints on `/v2/`
- **Resources**: 256Mi memory request, 512Mi limit

## Security Notes

- Registry runs with minimal privileges
- No external exposure - internal cluster access only
- HTTP communication (acceptable for internal cluster networking)
- Storage is persistent and backed by Longhorn for data durability
