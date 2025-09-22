# WordPress Cluster Monorepo

A centralized monorepo for managing multiple WordPress sites via GitOps with ArgoCD.

## 🏗️ Architecture

This monorepo follows a domain-based organization pattern where each WordPress site gets its own folder named after its domain. All sites share common infrastructure components but maintain independent configurations.

## 📁 Repository Structure

```
wp-cluster/
├── README.md                          # This file
├── docs/                              # Documentation
│   ├── deployment.md                  # Deployment guide
│   ├── troubleshooting.md             # Common issues
│   └── adding-new-site.md             # How to add new sites
├── sites/                             # Common components
│   ├── template/                      # Site template for new sites
│   └── shared/                        # Shared configurations
├── wp-avada-portfolio.xuperson.org/   # Individual WordPress site
│   ├── k8s-manifests.yaml            # Kubernetes manifests
│   ├── wp-config/                     # WordPress config files
│   ├── wp-content/                    # WordPress content (themes, plugins)
│   └── README.md                      # Site-specific documentation
└── [domain-name].xuperson.org/        # Additional WordPress sites...
```

## 🚀 GitOps Workflow

### 1. **Direct Editing** (Recommended)
Edit WordPress files directly in this repository:

```bash
# Edit theme files
vim wp-avada-portfolio.xuperson.org/wp-content/themes/avada-child/style.css

# Update WordPress config
vim wp-avada-portfolio.xuperson.org/wp-config/wp-config.php

# Modify Kubernetes manifests
vim wp-avada-portfolio.xuperson.org/k8s-manifests.yaml

# Commit and push (triggers ArgoCD deployment)
git add .
git commit -m "Update Avada portfolio styling"
git push origin main
```

### 2. **ArgoCD Integration**
Each site has its own ArgoCD Application pointing to its specific folder:

```yaml
# ArgoCD Application for wp-avada-portfolio
spec:
  source:
    repoURL: https://github.com/julesintime/wp-cluster.git
    targetRevision: main
    path: wp-avada-portfolio.xuperson.org
```

### 3. **Automatic Deployment**
- **Git Push** → **ArgoCD Sync** → **Live Changes** (within 3 minutes)
- No container builds required - uses official WordPress image + mounted content
- Real-time monitoring via ArgoCD UI

## 🎯 Benefits

- ✅ **Centralized Management**: All WordPress sites in one repository
- ✅ **Individual Isolation**: Each site maintains independent configurations
- ✅ **GitOps Automation**: Git push → automatic deployment
- ✅ **Version Control**: Full history for all WordPress customizations
- ✅ **Team Collaboration**: Multiple developers can edit simultaneously
- ✅ **No Container Builds**: Direct file mounting approach
- ✅ **Scalable**: Easy to add new WordPress sites

## 📋 Adding a New WordPress Site

1. **Copy Template**:
   ```bash
   cp -r sites/template/ new-site.xuperson.org/
   ```

2. **Update Configurations**:
   ```bash
   # Update domain, namespace, LoadBalancer IP
   vim new-site.xuperson.org/k8s-manifests.yaml
   ```

3. **Create ArgoCD Application**:
   ```bash
   # In labinfra repository
   cp devops/applications/wp-avada-portfolio-app.yaml devops/applications/new-site-app.yaml
   # Update source.path to point to new-site.xuperson.org
   ```

4. **Deploy**:
   ```bash
   git add . && git commit -m "Add new WordPress site" && git push
   ```

## 🔧 Configuration Management

### Secrets Management
- Use **Infisical** for all sensitive data (database passwords, API keys)
- Never commit secrets to git
- Reference Infisical secrets in Kubernetes manifests

### MetalLB IP Pool
Available IPs: `192.168.80.100-150`
Check used IPs: `kubectl get svc -A | grep LoadBalancer`

### DNS & SSL
- **Domain Pattern**: `[site-name].xuperson.org`
- **DNS**: ExternalDNS automatically creates records
- **SSL**: Cloudflare provides automatic certificates

## 📖 Documentation

- [Deployment Guide](docs/deployment.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Adding New Sites](docs/adding-new-site.md)

## 🏷️ Sites in this Monorepo

- [`wp-avada-portfolio.xuperson.org`](wp-avada-portfolio.xuperson.org/) - WordPress portfolio site with Avada theme

---

**GitOps Power**: Edit files → Git push → Live deployment in minutes! 🚀