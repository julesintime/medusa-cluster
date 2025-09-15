# Prerequisites Setup - Free Accounts and Tools

**Complete infrastructure-ready account setup in 30 minutes**

This guide walks you through creating all necessary accounts and configuring local tools to deploy production-ready cloud-native infrastructure at zero monthly cost (domain registration fees only).

## Quick Setup Checklist

- [ ] **GitHub account** with personal access token (5 min)
- [ ] **Cloudflare account** with domain and API token (10 min)  
- [ ] **Local development environment** setup (10 min)
- [ ] **Optional: Cloud VPS provider** for hosted deployment (5 min)

**Total time: 30 minutes** | **Monthly cost: $0** (plus domain fees)

---

## GitHub Account Setup

### Why GitHub?
- **GitOps repository hosting**: Source of truth for infrastructure configuration
- **Free private repositories**: Unlimited for small teams
- **GitHub Actions**: Optional CI/CD for application builds
- **Community integration**: Access to Helm charts, operators, and tooling

### Account Creation
1. **Sign up**: Visit [github.com](https://github.com) and create account
2. **Verify email**: Check inbox and verify email address  
3. **Enable 2FA**: Settings → Security → Two-factor authentication

### Personal Access Token
GitOps requires programmatic Git access for Flux to read repository configurations.

1. **Navigate**: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. **Generate token**: "Generate new token (classic)"
3. **Token name**: `flux-gitops-access`
4. **Expiration**: 1 year (renewable)
5. **Scopes required**:
   - `repo` (full control of private repositories)
   - `workflow` (update GitHub Action workflows)

```bash
# Save token securely - you'll need it for Flux bootstrap
export GITHUB_TOKEN="ghp_your_token_here"
echo $GITHUB_TOKEN > ~/.github-token
chmod 600 ~/.github-token
```

**Security note**: Never commit this token to any repository. Store in password manager or secure local file.

---

## Cloudflare Account Setup

### Why Cloudflare?
- **Free tier includes**: DNS management, SSL certificates, DDoS protection
- **ExternalDNS integration**: Automatic DNS record creation from Kubernetes
- **Global CDN**: Performance and security for applications
- **Enterprise-grade features**: Rate limiting, firewall rules, analytics

### Account Creation
1. **Sign up**: Visit [cloudflare.com](https://cloudflare.com) and create account
2. **Verify email**: Check inbox and verify account
3. **Plan selection**: Free tier sufficient for getting started

### Domain Configuration
You need a domain name for external access to applications. Options:

#### Option 1: Transfer Existing Domain
1. **Add site**: Cloudflare dashboard → "Add a site"
2. **Enter domain**: `yourdomain.com` 
3. **Plan selection**: Free
4. **DNS scan**: Review detected records
5. **Update nameservers**: At your domain registrar, change nameservers to Cloudflare's

#### Option 2: Register New Domain  
1. **Domain registrar**: Use [Namecheap](https://namecheap.com), [Google Domains](https://domains.google), or any registrar
2. **Cost**: ~$8-15/year depending on TLD
3. **Configuration**: Point nameservers to Cloudflare during registration
4. **Add to Cloudflare**: Add domain to Cloudflare account after registration

#### Recommended Domain Strategy
- **Personal projects**: `yourname.dev` or `yourname.io`
- **Business demos**: `companyname.com` or `companyname.app`
- **Development**: Consider `.dev` TLD for HTTPS-by-default

### API Token Creation
ExternalDNS needs programmatic access to manage DNS records.

1. **Navigate**: Cloudflare dashboard → My Profile → API Tokens
2. **Create token**: "Create Token"
3. **Template**: "Custom token"
4. **Permissions**:
   - `Zone:Zone:Read` (all zones)
   - `Zone:DNS:Edit` (specific zone or all zones)
5. **Zone resources**: Include specific zones you want to manage
6. **Token name**: `external-dns-management`

```bash
# Test API token
curl -H "Authorization: Bearer your_token_here" \
  "https://api.cloudflare.com/client/v4/user/tokens/verify"

# Save token securely
export CLOUDFLARE_API_TOKEN="your_token_here"
echo $CLOUDFLARE_API_TOKEN > ~/.cloudflare-token
chmod 600 ~/.cloudflare-token
```

### DNS Zone Configuration
1. **A record for cluster**: Create A record pointing to your server IP
   - **Name**: `k3s` 
   - **IPv4 address**: Your server's public IP
   - **TTL**: Auto
2. **Wildcard for apps**: Create CNAME record for application domains
   - **Name**: `*` (wildcard)
   - **Target**: `k3s.yourdomain.com`
   - **TTL**: Auto

---

## Local Development Environment

### Required Tools

#### kubectl - Kubernetes CLI
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Windows
winget install -e --id Kubernetes.kubectl

# Verify installation
kubectl version --client
```

#### Flux CLI - GitOps Controller
```bash
# macOS  
brew install fluxcd/tap/flux

# Linux
curl -s https://fluxcd.io/install.sh | sudo bash

# Windows
winget install -e --id FluxCD.Flux

# Verify installation
flux version
```

#### Helm - Kubernetes Package Manager
```bash
# macOS
brew install helm

# Linux  
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows
winget install -e --id Helm.Helm

# Verify installation
helm version
```

#### Git Configuration
```bash
# Configure identity (required for GitOps commits)
git config --global user.name "Your Name"
git config --global user.email "your.email@domain.com"

# Configure default branch (consistency with GitHub)
git config --global init.defaultBranch main

# Verify configuration
git config --global --list
```

### Optional Development Tools

#### k9s - Kubernetes Terminal UI
```bash
# macOS
brew install k9s

# Linux
curl -sS https://webinstall.dev/k9s | bash

# Windows  
winget install -e --id K9sProject.K9s
```

#### kubectx/kubens - Context Switching
```bash
# macOS
brew install kubectx

# Linux
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# Windows
winget install -e --id ahmetb.kubectx
```

### Environment Validation
```bash
# Create workspace directory
mkdir -p ~/cloud-native-workspace
cd ~/cloud-native-workspace

# Test all tools
kubectl version --client
flux version --client  
helm version
git --version

# Test API access
export GITHUB_TOKEN=$(cat ~/.github-token)
export CLOUDFLARE_API_TOKEN=$(cat ~/.cloudflare-token)

# Verify GitHub access
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Verify Cloudflare access
curl -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/user/tokens/verify
```

---

## Cloud VPS Provider (Optional)

If you don't have existing hardware, these providers offer excellent free tiers or low-cost VPS options:

### Free Tier Options

#### Oracle Cloud Always Free
- **Resources**: 1-4 ARM-based Compute instances (24GB RAM total)
- **Network**: 10TB monthly transfer  
- **Storage**: 200GB block storage
- **Cost**: $0/month permanently
- **Setup**: [Oracle Cloud signup](https://cloud.oracle.com/free)

#### Google Cloud Platform Free Tier
- **Resources**: 1 f1-micro instance (1vCPU, 0.6GB RAM)
- **Credits**: $300 for 90 days for larger instances
- **Network**: 1GB North America to most regions per month
- **Setup**: [GCP signup](https://cloud.google.com/free)

### Budget VPS Options ($5-20/month)

#### DigitalOcean
- **Droplet**: $6/month (1vCPU, 1GB RAM, 25GB SSD)
- **Features**: Simple control panel, marketplace apps
- **Regions**: Global presence
- **Setup**: [DigitalOcean referral](https://m.do.co/c/kubernetes) ($100 credit)

#### Linode  
- **Nanode**: $5/month (1vCPU, 1GB RAM, 25GB SSD)
- **Features**: Excellent performance, good documentation
- **Setup**: [Linode signup](https://linode.com)

#### Hetzner Cloud
- **CX11**: €3.29/month (~$3.50, 1vCPU, 2GB RAM, 20GB SSD)
- **Features**: Great price/performance, European data centers
- **Setup**: [Hetzner Cloud](https://hetzner.cloud)

### VPS Requirements
**Minimum for K3s cluster:**
- **CPU**: 1 vCPU  
- **RAM**: 1GB (2GB recommended)
- **Storage**: 20GB SSD
- **Network**: 1TB/month transfer
- **OS**: Ubuntu 22.04 LTS

**Production recommendations:**
- **CPU**: 2 vCPUs
- **RAM**: 4GB  
- **Storage**: 40GB SSD
- **Network**: Unmetered or high limit

---

## Security Configuration

### SSH Key Setup
For secure VPS access without passwords:

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -C "your.email@domain.com" -f ~/.ssh/cloud-native-key

# Add to SSH agent
ssh-add ~/.ssh/cloud-native-key

# Copy public key for VPS setup
cat ~/.ssh/cloud-native-key.pub
```

### Local Security Best Practices
```bash
# Set restrictive permissions on credential files
chmod 600 ~/.github-token ~/.cloudflare-token ~/.ssh/cloud-native-key

# Add credentials to .gitignore globally
echo -e "*.token\n.env\n*.key" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global

# Create secure credential directory
mkdir -p ~/.config/cloud-native
chmod 700 ~/.config/cloud-native
```

---

## Cost Analysis

### Free Tier Infrastructure
- **GitHub**: Free (unlimited public/private repos)
- **Cloudflare**: Free (DNS, SSL, CDN, basic security)
- **K3s software**: Free (Apache 2.0 license)
- **Flux, Helm, kubectl**: Free (open source tools)

### Paid Requirements
- **Domain registration**: $8-15/year
- **VPS hosting**: $0-20/month (optional if using existing hardware)

### Total Monthly Cost
- **With existing hardware**: $0/month + domain fees
- **With budget VPS**: $5-20/month + domain fees
- **Enterprise features**: Available but not required

---

## Troubleshooting

### GitHub Token Issues
**Symptom**: "authentication failed" during Flux bootstrap
**Solution**: 
```bash
# Test token manually
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Check token scopes
curl -H "Authorization: token $GITHUB_TOKEN" -I https://api.github.com/user | grep -i x-oauth-scopes
```

### Cloudflare API Issues
**Symptom**: ExternalDNS cannot create records
**Solution**:
```bash
# Verify token permissions
curl -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/zones

# Check zone access
curl -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID
```

### Local Tool Issues
**Symptom**: Command not found errors
**Solution**:
```bash
# Check PATH
echo $PATH

# Reinstall tools with package manager
brew upgrade kubectl helm flux # macOS
apt update && apt upgrade # Linux
```

---

## Next Steps

With prerequisites complete, you're ready for infrastructure deployment:

→ **[02-infrastructure-bootstrap.md](./02-infrastructure-bootstrap.md)** - Deploy K3s cluster with GitOps

### What You Have Now
- ✅ GitHub account with GitOps access token
- ✅ Cloudflare account with DNS management API
- ✅ Local development tools (kubectl, flux, helm)  
- ✅ Optional: Cloud VPS or local server ready
- ✅ Security credentials properly configured

### What's Next
- **Infrastructure deployment**: Automated K3s cluster with Ansible
- **GitOps setup**: Flux controller connecting to your GitHub repository
- **Load balancer configuration**: MetalLB for external service access  
- **Ingress controller**: NGINX for HTTP/HTTPS routing

**Estimated time for next session**: 45 minutes to running cluster