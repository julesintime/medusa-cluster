# Complete Disaster Recovery Walkthrough

**Production-ready K3s GitOps platform reconstruction from scratch**

This document provides a comprehensive step-by-step guide to rebuild the entire labinfra platform, including the working hello.xuperson.org CI/CD pipeline with proper Infisical secret management.

## Prerequisites Verification

### 1. Physical Infrastructure
```bash
# Verify Proxmox hosts are accessible
ping 192.168.8.26  # pve200
ping 192.168.8.27  # pve700

# Check Ubuntu cloud image exists
ssh root@192.168.8.26 "ls -la /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img"
```

### 2. EdgeRouter Configuration
```bash
# Verify BGP configuration
show ip bgp summary
show ip route

# Check static DHCP mappings for K3s nodes
show dhcp leases
```

### 3. Required Credentials
- **Cloudflare Tunnel Token**: Zero Trust → Tunnels → Configure
- **Cloudflare API Token**: dash.cloudflare.com/profile/api-tokens
- **GitHub Personal Access Token**: For Flux GitOps
- **Infisical Service Token**: For secrets management

## Phase 1: Infrastructure Bootstrap (Ansible)

### Step 1: Prepare Local Environment
```bash
# Clone repository
git clone https://github.com/julesintime/labinfra.git
cd labinfra/infrastructure/ansible

# Install Infisical CLI
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | bash
apt-get update && apt-get install -y infisical

# Authenticate with Infisical
infisical login
```

### Step 2: Configure GitHub Credentials
Edit `infrastructure/ansible/config/group_vars.yml`:
```yaml
github:
  owner: "your-github-username"
  repo: "labinfra"
  token: "ghp_your_github_personal_access_token"
```

### Step 3: Store Required Secrets in Infisical
```bash
# Core infrastructure secrets (prod environment, root path)
infisical secrets set CLOUDFLARE_TUNNEL_TOKEN=your_tunnel_token --env=prod
infisical secrets set CLOUDFLARE_API_TOKEN=your_api_token --env=prod
infisical secrets set VM_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)" --env=prod
infisical secrets set GITHUB_TOKEN=ghp_your_token --env=prod
infisical secrets set GITHUB_OWNER=your-username --env=prod
infisical secrets set GITHUB_REPO=labinfra --env=prod

# Gitea admin credentials (CRITICAL for registry authentication)
infisical secrets set GITEA_ADMIN_USERNAME=helloroot --env=prod
infisical secrets set GITEA_ADMIN_PASSWORD=$(openssl rand -base64 32) --env=prod
infisical secrets set GITEA_ADMIN_EMAIL=admin@xuperson.org --env=prod
```

### Step 4: Deploy VMs and K3s Cluster
```bash
# Remove any existing VMs (if disaster recovery)
ansible-playbook playbooks/00-vm-removal.yml

# Create fresh VMs with Ubuntu 22.04
ansible-playbook playbooks/01-vm-creation.yml

# Install K3s cluster with BGP MetalLB
ansible-playbook playbooks/02-k3s-installation.yml

# Verify cluster
export KUBECONFIG=./config/kubeconfig.yaml
kubectl get nodes -o wide
```

### Step 5: Bootstrap GitOps with Flux
```bash
# Initialize Flux CD with GitHub integration + Infisical
ansible-playbook playbooks/03-flux-bootstrap.yml

# Verify Flux deployment
kubectl get pods -n flux-system
```

## Phase 2: Core Infrastructure Verification

### Step 1: Storage (Longhorn)
```bash
# Verify Longhorn system
kubectl get pods -n longhorn-system
kubectl get storageclass

# Check storage nodes
kubectl get nodes.longhorn.io -o wide
```

### Step 2: Load Balancer (MetalLB)
```bash
# Verify MetalLB BGP peering
kubectl get pods -n metallb-system
kubectl logs -n metallb-system deployment/controller

# Check BGP configuration
kubectl get bgppeers -n metallb-system
kubectl get ipaddresspools -n metallb-system
```

### Step 3: Ingress (NGINX + Cloudflare)
```bash
# Verify Cloudflare tunnel
kubectl get pods -n cloudflare
kubectl logs -n cloudflare deployment/cloudflared

# Check NGINX ingress
kubectl get pods -n cloudflare | grep nginx
kubectl get svc -n cloudflare
```

### Step 4: Secrets Management (Infisical)
```bash
# Verify Infisical operator
kubectl get pods -n infisical-operator
kubectl get secret infisical-service-token -n infisical-operator

# Test secret synchronization
kubectl get infisicalsecrets -A
```

## Phase 3: Gitea Deployment with CI/CD

### Step 1: Gitea Core Components
```bash
# Monitor Gitea deployment
kubectl get pods -n gitea -w

# Expected sequence:
# 1. gitea-postgresql-0 (Running)
# 2. gitea-redis-master-0 (Running) 
# 3. gitea-7f8db9b676-* (Running - may take 2-3 minutes for init containers)
```

### Step 2: Verify Gitea Admin Credentials
```bash
# Check Infisical secret sync
kubectl describe infisicalsecret gitea-secrets -n gitea

# Verify admin secret creation
kubectl get secret gitea-admin-secrets -n gitea -o yaml

# Get actual credentials
ADMIN_USER=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.password}' | base64 -d)
echo "Admin User: $ADMIN_USER"
echo "Admin Pass: $ADMIN_PASS"
```

### Step 3: Test Gitea External Access
```bash
# Verify external access
curl -I https://git.xuperson.org

# Test API access
curl -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/api/v1/version
```

### Step 4: BuildKit Daemon
```bash
# Verify BuildKit daemon
kubectl get pods -n gitea | grep buildkit
kubectl logs -n gitea deployment/buildkitd

# Test BuildKit connectivity
kubectl exec -n gitea deployment/buildkitd -- buildctl debug workers
```

### Step 5: Runner Registration
```bash
# Monitor runner token generation
kubectl get pods -n gitea | grep token-generator
kubectl logs -n gitea job/gitea-runner-token-generator

# Verify runner deployment
kubectl get pods -n gitea | grep act-runner
kubectl logs -n gitea deployment/act-runner-buildkit -c runner

# Check runner registration
kubectl get secret runner-secret -n gitea
```

## Phase 4: Hello CI/CD Pipeline Implementation

### Step 1: Repository Bootstrap
```bash
# Monitor hello repository setup
kubectl get pods -n gitea | grep hello-repo-setup
kubectl logs -n gitea job/hello-repo-setup

# Expected output:
# ✅ Gitea API is accessible
# ✅ Created and stored new token
# ✅ Repository 'hello' created successfully
# ✅ Hello repository setup completed successfully!
```

### Step 2: Verify Repository Creation
```bash
# Check repository via API
curl -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/api/v1/repos/helloroot/hello

# Verify CI/CD workflow file
curl -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/helloroot/hello/raw/branch/main/.gitea/workflows/buildkit-ci.yml
```

### Step 3: CI/CD Pipeline Execution
```bash
# Verify runner picked up the workflow
kubectl logs -n gitea deployment/act-runner-buildkit -c runner --tail=50

# Monitor build process (should see task execution)
# Expected: "task X repo is helloroot/hello"

# Check registry for built images
curl -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/v2/_catalog
curl -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/v2/helloroot/hello-app/tags/list
```

### Step 4: Registry Authentication Setup
```bash
# Verify registry secret for Flux
kubectl get infisicalsecrets -n hello
kubectl describe infisicalsecret gitea-registry-credentials -n hello

# Check synced registry secret
kubectl get secret gitea-registry-secret -n hello -o yaml

# Test registry access patterns
# Internal (BuildKit push)
curl -u "$ADMIN_USER:$ADMIN_PASS" http://gitea-http.gitea.svc.cluster.local:3000/v2/_catalog
# External (Flux pull)  
curl -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/v2/_catalog
```

## Phase 5: Hello Application Deployment

### Step 1: Flux Image Automation
```bash
# Check ImageRepository status
kubectl get imagerepository hello-app -n hello
kubectl describe imagerepository hello-app -n hello

# Verify ImagePolicy
kubectl get imagepolicy hello-app -n hello -o yaml

# Check ImageUpdateAutomation
kubectl get imageupdateautomation -A
```

### Step 2: Application Deployment
```bash
# Monitor hello app deployment
kubectl get pods -n hello -w

# Expected pod states:
# 1. hello-app-*-* Pending (ImagePullBackOff if no image yet)
# 2. hello-app-*-* ContainerCreating (after image is built)
# 3. hello-app-*-* Running (application ready)

# Check deployment events
kubectl describe deployment hello-app -n hello
```

### Step 3: Service and Ingress
```bash
# Verify LoadBalancer service
kubectl get svc hello-app -n hello
# Should show EXTERNAL-IP: 192.168.80.120

# Check ingress
kubectl get ingress hello-app -n hello
# Should show git.xuperson.org/192.168.80.101

# Verify DNS records (ExternalDNS)
nslookup hello.xuperson.org
# Should return CNAME to git.xuperson.org
```

### Step 4: End-to-End Verification
```bash
# Test external HTTPS access
curl -I https://hello.xuperson.org
# Expected: HTTP/2 200

# Get application response
curl -s https://hello.xuperson.org
# Expected: "Hello from Gitea Actions CI/CD! 🚀"
```

## Phase 6: Troubleshooting Common Issues

### Issue 1: Infisical Secret Sync Failures
```bash
# Check Infisical operator logs
kubectl logs -n infisical-operator deployment/infisical-opera-controller-manager

# Verify service token
kubectl get secret infisical-service-token -n infisical-operator -o yaml

# Force secret refresh
kubectl annotate infisicalsecret gitea-secrets -n gitea infisical.com/reconcileAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### Issue 2: Gitea Pod Init Container Failures
```bash
# Check specific init container logs
kubectl logs -n gitea gitea-pod-name -c configure-gitea
kubectl logs -n gitea gitea-pod-name -c init-app-ini

# Common issues:
# - Database not ready: Check PostgreSQL pod
# - Redis not ready: Check Redis pod  
# - Admin credentials missing: Check Infisical secret sync
```

### Issue 3: Runner Registration Problems
```bash
# Check runner token generation
kubectl logs -n gitea job/gitea-runner-token-generator

# Verify admin API token
kubectl get secret gitea-admin-api-token -n gitea -o yaml

# Check runner registration
kubectl logs -n gitea deployment/act-runner-buildkit -c runner
```

### Issue 4: Registry Authentication Failures
```bash
# Test registry endpoints
curl -v -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/v2/
curl -v -u "$ADMIN_USER:$ADMIN_PASS" http://gitea-http.gitea.svc.cluster.local:3000/v2/

# Check Flux ImageRepository
kubectl describe imagerepository hello-app -n hello

# Force image repository rescan
kubectl annotate imagerepository hello-app -n hello fluxcd.io/reconcileAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### Issue 5: BuildKit Build Failures
```bash
# Check BuildKit daemon
kubectl logs -n gitea deployment/buildkitd

# Check runner build logs
kubectl logs -n gitea deployment/act-runner-buildkit -c runner -f

# Verify BuildKit connectivity
kubectl exec -n gitea deployment/act-runner-buildkit -c runner -- buildctl --addr tcp://buildkitd:1234 debug workers
```

## Phase 7: Validation Checklist

### Infrastructure Health
- [ ] All nodes Ready: `kubectl get nodes`
- [ ] Longhorn healthy: `kubectl get pods -n longhorn-system`
- [ ] MetalLB operational: `kubectl get pods -n metallb-system`
- [ ] Cloudflare tunnel active: `kubectl get pods -n cloudflare`
- [ ] Infisical secrets syncing: `kubectl get infisicalsecrets -A`

### Gitea Platform
- [ ] Gitea accessible: `curl -I https://git.xuperson.org`
- [ ] Admin login works: Web UI login test
- [ ] API functional: `curl -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/api/v1/version`
- [ ] Registry accessible: `curl -u "$ADMIN_USER:$ADMIN_PASS" https://git.xuperson.org/v2/_catalog`

### CI/CD Pipeline
- [ ] Runner registered: `kubectl logs -n gitea deployment/act-runner-buildkit -c runner`
- [ ] BuildKit healthy: `kubectl logs -n gitea deployment/buildkitd`
- [ ] Hello repository exists: Web UI check
- [ ] Workflow triggered: Runner logs show task execution
- [ ] Image built: Registry contains `hello-app` tags

### Hello Application
- [ ] Flux scanning images: `kubectl describe imagerepository hello-app -n hello`
- [ ] Pod running: `kubectl get pods -n hello`
- [ ] Service ready: `kubectl get svc hello-app -n hello`
- [ ] Ingress configured: `kubectl get ingress hello-app -n hello`
- [ ] External access: `curl https://hello.xuperson.org`

## Success Criteria

✅ **Complete Success**: All checklist items pass and hello.xuperson.org returns:
```
Hello from Gitea Actions CI/CD! 🚀

Build Information:
- Timestamp: [current timestamp]
- Build: main
- Version: 1.0.0
- Environment: production

Powered by Gitea Actions + BuildKit
```

## Architecture Summary

The final architecture achieves:

1. **🔐 Cloud-Native Security**: All secrets managed via Infisical
2. **🔄 GitOps Workflow**: Flux CD manages all deployments
3. **🏗️ Container CI/CD**: Gitea Actions + BuildKit + Registry
4. **🌐 External Access**: Cloudflare tunnel + ExternalDNS + NGINX
5. **💾 Persistent Storage**: Longhorn distributed storage
6. **⚖️ Load Balancing**: MetalLB with BGP routing

**Registry Access Pattern**:
- **Push**: BuildKit → `gitea-http.gitea.svc.cluster.local:3000` (internal)
- **Pull**: Flux ← `git.xuperson.org` (external via tunnel)
- **Auth**: Infisical-managed Gitea admin credentials for both

This completes a production-ready, fully automated, cloud-native GitOps platform with working CI/CD pipeline.