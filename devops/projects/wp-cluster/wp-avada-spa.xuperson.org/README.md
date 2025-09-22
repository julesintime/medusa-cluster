# WordPress Avada Portfolio Site

**Domain**: [wp-avada-portfolio.xuperson.org](https://wp-avada-portfolio.xuperson.org)
**Theme**: Avada Pro
**Purpose**: Professional portfolio website

## 🏗️ Architecture

- **WordPress**: Official `wordpress:latest` image
- **Database**: MySQL 8.0
- **Storage**: Longhorn persistent volumes
- **Load Balancer**: MetalLB IP `192.168.80.122`
- **SSL**: Cloudflare automatic certificates
- **DNS**: ExternalDNS automatic record creation

## 📁 Directory Structure

```
wp-avada-portfolio.xuperson.org/
├── README.md                 # This file
├── k8s-manifests.yaml        # Complete Kubernetes deployment
├── wp-config/                # WordPress configuration
│   ├── wp-config.php         # Main WordPress config
│   ├── .htaccess             # Apache rewrite rules
│   ├── php.ini               # PHP configuration
│   └── mysql.cnf             # MySQL configuration
├── wp-content/               # WordPress content
│   ├── themes/               # Custom themes
│   ├── plugins/              # Custom plugins
│   └── uploads/              # Media uploads
├── docker-compose.yml        # Local development (optional)
└── Dockerfile                # Custom container (if needed)
```

## 🚀 Development Workflow

### 1. **Edit Files Directly**
```bash
# Edit theme files
vim wp-content/themes/avada-child/style.css
vim wp-content/themes/avada-child/functions.php

# Update WordPress config
vim wp-config/wp-config.php

# Modify Kubernetes settings
vim k8s-manifests.yaml
```

### 2. **Deploy Changes**
```bash
# Commit changes
git add .
git commit -m "Update portfolio theme styling"
git push origin main

# ArgoCD auto-syncs within 3 minutes
# Monitor: argocd app get wp-avada-portfolio --grpc-web
```

### 3. **Verify Deployment**
```bash
# Check pods
kubectl get pods -n wp-avada-portfolio

# Check services
kubectl get svc -n wp-avada-portfolio

# Check ingress
kubectl get ingress -n wp-avada-portfolio

# Test site
curl -I https://wp-avada-portfolio.xuperson.org
```

---

**Quick Start**: Edit files → `git push` → Live in 3 minutes! 🚀
