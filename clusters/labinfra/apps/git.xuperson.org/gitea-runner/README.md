# Gitea Actions Runner - Rootless Docker Implementation

This directory contains a Gitea Actions runner deployment based on the official rootless Docker example from:
https://gitea.com/gitea/act_runner/src/branch/main/examples/kubernetes/rootless-docker.yaml

## Key Features

### 🐳 Rootless Docker-in-Docker (DinD)
- Uses `gitea/act_runner:nightly-dind-rootless` image
- Secure rootless Docker daemon running inside the container
- Eliminates the need for host Docker socket access
- Better security isolation compared to privileged host socket mounting

### 🔧 Native K3s Docker Integration
- Works seamlessly with K3s clusters using Docker runtime
- Automatic Docker client installation for compatibility
- Uses local Docker daemon with TLS (localhost:2376)

### 🏗️ Docker Buildx Integration
- Uses Docker Buildx for modern container building capabilities
- Multi-platform builds and advanced caching
- Native integration with rootless Docker daemon
- Simplified compared to external BuildKit daemon

### 📦 Persistent Storage
- 5GB persistent volume for runner data and cache
- Uses Longhorn storage class for reliable persistence
- Maintains runner registration across pod restarts

## Architecture

```
┌─────────────────────────────────────────┐
│ act-runner-rootless Pod                 │
├─────────────────────────────────────────┤
│ InitContainers:                         │
│ └── wait-for-secret                     │
├─────────────────────────────────────────┤
│ Main Container:                         │
│ ├── gitea/act_runner:nightly-dind-      │
│ │   rootless                            │
│ ├── Docker daemon (localhost:2376)      │
│ ├── Docker Buildx (modern builds)       │
│ └── Gitea Actions runner                │
└─────────────────────────────────────────┘
```

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `DOCKER_HOST` | `tcp://localhost:2376` | Rootless Docker daemon endpoint |
| `DOCKER_CERT_PATH` | `/certs/client` | Docker TLS certificates path |
| `DOCKER_TLS_VERIFY` | `"1"` | Enable Docker TLS verification |
| `GITEA_INSTANCE_URL` | `https://git.xuperson.org` | Gitea instance URL |
| `GITEA_RUNNER_NAME` | `k3s-rootless-runner` | Runner identifier |
| `GITEA_RUNNER_LABELS` | `ubuntu-latest:docker://node:18-alpine,...` | Supported job types |

## Secrets

### `runner-secret`
- **Created by**: `gitea-runner-token-job.yaml`
- **Contains**: Fresh runner registration token from Gitea API
- **Key**: `token`
- **Usage**: Automatic runner registration on startup

## Deployment Flow

1. **Init Phase**:
   - Wait for runner registration token to be available

2. **Runtime Phase**:
   - Start rootless Docker daemon inside container
   - Install Docker Buildx for modern container builds
   - Clean any existing runner configuration
   - Register with Gitea using fresh API token
   - Start runner daemon to process jobs

## Advantages Over Previous Implementation

### ✅ Security
- No privileged host Docker socket access
- Rootless Docker daemon (runs as user 1000)
- Container isolation with security contexts

### ✅ Simplicity  
- Single container (no sidecar complexity)
- Official upstream image with proven stability
- Fewer moving parts and failure points

### ✅ Compatibility
- Works with K3s Docker runtime out of the box
- Compatible with Docker Buildx for modern builds
- Supports standard Docker Compose workflows

### ✅ Maintenance
- Follows official Gitea examples
- Easier to troubleshoot and debug
- Better alignment with upstream development

## Migration from DinD Sidecar

The previous implementation used a complex DinD sidecar pattern with:
- Separate `docker:27-dind` container
- Host socket mounting for some operations  
- Complex networking between containers

This new implementation simplifies to:
- Single container with embedded rootless Docker
- No sidecar containers or complex networking
- Better security with rootless operation

## Troubleshooting

### Check Runner Registration
```bash
kubectl logs -n gitea deployment/act-runner-rootless -f
```

### Check Docker Daemon
```bash
kubectl exec -n gitea deployment/act-runner-rootless -- docker version
```

### Check Docker Buildx
```bash
kubectl exec -n gitea deployment/act-runner-rootless -- docker buildx version
```

### Verify Persistent Storage
```bash
kubectl get pvc -n gitea
kubectl exec -n gitea deployment/act-runner-rootless -- ls -la /data
```
