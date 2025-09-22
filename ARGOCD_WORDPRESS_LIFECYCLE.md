# ArgoCD WordPress Lifecycle Guide

## 🔄 Complete WordPress GitOps Workflow

### **Repository Setup**
```bash
# 1. Create GitHub project repo
gh repo create julesintime/wp-project --public

# 2. Add as git subtree to labinfra
git subtree add --prefix=devops/projects/wp-project \
  https://github.com/julesintime/wp-project.git main --squash

# 3. GitHub token in Infisical
infisical secrets set GITHUB_TOKEN=$(gh auth token) --env=prod --path="/"
```

### **ArgoCD Integration**
```bash
# 1. Add GitHub repo to ArgoCD (one-time)
argocd repo add https://github.com/julesintime/labinfra.git \
  --username julesintime \
  --password $(cd devops && infisical secrets get GITHUB_TOKEN --env=prod --plain) \
  --grpc-web

# 2. Create ArgoCD Application
cat > devops/applications/wp-project-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wp-project
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/julesintime/labinfra.git
    targetRevision: main
    path: devops/projects/wp-project
  destination:
    server: https://kubernetes.default.svc
    namespace: wp-project
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# 3. Deploy application
argocd app create -f devops/applications/wp-project-app.yaml --grpc-web
```

### **WordPress Deployment (No Build Required)**
```yaml
# devops/projects/wp-project/k8s-manifests.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wp-project
spec:
  template:
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest  # Use official WordPress image
        volumeMounts:
        - name: wp-content          # Mount git subtree files
          mountPath: /var/www/html/wp-content
        - name: wp-config
          mountPath: /var/www/html/wp-config.php
          subPath: wp-config.php
      volumes:
      - name: wp-content
        configMap:
          name: wp-content-files    # WordPress files from git
      - name: wp-config
        configMap:
          name: wp-config
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: wp-project
spec:
  type: LoadBalancer
  loadBalancerIP: "192.168.80.XXX"  # Pick available IP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: wordpress
```

### **WordPress Content from Git**
```yaml
# Mount WordPress files directly from git subtree
apiVersion: v1
kind: ConfigMap
metadata:
  name: wp-content-files
  namespace: wp-project
data:
  # Copy files from git subtree
  index.php: |
    <?php
    // Your WordPress customizations
binaryData:
  # Themes, plugins, uploads from git subtree
  avada-theme.zip: <base64-encoded-theme>
```

### **Daily Workflow**
```bash
# 1. Edit WordPress files in subtree
vim devops/projects/wp-project/wp-content/themes/custom-theme/style.css
vim devops/projects/wp-project/wp-config/wp-config.php

# 2. Commit to GitOps repo (triggers ArgoCD)
git add devops/projects/wp-project/
git commit -m "Update WordPress theme styling"
git push origin main

# 3. ArgoCD auto-syncs within 3 minutes
argocd app get wp-project --grpc-web

# 4. Optional: Push back to project repo
git subtree push --prefix=devops/projects/wp-project \
  https://github.com/julesintime/wp-project.git main
```

### **Key Benefits**
- ✅ **No Container Builds**: Use official WordPress image + mounted files
- ✅ **Direct Editing**: WordPress files in git subtree, IDE-friendly
- ✅ **Auto Deployment**: Git push → ArgoCD sync → live changes
- ✅ **Version Control**: All WordPress customizations in git
- ✅ **Team Collaboration**: Multiple devs edit same subtree

### **MetalLB IP Pool**
```bash
# Check available IPs
kubectl get svc -A | grep LoadBalancer

# Available range: 192.168.80.100-150
# Used: 100,101,102,103,104,105,106,110,120,121,122
# Next available: 123,124,125...
```

### **Secret Management**
```bash
# WordPress database credentials via Infisical
infisical secrets set WP_DB_PASSWORD=$(openssl rand -base64 32) --env=prod
infisical secrets set WP_DB_NAME=wp_project --env=prod
infisical secrets set WP_DB_USER=wordpress --env=prod

# InfisicalSecret syncs to kubernetes.io/basic-auth
```

### **External Access**
- **Domain**: `wp-project.xuperson.org` (auto-created by ExternalDNS)
- **SSL**: Cloudflare automatic certificates
- **CDN**: Cloudflare global caching

This approach eliminates container builds while maintaining full GitOps automation!