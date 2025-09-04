# Coder Development Environment

Production-ready Coder deployment with PostgreSQL backend, DERP network support, and automatic HTTPS via Cloudflare tunnel.

## Architecture

```
Internet → Cloudflare (SSL) → Cloudflare Tunnel → NGINX Ingress → Coder Service
                                                      ↓
                                                PostgreSQL Database
```

## Directory Structure

```
apps/coder.xuperson.org/
├── README.md                       # This documentation
├── namespace.yaml                  # Dedicated coder namespace
├── rbac.yaml                      # Service account and RBAC
├── kustomization.yaml             # Resource orchestration
├── postgresql-helmrepository.yaml # Bitnami PostgreSQL Helm repo
├── postgresql-helmrelease.yaml   # PostgreSQL database (Helm)
├── coder-helmrepository.yaml     # Coder Helm repository
├── coder-helmrelease.yaml        # Coder server deployment (Helm)
├── coder-ingress.yaml            # Ingress with DERP WebSocket support
├── proxy-headers.yaml            # NGINX proxy headers for WebSocket
└── database-secret.yaml          # [Deprecated] - Now using SOPS
```

## Key Features

### 🔐 Security
- **SOPS Encryption**: All passwords encrypted with Age
- **No Plaintext Secrets**: Zero "changeme" passwords in manifests
- **RBAC**: Dedicated service account with minimal permissions
- **Security Context**: Non-root containers, read-only filesystem

### 🌐 Networking
- **Wildcard Domain**: `*.xuperson.org` for workspace access
- **DERP Protocol**: Full WebSocket support for remote development
- **Fixed LoadBalancer IP**: `192.168.80.105` via MetalLB
- **Automatic DNS**: ExternalDNS creates CNAME records

### 💾 Data Persistence
- **PostgreSQL**: Dedicated database with Longhorn storage
- **20GB Storage**: Persistent workspace data
- **Database Backup**: Production-ready configuration

### 📊 Monitoring
- **Health Checks**: Liveness and readiness probes
- **Prometheus Metrics**: Built-in metrics endpoint
- **Resource Limits**: CPU/Memory limits for stability

## Configuration

### Domain Setup

**Primary Domain**: `coder.xuperson.org`
**Wildcard Workspaces**: `*.xuperson.org`

⚠️ **Important**: Uses root domain wildcard (`*.xuperson.org`) instead of subdomain wildcard (`*.coder.xuperson.org`) to avoid Cloudflare free tier SSL certificate limits.

### DERP Network Configuration

DERP (Designated Encrypted Relay Protocol) enables direct peer-to-peer connections for workspaces:

```yaml
# NGINX Ingress annotations for DERP support
annotations:
  nginx.ingress.kubernetes.io/websocket-services: "coder"
  nginx.ingress.kubernetes.io/proxy-set-headers: "ingress-nginx/proxy-headers"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-body-size: "0"
```

**NGINX Configuration** (in nginx-ingress HelmRelease):
```yaml
config:
  http-snippet: |
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
        'derp' upgrade;
    }
```

### IP Allocation

- **Coder Service**: `192.168.80.105` (LoadBalancer)
- **PostgreSQL**: `192.168.80.103` (LoadBalancer)
- **NGINX Ingress**: `192.168.80.101` (LoadBalancer)

## Secrets Management

All sensitive data is encrypted with SOPS and stored in `/secrets/sops/coder-secrets.yaml`:

```yaml
# Encrypted with Age - never store plaintext!
stringData:
  postgres-admin-password: "[SOPS-ENCRYPTED]"
  coder-user-password: "[SOPS-ENCRYPTED]"  
  database-url: "postgresql://coder:[PASSWORD]@coder-coder-postgresql:5432/coder?sslmode=disable"
```

### Secret Generation

```bash
# Generate secure passwords
openssl rand -base64 32  # For postgres admin
openssl rand -base64 32  # For coder user

# Edit encrypted secrets
SOPS_AGE_KEY_FILE=secrets/age/age-key.txt sops edit secrets/sops/coder-secrets.yaml

# Encrypt new secrets
SOPS_AGE_KEY_FILE=secrets/age/age-key.txt sops --encrypt --in-place secrets/sops/coder-secrets.yaml
```

## Deployment

### Prerequisites
1. Flux CD running with SOPS decryption
2. Age private key in `secrets/age/age-key.txt`
3. MetalLB configured with IP pool `192.168.80.100-150`
4. NGINX Ingress with DERP support enabled
5. Cloudflare tunnel and ExternalDNS configured

### Deploy Application
```bash
# Add to main apps kustomization
cd clusters/minikube
echo "  - ../../apps/coder.xuperson.org" >> applications/kustomization.yaml

# Commit and push - Flux handles deployment
git add apps/coder.xuperson.org/
git commit -m "Add Coder development environment"
git push
```

### Verify Deployment
```bash
export KUBECONFIG=./infrastructure/ansible/config/kubeconfig.yaml

# Check pods
kubectl get pods -n coder
kubectl get svc -n coder

# Check ingress and DNS
kubectl get ingress -n coder
curl -I https://coder.xuperson.org
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Failures
**Symptoms**: 
```
error: dial tcp: lookup coder-postgresql on 10.43.0.10:53: no such host
```

**Solution**: Check service name in database URL
```bash
# Verify PostgreSQL service name
kubectl get svc -n coder | grep postgresql

# Should show: coder-coder-postgresql (not coder-postgresql)
# Update database-url in SOPS secrets if needed
```

#### 2. SSL Connection Errors
**Symptoms**:
```
error: pq: SSL is not enabled on the server
```

**Solution**: Add `?sslmode=disable` to database URL:
```
postgresql://coder:password@host:5432/database?sslmode=disable
```

#### 3. DERP Connection Issues
**Symptoms**: Workspaces can't establish direct connections

**Solutions**:
1. Verify NGINX WebSocket configuration:
```bash
kubectl get configmap -n ingress-nginx ingress-nginx-controller -o yaml | grep upgrade
```

2. Check proxy headers ConfigMap:
```bash
kubectl get configmap -n ingress-nginx proxy-headers -o yaml
```

3. Test WebSocket upgrade:
```bash
curl -I -H "Connection: Upgrade" -H "Upgrade: websocket" https://coder.xuperson.org
```

#### 4. Pod Crashes (CrashLoopBackOff)
**Common Causes**:
- Wrong database credentials → Check SOPS secrets
- Database not ready → Wait for PostgreSQL pod
- Insufficient resources → Check resource limits
- Security context issues → Verify non-root configuration

**Debug Commands**:
```bash
# Check pod logs
kubectl logs -n coder deployment/coder --previous

# Check events
kubectl get events -n coder --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n coder
```

#### 5. Wildcard Domain Issues
**Symptoms**: Can't access workspace subdomains

**Solution**: Verify wildcard ingress and DNS:
```bash
# Check wildcard ingress
kubectl get ingress -n coder coder-workspaces-wildcard -o yaml

# Test subdomain resolution
nslookup test-workspace.xuperson.org
```

### Configuration Validation

```bash
# Verify all components
kubectl get pods,svc,ingress -n coder
kubectl get secrets -n coder | grep coder-database-secrets

# Test end-to-end connectivity
curl -I https://coder.xuperson.org
curl -I https://example-workspace.xuperson.org
```

## Resource Requirements

### Minimum Requirements
- **Coder**: 250m CPU, 512Mi Memory
- **PostgreSQL**: 100m CPU, 256Mi Memory  
- **Storage**: 20Gi persistent volume

### Production Limits
- **Coder**: 2000m CPU, 4Gi Memory
- **PostgreSQL**: 500m CPU, 512Mi Memory
- **Total**: ~2.5 CPU cores, 4.5Gi Memory

## Maintenance

### Backup Database
```bash
# Create PostgreSQL backup
kubectl exec -n coder coder-coder-postgresql-0 -- pg_dump -U coder coder > coder-backup.sql
```

### Update Secrets
```bash
# Rotate passwords
SOPS_AGE_KEY_FILE=secrets/age/age-key.txt sops edit secrets/sops/coder-secrets.yaml

# Force pod restart to pick up new secrets
kubectl rollout restart deployment/coder -n coder
```

### Monitor Resources
```bash
# Check resource usage
kubectl top pods -n coder
kubectl get pvc -n coder

# Check Longhorn storage
kubectl get pv | grep coder
```

## Template Management

**Important**: Templates are NOT deployed via Kubernetes manifests. Use the Coder CLI instead.

### Pushing Templates

1. Install Coder CLI:
```bash
curl -L https://coder.com/install.sh | sh
```

2. Set your Coder URL and create an API token:
```bash
export CODER_URL=https://coder.xuperson.org
coder login
# or create token directly:
# coder tokens create --lifetime 24h
# export CODER_SESSION_TOKEN=your-token-here
```

3. Push the Kubernetes devcontainer template:
```bash
cd coder-templates/kubernetes-devcontainer
coder templates push kubernetes-devcontainer
```

### Available Templates

- `kubernetes-devcontainer/`: Advanced Kubernetes-based template with Docker-in-Docker support
- `containerd-workspace/`: Simple containerd-based workspace template

### Alternative Template Deployment Methods

**1. CLI Push (Recommended)**
```bash
coder templates push <template-name> -d <template-directory>
```

**2. Terraform Git Repository Automation**
```terraform
resource "coderd_template" "kubernetes" {
  name = "kubernetes"
  versions = [{
    directory = ".coder/templates/kubernetes"
    active    = true
  }]
}
```

**3. Helm Volume Mount (Advanced)**
```yaml
coder:
  volumes:
    - name: templates
      hostPath:
        path: /path/to/templates
  volumeMounts:
    - name: templates
      mountPath: /opt/templates
```

### Template Development

When modifying templates:

1. Edit the `.tf` files in the template directory
2. Test locally with `terraform validate`
3. Push to Coder with `coder templates push <template-name> -d <template-directory>`

## Version History

- **v2.25.0**: Current Coder version with DERP support
- **PostgreSQL 15.5.32**: Stable database version
- **Bitnami Charts**: Latest Helm charts for production stability