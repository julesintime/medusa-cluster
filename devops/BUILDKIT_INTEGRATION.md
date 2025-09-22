# BuildKit Integration with ArgoCD Workflows

## Overview: Replacing Gitea Runner + Tekton

### Current Setup (Gitea Runner + Tekton)
```
📥 Git Push → Gitea → Gitea Actions Runner → Tekton Pipeline → BuildKit → Registry → K8s
```

### New Setup (ArgoCD Workflows + BuildKit)
```
📥 Git Push → Gitea → Webhook → Argo Events → Argo Workflow → BuildKit → Registry → ArgoCD → K8s
```

## Benefits of ArgoCD + BuildKit Approach

### vs Current Gitea Runner + Tekton
- **✅ Simpler**: Single workflow engine (Argo) vs dual (Gitea Actions + Tekton)
- **✅ Better UI**: Rich ArgoCD dashboard vs limited Tekton UI
- **✅ Native GitOps**: ArgoCD handles both CI and CD natively
- **✅ Event-Driven**: Argo Events provides robust webhook handling
- **✅ Scalable**: Kubernetes-native scaling vs static runner instances

### BuildKit Advantages
- **🚀 Faster Builds**: Parallel multi-stage builds
- **🔒 Rootless**: No Docker daemon required (security)
- **📦 Cache Optimization**: Layer and mount caching
- **🏗️ Multi-Platform**: ARM64/AMD64 builds

## Implementation Architecture

### 1. Event Flow
```yaml
Gitea Repository (git.xuperson.org)
    │ webhook on push
    ▼
Argo Events EventSource (webhooks.xuperson.org/gitea)
    │ filters for main/master branch
    ▼
Argo Events Sensor
    │ triggers workflow
    ▼
Argo Workflow (ci-cd-buildkit-deploy)
    │ runs BuildKit build
    ▼
Gitea Container Registry (git.xuperson.org)
    │ stores built images
    ▼
ArgoCD Application Sync
    │ deploys to namespace
    ▼
Kubernetes Deployment
```

### 2. BuildKit Workflow Integration

#### Current Hello App Integration
Your existing `hello.xuperson.org` CI/CD setup uses:
- ✅ BuildKit daemon for builds
- ✅ Gitea registry push/pull
- ✅ Flux image automation

#### Migration Strategy
```bash
# Current: Gitea Actions workflow
.gitea/workflows/ci.yml:
  - uses: actions/checkout
  - run: buildctl build --frontend dockerfile.v0

# New: Argo Workflow template
devops/workflows/ci-cd-workflow-template.yaml:
  - template: git-clone
  - template: buildkit-build-push
  - template: update-deployment-manifest
```

### 3. BuildKit Configuration

#### Workflow Template Features
1. **Git Clone**: Authenticated clone from Gitea
2. **BuildKit Build**: Containerless builds with caching
3. **Registry Push**: Direct push to Gitea registry
4. **Manifest Update**: GitOps deployment trigger

#### BuildKit Container Settings
```yaml
container:
  image: moby/buildkit:latest
  securityContext:
    privileged: true  # Required for BuildKit daemon
  env:
  - name: BUILDKIT_HOST
    value: "unix:///run/buildkit/buildkitd.sock"
```

#### Build Command
```bash
buildctl --addr unix:///run/buildkit/buildkitd.sock build \
  --frontend dockerfile.v0 \
  --local context=. \
  --local dockerfile=. \
  --output type=image,name=$IMAGE_FULL,push=true,registry.insecure=true \
  --export-cache type=inline \
  --import-cache type=registry,ref=$IMAGE_FULL
```

## Deployment Process

### 1. Repository Setup
```bash
# Configure Gitea webhook to point to ArgoCD
# URL: https://webhooks.xuperson.org/gitea/gitea-push
# Events: Push events
# Branch filter: main/master
```

### 2. Secrets Configuration
```yaml
# Gitea credentials for clone and registry access
apiVersion: v1
kind: Secret
metadata:
  name: gitea-credentials
  namespace: argocd
data:
  username: <base64-encoded-gitea-username>
  password: <base64-encoded-gitea-token>
```

### 3. Workflow Triggers
Each repository push to main/master triggers:
1. **Event Source** receives webhook
2. **Sensor** filters and triggers workflow
3. **Workflow** executes CI/CD pipeline
4. **BuildKit** builds and pushes image
5. **ArgoCD** syncs updated deployment

## Migration from Existing Setup

### Phase 1: Parallel Deployment
1. Keep existing Gitea runner + Tekton operational
2. Deploy ArgoCD workflows for new projects
3. Test with non-critical applications

### Phase 2: Selective Migration
1. Choose specific repositories for migration
2. Update webhook configuration
3. Deploy workflow templates
4. Verify build and deployment

### Phase 3: Full Migration
1. Migrate all CI/CD to ArgoCD workflows
2. Decommission Gitea runners
3. Remove Tekton pipelines
4. Consolidate monitoring on ArgoCD

## Monitoring and Debugging

### ArgoCD UI
- Workflow execution logs
- Real-time pipeline status
- Historical workflow runs

### CLI Commands
```bash
# Watch workflow execution
argo watch <workflow-name> -n argocd

# Get workflow logs
argo logs <workflow-name> -n argocd

# List workflows
argo list -n argocd
```

### BuildKit Debugging
```bash
# Check BuildKit logs in workflow
kubectl logs <workflow-pod> -c buildkit-build-push -n argocd

# Verify registry connectivity
kubectl exec -it <workflow-pod> -c buildkit-build-push -n argocd -- \
  buildctl --addr unix:///run/buildkit/buildkitd.sock debug info
```

## Performance Optimization

### Build Caching
- **Inline Cache**: Stored in image layers
- **Registry Cache**: Shared across builds
- **Local Cache**: Volume-based caching

### Resource Management
```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

### Parallel Builds
- Multiple workflow instances can run simultaneously
- BuildKit handles concurrent builds efficiently
- Namespace isolation prevents conflicts

This integration provides a modern, Kubernetes-native CI/CD pipeline that surpasses the capabilities of the current Gitea runner + Tekton setup while maintaining compatibility with your existing BuildKit and registry infrastructure.