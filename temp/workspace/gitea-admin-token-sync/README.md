# Gitea Admin Token Sync

Production-ready solution for syncing Gitea admin API tokens using Kubernetes Jobs.

## Approaches Used

1. **Baked Image (Recommended)**: Script baked into container image for immutability
2. **ConfigMap Mount**: Script stored in ConfigMap, mounted into container

Both approaches use service accounts for secure K8s access and cluster DNS for Gitea API.

## Prerequisites

- Kubernetes cluster (local: minikube/kind, cloud: EKS/GKE/AKS)
- Gitea deployed in `gitea` namespace
- `gitea-admin-secrets` secret with admin credentials
- kubectl configured

## Build and Deploy

### 1. Build Image (for Baked Approach)

```bash
# Edit build.sh with your registry
./build.sh
```

### 2. Deploy

#### Option A: Baked Image (Recommended)
```bash
# Update job.yaml with your image registry/tag
kubectl apply -f job.yaml
```

#### Option B: ConfigMap Mount
```bash
kubectl apply -f job-configmap.yaml
```

### 3. Monitor
```bash
kubectl logs -n gitea job/gitea-admin-token-sync
kubectl get secret -n gitea gitea-admin-api-token -o yaml
```

## Environment Compatibility

### Local (minikube/kind)
- Works out-of-the-box with cluster DNS
- Service account provides K8s API access
- No external dependencies

### Cloud (EKS/GKE/AKS)
- Uses cluster-internal DNS for Gitea
- Service account with RBAC for secrets access
- No load balancer needed (internal communication)

## Security
- Non-root container user
- Minimal RBAC permissions
- Secrets accessed via K8s API (not mounted)
- No hardcoded credentials

## Customization
- Edit `revised-admin-token.sh` for custom logic
- Modify RBAC in `job.yaml` for additional permissions
- Change Gitea service DNS if different namespace/service

## Troubleshooting
- Check pod logs: `kubectl logs -n gitea -l job-name=gitea-admin-token-sync`
- Verify Gitea service: `kubectl get svc -n gitea gitea-http`
- Test API access: `kubectl exec -it <pod> -- curl http://gitea-http.gitea.svc.cluster.local:3000/api/v1/version`
