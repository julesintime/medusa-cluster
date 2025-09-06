# Labinfra K3s Infrastructure

Production-ready Kubernetes platform built on Proxmox with automated deployment, BGP load balancing, and Cloudflare tunnel integration. Full GitOps workflow with Flux CD and Infisical secrets management.

## GitOps Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Proxmox Hosts  │───▶│   VM Creation   │───▶│  K3s Cluster    │───▶│   Flux GitOps   │
│  pve200/pve700  │    │  Ubuntu 22.04   │    │ HA Control+Work │    │   Sync & Deploy │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
   Ansible Automation      Cloud-init Setup        K3s Installation       Git Repository
         │                       │                       │                       │
    ┌────▼────┐             ┌────▼────┐            ┌────▼────┐            ┌────▼────┐
    │ SSH Key │             │EdgeRouter│            │ MetalLB │            │Infisical│
    │ Deploy  │             │BGP ASN  │            │ BGP     │            │ Secrets │
    │         │             │ 65008   │            │ ASN     │            │ Manager │
    └─────────┘             └─────────┘            └─────────┘            └─────────┘
```

**Flow**: Physical Infrastructure → VM Automation → K3s + BGP → GitOps Management  
**BGP**: EdgeRouter (ASN 65008) ↔ MetalLB (ASN 65009) for LoadBalancer IP routing

## External Access Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Internet User  │───▶│   Cloudflare    │───▶│ Cloudflare      │───▶│ NGINX Ingress   │
│     Browser     │    │   CDN + SSL     │    │    Tunnel       │    │   Controller    │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
      HTTPS Request           SSL Termination        Secure Routing         Host Matching
         │                       │                       │                       │
    ┌────▼────┐             ┌────▼────┐            ┌────▼────┐            ┌────▼────┐
    │yourdoma.│             │Automatic│            │MetalLB  │            │Service  │
    │ in.org  │             │   DNS   │            │LoadBal  │            │ Pods    │
    └─────────┘             └─────────┘            └─────────┘            └─────────┘
                                  ▲
                            ┌─────▼─────┐
                            │ExternalDNS│
                            │CNAME Auto │
                            └───────────┘
```

**Flow**: Internet → Cloudflare SSL → Tunnel → MetalLB → NGINX → Services
**DNS**: ExternalDNS automatically creates CNAME records for all ingress hostnames

## Project Structure

```
labinfra/
├── infrastructure/ansible/          # One-time VM provisioning & K3s bootstrap
│   ├── config/
│   │   ├── group_vars.yml               # Consolidated Ansible configuration
│   │   ├── inventory.yml                # Host definitions
│   │   ├── ansible_minikube_key         # SSH automation key
│   │   └── kubeconfig.yaml              # Generated K3s access
│   └── playbooks/
│       ├── 00-vm-removal.yml            # Proxmox VM cleanup
│       ├── 01-vm-creation.yml           # Proxmox VM creation
│       ├── 02-k3s-installation.yml      # K3s cluster deployment  
│       └── 03-flux-bootstrap.yml        # GitOps + Infisical initialization
├── clusters/labinfra/                   # GitOps manifests (Flux managed)
│   ├── flux-system/                 # Flux CD controllers
│   ├── core/                            # Core cluster components
│   │   ├── longhorn/                    # Distributed storage
│   │   ├── metallb/                     # BGP load balancer
│   │   ├── infisical-operator/          # Secrets management
│   │   ├── cloudflare-ingress/          # Tunnel + ExternalDNS + NGINX
│   │   ├── tekton/                      # CI/CD pipelines
│   │   └── kustomization.yaml           # Core orchestration
│   ├── apps/                            # User applications
│   │   ├── hello.xuperson.org/          # Test application
│   │   ├── coder.xuperson.org/          # Development environment
│   │   ├── git.xuperson.org/            # Git hosting + CI/CD runners
│   │   └── kustomization.yaml           # App orchestration
│   └── kustomization.yaml               # Main cluster config
├── docs/                                # Documentation
└── README.md                            # This documentation
```

## Network Configuration

**Host Network**: 192.168.8.0/24 (EdgeRouter managed)
- **Proxmox**: pve200 (192.168.8.26), pve700 (192.168.8.27)
- **K3s Control**: 192.168.8.21-22
- **K3s Workers**: 192.168.8.11-13
- **MetalLB Pool**: 192.168.80.100-150
- **BGP**: EdgeRouter ASN 65008 ↔ K3s ASN 65009

**IP Allocations**:
- `192.168.80.101`: NGINX Ingress Controller
- `192.168.80.103`: PostgreSQL (Coder database)
- `192.168.80.105`: Coder application

## Prerequisites

1. **Proxmox Infrastructure**:
   - Hosts: pve200 (192.168.8.26), pve700 (192.168.8.27) accessible
   - Ubuntu cloud image: `/var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img`

2. **EdgeRouter Configuration**:
   - Static DHCP mappings for K3s nodes
   - BGP configuration (ASN 65008, ready for MetalLB peering)

3. **Cloudflare Setup**:
   - Domain managed in Cloudflare (e.g., `xuperson.org`)
   - **Tunnel Token**: Zero Trust → Access → Tunnels → [Your Tunnel] → Configure
   - **API Token**: dash.cloudflare.com/profile/api-tokens (Zone:DNS:Edit permissions)

4. **Local Environment**:
   - Ansible with Proxmox community collection
   - SSH key pair for automation

## Installation

### Step 1: VM Provisioning & K3s

```bash
cd infrastructure/ansible

# SSH key will be fetched from Infisical using VM-SSH-PUBLIC-KEY secret
# Install Infisical CLI and setup authentication first:
# curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | bash
# apt-get update && apt-get install -y infisical

# SSH key management handled by Infisical - no manual key distribution needed

# Deploy VMs and K3s cluster
ansible-playbook playbooks/01-vm-creation.yml
ansible-playbook playbooks/02-k3s-installation.yml
```

### Step 2: Configure Secrets

**Critical**: Update configuration with real credentials:

**A. GitHub Credentials** (for Flux GitOps):
Edit `infrastructure/ansible/config/group_vars.yml`:
```yaml
# GitHub credentials for Flux bootstrap
github:
  owner: "your-github-username"
  repo: "your-repo-name" 
  token: "ghp_your_github_personal_access_token"
```

**B. Infisical Secrets Setup**:
Store the following secrets in Infisical:
```bash
# Required secrets in Infisical:
# - CLOUDFLARE_TUNNEL_TOKEN: From Cloudflare Zero Trust → Tunnels → Configure
# - CLOUDFLARE_API_TOKEN: From dash.cloudflare.com/profile/api-tokens
# - VM_SSH_PUBLIC_KEY: SSH public key for VM access
# - GITHUB_TOKEN: GitHub Personal Access Token
# - GITHUB_OWNER: GitHub username/organization  
# - GITHUB_REPO: Repository name

# Use Infisical CLI to set these:
# infisical secrets set CLOUDFLARE_TUNNEL_TOKEN=your_token --env=prod
# infisical secrets set CLOUDFLARE_API_TOKEN=your_api_token --env=prod
```

### Step 3: Bootstrap GitOps

```bash
# Initialize Flux CD with GitHub integration
ansible-playbook playbooks/03-flux-bootstrap.yml
```

**This automatically deploys all core infrastructure via GitOps:**
- Longhorn storage with replication
- MetalLB with BGP peering to EdgeRouter
- NGINX Ingress with DERP WebSocket support
- Cloudflare tunnel + ExternalDNS integration
- All applications defined in `clusters/labinfra/apps/`

### Step 4: Verification

```bash
export KUBECONFIG=./infrastructure/ansible/config/kubeconfig.yaml

# Check core infrastructure
kubectl get pods -n longhorn-system
kubectl get pods -n metallb-system  
kubectl get pods -n cloudflare

# Test applications
kubectl get pods -n default    # hello-world
kubectl get pods -n coder      # coder development env

# Verify external access
curl -I https://hello.xuperson.org
curl -I https://coder.xuperson.org
```

**Expected Results**:
- All pods `Running` and healthy
- External HTTPS access working (HTTP 200)
- Automatic DNS records created for all applications
- WebSocket/DERP support enabled for development tools

## Application Deployment

### Directory Structure Standard

All applications use `apps/[domain.name]/` structure:

```bash
apps/
├── hello.xuperson.org/              # Simple test app
└── coder.xuperson.org/              # Complex app with database
    ├── README.md                    # App-specific documentation
    ├── kustomization.yaml          # Resource orchestration
    ├── {app-name}-namespace.yaml   # Dedicated namespace
    ├── {app-name}-helmrelease.yaml # Main deployment
    ├── {app-name}-ingress.yaml     # External access
    ├── {app-name}-infisical-secrets.yaml # Secure secrets management
    └── {app-name}-rbac.yaml        # Security
```

**File Naming**: All files follow `{app-name}-{resource-type}.yaml` convention.

### Adding New Applications

```bash
# 1. Create application directory
mkdir -p clusters/labinfra/apps/newapp.domain.name

# 2. Follow standard structure (see existing apps as templates)

# 3. Create secrets if needed
# Store secrets in Infisical:
infisical secrets set SECRET_KEY=value --env=<environment> --path=/apps/newapp.domain.name

# 4. Add to applications kustomization
echo "  - newapp.domain.name" >> clusters/labinfra/apps/kustomization.yaml

# 5. Commit - Flux deploys automatically
git add . && git commit -m "Add newapp" && git push
```

### Domain & DNS Pattern

- **Primary**: `appname.xuperson.org`
- **Wildcard**: `*.xuperson.org` (for workspace subdomains)
- **Automatic**: ExternalDNS creates CNAME records
- **SSL**: Cloudflare provides certificates

## Security

- **🔐 Infisical Secrets**: All secrets managed centrally with Infisical (never commit plaintext!)
- **🛡️ RBAC**: Dedicated service accounts with minimal permissions
- **🔒 Pod Security**: Non-root containers, read-only filesystems
- **🌐 Network**: Pod security contexts and resource limits
- **🔑 SSH**: Dedicated automation keys per project

## Troubleshooting

### Common Issues

**Pods CrashLoopBackOff**: Check logs and Infisical secrets
```bash
kubectl logs -n <namespace> deployment/<app> --previous
# Check Infisical secrets with:
infisical secrets --env=<environment>
```

**External access fails**: Verify tunnel and DNS
```bash
kubectl logs -n cloudflare deployment/cloudflared
kubectl get ingress -A
```

## Script Development

**Rule**: Always develop and test scripts locally before Kubernetes deployment.

```bash
# 1. Write in workspace/scripts/
# 2. Test with kubectl port-forward 
# 3. Create ConfigMap only after local testing succeeds
# 4. Use ConfigMap volumes in deployments
```

### Gitea Runner Success Pattern

**Single Runner Implementation**: Simplified token management without sync jobs.

```yaml
# Key insight: Reuse first existing admin token, create only if none exists
runner-setup.sh:
  - Get admin credentials from Kubernetes secrets
  - List existing admin API tokens, use first one found
  - Create admin token only if none exists  
  - Use admin token to get runner registration token
  - Clean registration process with proper RBAC permissions
```

**Critical RBAC**: Service account needs `delete` permission for secret cleanup.

See CLAUDE.md for detailed script development workflow.

## Complete Container Image CI/CD Lifecycle

The platform provides a fully automated container image lifecycle using Gitea Actions, BuildKit, and Flux CD image automation.

### Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  ConfigMap Code │───▶│ Gitea Repository│───▶│ BuildKit CI/CD  │───▶│ Container Image │
│  git.x.org/hello│    │   hello repo    │    │ Gitea Actions   │    │   Registry      │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
   App Source Code        Repository Init        Automated Build         Image Storage
         │                       │                       │                       │
    ┌────▼────┐             ┌────▼────┐            ┌────▼────┐            ┌────▼────┐
    │Node.js  │             │Gitea API│            │buildctl │            │git.x.org│
    │Dockerfile│             │Secrets  │            │BuildKit │            │/v2/...  │
    └─────────┘             └─────────┘            └─────────┘            └─────────┘
```

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Container Image │───▶│ Flux Automation │───▶│ GitOps Update   │───▶│ Pod Deployment  │
│   Registry      │    │  Image Scanning │    │ Deployment YAML │    │ hello.x.org     │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
      Registry Scan        New Image Detection      Git Commit           Pod Restart
         │                       │                       │                       │
    ┌────▼────┐             ┌────▼────┐            ┌────▼────┐            ┌────▼────┐
    │Registry │             │ImageRepo│            │Image    │            │External │
    │Auth     │             │Policy   │            │Policy   │            │Access   │
    └─────────┘             └─────────┘            └─────────┘            └─────────┘
```

**Complete Flow**: ConfigMap → Repository → CI/CD → Registry → Flux → GitOps → Deployment

### Implementation Details

#### 1. Repository Bootstrap (`git.xuperson.org/hello/`)

The `hello-repo-setup` job creates a complete Node.js application in Gitea:

- **Source**: ConfigMaps contain app code, Dockerfile, and CI/CD workflow
- **Repository**: Auto-created in Gitea with proper structure and secrets
- **Authentication**: Admin token management with k8s secret synchronization

#### 2. CI/CD Pipeline (Gitea Actions + BuildKit)

When code is pushed to the repository:

```yaml
# Triggered on push to main/master branches
on:
  push:
    branches: [ main, master ]

# BuildKit workflow steps:
# 1. Clone repository with full context
# 2. Build container image using BuildKit daemon  
# 3. Tag with format: main-<commit-sha>
# 4. Push to Gitea package registry
# 5. Use insecure registry settings for internal access
```

**Registry Format**: `git.xuperson.org/helloroot/hello-app:main-<sha>`

#### 3. Image Registry (Gitea Packages)

- **Internal Access**: `gitea-http.gitea.svc.cluster.local:3000` (BuildKit pushes)
- **External Access**: `git.xuperson.org` (Flux pulls via Cloudflare tunnel)
- **Authentication**: Admin credentials stored in Kubernetes secrets
- **Tags**: Maintains `latest`, `cache`, and commit-specific tags

#### 4. Flux CD Image Automation

```yaml
# ImageRepository: Scans registry for new images
spec:
  image: git.xuperson.org/helloroot/hello-app
  interval: 2m
  secretRef:
    name: gitea-registry-secret

# ImagePolicy: Selects images based on pattern
spec:
  policy:
    alphabetical:
      order: asc
  filterTags:
    pattern: '^main-[a-f0-9]+$'
```

#### 5. GitOps Deployment Update

When Flux detects a new image:

1. **Image Detection**: ImageRepository scans registry every 2 minutes
2. **Policy Selection**: ImagePolicy filters tags matching `main-<commit-sha>` pattern
3. **Deployment Update**: ImageUpdateAutomation updates the deployment YAML
4. **Git Commit**: Flux commits the change back to the repository
5. **Pod Rollout**: Kubernetes performs rolling update with new image

### Registry Authentication

**Critical**: The registry secret must use actual Gitea admin credentials:

```bash
# Get current admin credentials
ADMIN_USER=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.password}' | base64 -d)

# Create registry auth string
AUTH_STRING=$(echo -n "$ADMIN_USER:$ADMIN_PASS" | base64)
```

### Troubleshooting Container Image Issues

**Image Pull Errors**:
```bash
# Check if image exists in registry
curl -u "helloroot:$ADMIN_PASS" https://git.xuperson.org/v2/_catalog

# Verify image tags
curl -u "helloroot:$ADMIN_PASS" https://git.xuperson.org/v2/helloroot/hello-app/tags/list
```

**Registry Authentication Failures**:
```bash
# Check registry secret
kubectl get secret gitea-registry-secret -n hello -o yaml

# Test external registry access
curl -u "helloroot:$ADMIN_PASS" https://git.xuperson.org/v2/_catalog
```

**Flux Image Automation Issues**:
```bash
# Check ImageRepository status
kubectl describe imagerepository hello-app -n hello

# Force image repository rescan
kubectl annotate imagerepository hello-app -n hello fluxcd.io/reconcileAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

**CI/CD Pipeline Failures**:
```bash
# Check runner logs
kubectl logs -n gitea deployment/act-runner-buildkit -c runner

# Check BuildKit daemon
kubectl logs -n gitea deployment/buildkitd
```

This completes your production-ready GitOps Kubernetes platform with secure secrets management, automated external access, and fully automated container image CI/CD lifecycle.


