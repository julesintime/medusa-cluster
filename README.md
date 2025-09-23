# 🚀 GitOps-Native Medusa Cluster

**ULTRATHINK: Complete GitOps automation - no manual steps required!**

## 🎯 How It Works

This is a **fully GitOps-native** implementation of Medusa backend deployment using:

- ✅ **ApplicationSet Auto-Discovery**: ArgoCD automatically detects new medusa services
- ✅ **Declarative Argo Workflows**: Build process is GitOps resource, not manual submission
- ✅ **PVC Binary Sharing**: Build once, deploy fast with pre-built applications
- ✅ **Flux-like Experience**: Everything streamlined and automatic
- ✅ **Git Subtree Integration**: Works seamlessly with labinfra repository structure

## 📁 Directory Structure

```
devops/projects/medusa-cluster/
├── medusa-backend.xuperson.org/      # Backend service (auto-discovered)
│   ├── kustomization.yaml            # GitOps resource orchestration
│   ├── medusa-backend-workflow.yaml  # Declarative build process
│   ├── medusa-backend-pvc.yaml       # Shared workspace storage
│   ├── medusa-backend-server-gitops.yaml    # Server deployment (PVC-based)
│   ├── medusa-backend-worker-gitops.yaml    # Worker deployment (PVC-based)
│   ├── medusa-backend-rbac.yaml      # RBAC for app + workflow
│   ├── medusa-backend-namespace.yaml # Namespace creation
│   ├── medusa-backend-infisical-secrets.yaml # Secret management
│   ├── medusa-backend-postgresql.yaml # Database dependency
│   ├── medusa-backend-redis.yaml     # Cache dependency
│   └── medusa-backend-ingress.yaml   # External access
└── medusa-storefront.xuperson.org/   # Future: Storefront service
    └── [auto-discovered by ApplicationSet]
```

## 🔄 GitOps Workflow

### 1. Automatic Discovery
```
git push → ApplicationSet detects → ArgoCD creates Application → Deployment starts
```

### 2. Build Process (Declarative)
```
ArgoCD applies → Workflow builds app → Stores in PVC → Marks ready
```

### 3. Deployment Process
```
Workflow completes → Server/Worker pods start → Use pre-built app from PVC
```

### 4. Scaling & Updates
```
Code changes → Git push → Workflow rebuilds → Rolling deployment
```

## ⚡ Key Benefits

| Feature | Manual Approach | GitOps-Native Approach |
|---------|----------------|------------------------|
| **Deployment** | `argo submit --from` | `git push` |
| **Discovery** | Manual application creation | ApplicationSet auto-discovery |
| **Build** | Manual workflow submission | Declarative workflow resource |
| **Scaling** | Rebuild every pod | Share built app via PVC |
| **Updates** | Multi-step manual process | Single git commit |
| **Rollback** | Manual intervention | Git revert |

## 🏗️ Build Pipeline

The GitOps workflow automatically:

1. **Detects Changes**: ApplicationSet monitors git repository
2. **Builds Application**: Declarative Argo Workflow builds Node.js app
3. **Optimizes Dependencies**: Production-only node_modules in PVC
4. **Shares Binary**: Server and worker pods use same built application
5. **Handles Migrations**: Server runs DB migrations, workers skip
6. **Marks Ready**: Build completion triggers deployment readiness

## 🚀 Adding New Services

To add a new medusa service (e.g., `medusa-admin.xuperson.org`):

```bash
# 1. Create new service directory
mkdir -p devops/projects/medusa-cluster/medusa-admin.xuperson.org

# 2. Copy and adapt manifests from medusa-backend.xuperson.org
cp devops/projects/medusa-cluster/medusa-backend.xuperson.org/* \
   devops/projects/medusa-cluster/medusa-admin.xuperson.org/

# 3. Update manifests for new service (name, domain, etc.)

# 4. Commit and push
git add . && git commit -m "Add medusa-admin service" && git push

# 5. ApplicationSet automatically discovers and deploys!
```

## 🔍 Monitoring

```bash
# Check ApplicationSet discovery
kubectl get applicationset medusa-cluster -n argocd

# Check discovered applications
kubectl get applications -n argocd -l app.kubernetes.io/part-of=medusa-cluster

# Check build workflows
kubectl get workflows -n medusa-backend

# Check deployments
kubectl get pods -n medusa-backend

# Check build progress
kubectl logs -n medusa-backend -l workflows.argoproj.io/workflow

# Test deployment
curl https://medusa-backend.xuperson.org/health
```

## 🎯 Result

**ULTRATHINK ACHIEVED**: True GitOps experience where:
- Everything is declarative and automatic
- No manual argo commands needed
- ApplicationSet provides Flux-like auto-discovery
- PVC binary sharing gives instant pod startup
- Complete integration with existing labinfra GitOps infrastructure

Just push code → ArgoCD handles everything! 🚀
