# ArgoCD WordPress Monorepo Lifecycle Guide

## 🏗️ WordPress Cluster Monorepo Pattern

### **Monorepo Architecture**
All WordPress sites are managed in a centralized `wp-cluster` monorepo with individual site isolation:

```
wp-cluster/                              # Main monorepo
├── README.md                            # Monorepo documentation
├── sites/template/                      # Template for new sites
├── wp-avada-portfolio.xuperson.org/     # Individual WordPress site
├── new-site.xuperson.org/              # Additional sites...
└── docs/                               # Shared documentation
```

### **Repository Setup (One-Time)**
```bash
# 1. WordPress cluster monorepo already exists
# Repository: https://github.com/julesintime/wp-cluster

# 2. Integrated as git subtree in labinfra
git subtree add --prefix=devops/projects/wp-cluster \
  https://github.com/julesintime/wp-cluster.git main --squash

# 3. GitHub token in Infisical (if not already set)
infisical secrets set GITHUB_TOKEN=$(gh auth token) --env=prod --path="/"
```

### **ArgoCD Integration (Per Site)**
```bash
# 1. ArgoCD repository already configured (labinfra)
# No additional repo setup needed

# 2. Create ArgoCD Application for new site
cat > devops/applications/new-site-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: new-site
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/julesintime/labinfra.git
    targetRevision: main
    path: devops/projects/wp-cluster/new-site.xuperson.org
  destination:
    server: https://kubernetes.default.svc
    namespace: new-site
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# 3. Deploy application
argocd app create -f devops/applications/new-site-app.yaml --grpc-web
```

### **Adding a New WordPress Site**
```bash
# 1. Create new site in wp-cluster monorepo
cd /tmp && git clone https://github.com/julesintime/wp-cluster.git
cd wp-cluster

# 2. Copy template to new site folder
cp -r sites/template/ new-site.xuperson.org/

# 3. Update site configuration
vim new-site.xuperson.org/k8s-manifests.yaml
# Update: namespace, domain, LoadBalancer IP

# 4. Add site-specific WordPress content
mkdir -p new-site.xuperson.org/wp-content/{themes,plugins,uploads}
mkdir -p new-site.xuperson.org/wp-config

# 5. Commit and push to monorepo
git add . && git commit -m "Add new WordPress site: new-site.xuperson.org" && git push

# 6. Update labinfra subtree
cd /path/to/labinfra
git subtree pull --prefix=devops/projects/wp-cluster \
  https://github.com/julesintime/wp-cluster.git main --squash

# 7. Create ArgoCD application (see above)
# 8. Commit labinfra changes
git add . && git commit -m "Add new WordPress site to cluster" && git push
```

### **WordPress Deployment Architecture**
```yaml
# Each site follows this pattern: site-name.xuperson.org/k8s-manifests.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: site-namespace
spec:
  template:
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest  # Official WordPress image
        volumeMounts:
        - name: wp-content       # Persistent WordPress content
          mountPath: /var/www/html/wp-content
        - name: wp-config       # ConfigMap WordPress config
          mountPath: /var/www/html/wp-config.php
          subPath: wp-config.php
      volumes:
      - name: wp-content
        persistentVolumeClaim:
          claimName: wp-content-pvc
      - name: wp-config
        configMap:
          name: wp-config
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: site-namespace
spec:
  type: LoadBalancer
  loadBalancerIP: "192.168.80.XXX"  # Pick available IP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: wordpress
```

### **Daily Development Workflow**

#### **Option A: Direct Editing (Recommended)**
```bash
# 1. Edit WordPress files directly in labinfra subtree
vim devops/projects/wp-cluster/wp-avada-portfolio.xuperson.org/wp-content/themes/avada-child/style.css
vim devops/projects/wp-cluster/wp-avada-portfolio.xuperson.org/wp-config/wp-config.php

# 2. Commit to labinfra (triggers ArgoCD immediately)
git add devops/projects/wp-cluster/
git commit -m "Update WordPress theme styling for avada portfolio"
git push origin main

# 3. ArgoCD auto-syncs within 3 minutes
argocd app get wp-avada-portfolio --grpc-web

# 4. Optional: Sync changes back to monorepo
git subtree push --prefix=devops/projects/wp-cluster \
  https://github.com/julesintime/wp-cluster.git main
```

#### **Option B: Monorepo-First Development**
```bash
# 1. Work directly in wp-cluster monorepo
cd /tmp && git clone https://github.com/julesintime/wp-cluster.git && cd wp-cluster

# 2. Edit WordPress files
vim wp-avada-portfolio.xuperson.org/wp-content/themes/avada-child/style.css
vim wp-avada-portfolio.xuperson.org/wp-config/wp-config.php

# 3. Commit and push to monorepo
git add . && git commit -m "Update theme styling" && git push

# 4. Pull changes into labinfra subtree
cd /path/to/labinfra
git subtree pull --prefix=devops/projects/wp-cluster \
  https://github.com/julesintime/wp-cluster.git main --squash

# 5. Push labinfra to trigger ArgoCD
git push origin main
```

### **Key Benefits of Monorepo Pattern**
- ✅ **Centralized Management**: All WordPress sites in one repository
- ✅ **Individual Site Isolation**: Each site maintains independent configurations
- ✅ **Scalable Architecture**: Easy to add new WordPress sites using template
- ✅ **No Container Builds**: Use official WordPress image + mounted files
- ✅ **Direct Editing**: WordPress files in git subtree, IDE-friendly
- ✅ **GitOps Automation**: Git push → ArgoCD sync → live changes
- ✅ **Version Control**: Complete history for all WordPress customizations
- ✅ **Team Collaboration**: Multiple developers can edit simultaneously
- ✅ **Template-Based**: Consistent structure across all sites
- ✅ **Dual Workflow**: Work directly in labinfra or monorepo

### **WordPress Sites in Cluster**
- **wp-avada-portfolio.xuperson.org**: Professional portfolio site with Avada theme
- **Add more sites**: Copy template and update ArgoCD application

### **MetalLB IP Pool Management**
```bash
# Check available IPs across all WordPress sites
kubectl get svc -A | grep LoadBalancer | grep wp-

# Available range: 192.168.80.100-150
# Current allocation:
# - wp-avada-portfolio: 192.168.80.122
# Next available: 123,124,125,126...
```

### **Secret Management (Per Site)**
```bash
# WordPress database credentials via Infisical (per site)
infisical secrets set WP_AVADA_DB_PASSWORD=$(openssl rand -base64 32) --env=prod
infisical secrets set WP_AVADA_DB_NAME=wp_avada_portfolio --env=prod
infisical secrets set WP_AVADA_DB_USER=wordpress --env=prod

# For new sites, use appropriate naming convention
infisical secrets set WP_NEWSITE_DB_PASSWORD=$(openssl rand -base64 32) --env=prod
```

### **External Access Pattern**
- **Domain Pattern**: `[site-name].xuperson.org` (auto-created by ExternalDNS)
- **SSL**: Cloudflare automatic certificates
- **CDN**: Cloudflare global caching
- **Load Balancing**: MetalLB with dedicated IPs per site

### **Monitoring All Sites**
```bash
# Check all WordPress deployments
kubectl get pods,svc,ingress -A | grep wp-

# ArgoCD applications
argocd app list | grep wp-

# Monitor specific site
argocd app get wp-avada-portfolio --grpc-web
```

## 🚀 **Complete GitOps Power**

**Monorepo Pattern**: One repository → Multiple sites → Centralized management → Individual site control!

**Development Flow**: Edit files → Git push → ArgoCD sync → Live deployment → Zero downtime!