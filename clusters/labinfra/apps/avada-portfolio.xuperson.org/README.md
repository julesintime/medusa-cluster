# Avada Portfolio - ArgoCD Application

WordPress portfolio application deployed using ArgoCD, replacing Docker Compose setup with Kubernetes-native deployment.

## Architecture

### Application Components
- **WordPress**: Latest WordPress with custom PHP configuration
- **MySQL 8.0**: Database backend with persistent storage
- **Persistent Storage**: Longhorn-backed PVCs for WordPress content and MySQL data
- **External Access**: NGINX Ingress with automatic DNS via ExternalDNS

### Security & Configuration
- **Secrets Management**: All credentials managed via Infisical
- **Security Context**: Non-root containers where possible with minimal capabilities
- **Resource Limits**: CPU and memory limits for stable performance
- **Health Checks**: Liveness and readiness probes for both components

## External Access

- **URL**: https://avada-portfolio.xuperson.org
- **LoadBalancer**: 192.168.80.115 (MetalLB)
- **DNS**: Automatic CNAME record creation via ExternalDNS

## Required Secrets in Infisical

Create these secrets in Infisical (prod environment, root path):

```bash
# MySQL database secrets
infisical secrets set AVADA_MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32) --env=prod
infisical secrets set AVADA_MYSQL_DATABASE="wordpress" --env=prod
infisical secrets set AVADA_MYSQL_USER="wp_user" --env=prod
infisical secrets set AVADA_MYSQL_PASSWORD=$(openssl rand -base64 32) --env=prod

# WordPress security keys (generate from https://api.wordpress.org/secret-key/1.1/salt/)
infisical secrets set AVADA_WP_AUTH_KEY="your-auth-key" --env=prod
infisical secrets set AVADA_WP_SECURE_AUTH_KEY="your-secure-auth-key" --env=prod
infisical secrets set AVADA_WP_LOGGED_IN_KEY="your-logged-in-key" --env=prod
infisical secrets set AVADA_WP_NONCE_KEY="your-nonce-key" --env=prod
```

## ArgoCD Integration

This application is managed by ArgoCD and automatically syncs from Git:

- **Application Name**: `avada-portfolio`
- **Source**: Git repository `clusters/labinfra/apps/avada-portfolio.xuperson.org/`
- **Sync Policy**: Automated with pruning and self-healing
- **Health Checks**: Custom health checks for WordPress and MySQL

## CI/CD Pipeline

### Automated Deployment
The application includes integration with Argo Workflows for automated CI/CD:

1. **Webhook Trigger**: Git pushes trigger Argo Events
2. **Build Phase**: Kaniko builds custom WordPress images
3. **Deploy Phase**: ArgoCD syncs updated manifests
4. **Testing Phase**: Integration tests verify deployment

### Manual Operations

```bash
# Trigger manual build and deployment
argo submit --from workflowtemplate/portfolio-manual-trigger \
  -p trigger-reason="Manual deployment for feature X"

# Check application status
kubectl get applications -n argocd avada-portfolio

# View application in ArgoCD UI
# https://argocd.xuperson.org/applications/avada-portfolio
```

## Monitoring & Troubleshooting

### Application Status
```bash
# Check pod status
kubectl get pods -n avada-portfolio

# Check persistent volumes
kubectl get pvc -n avada-portfolio

# Check services and ingress
kubectl get svc,ingress -n avada-portfolio

# View logs
kubectl logs -n avada-portfolio deployment/wordpress
kubectl logs -n avada-portfolio deployment/mysql
```

### Infisical Secret Sync
```bash
# Check secret synchronization
kubectl get infisicalsecrets -n avada-portfolio
kubectl describe infisicalsecret avada-portfolio-secrets -n avada-portfolio

# View synced secrets
kubectl get secrets -n avada-portfolio
```

### ArgoCD Application
```bash
# Check ArgoCD application health
kubectl get application -n argocd avada-portfolio

# Force sync if needed
argocd app sync avada-portfolio

# View application details
argocd app get avada-portfolio
```

## Migration from Docker Compose

This deployment replaces the original Docker Compose setup with:

### ✅ Improvements
- **High Availability**: Kubernetes scheduling and health checks
- **Persistent Storage**: Longhorn-backed storage with snapshots
- **Security**: Kubernetes security contexts and network policies
- **Scalability**: Can be scaled horizontally if needed
- **GitOps**: Declarative configuration managed via Git
- **CI/CD Integration**: Automated builds and deployments

### 🔄 Equivalent Features
- **WordPress + MySQL**: Same application stack
- **Persistent Data**: WordPress content and database persist across restarts
- **External Access**: HTTPS access via domain name
- **Custom Configuration**: PHP and MySQL configuration via ConfigMaps

## Rollback Procedures

### Emergency Rollback
```bash
# Rollback ArgoCD application to previous revision
argocd app rollback avada-portfolio

# Or rollback specific deployment
kubectl rollout undo deployment/wordpress -n avada-portfolio
kubectl rollout undo deployment/mysql -n avada-portfolio
```

### Data Recovery
```bash
# List Longhorn snapshots
kubectl get volumesnapshots -n avada-portfolio

# Restore from snapshot if needed
# (Follow Longhorn restoration procedures)
```

## Performance Tuning

### Resource Allocation
Current resource allocations are conservative. For high-traffic scenarios:

```yaml
# WordPress resources (in deployment YAML)
resources:
  requests:
    cpu: 500m      # Increase from 250m
    memory: 1Gi    # Increase from 512Mi
  limits:
    cpu: 2000m     # Increase from 1000m
    memory: 4Gi    # Increase from 2Gi

# MySQL resources
resources:
  requests:
    cpu: 500m      # Increase from 250m
    memory: 1Gi    # Increase from 512Mi
  limits:
    cpu: 2000m     # Increase from 1000m
    memory: 4Gi    # Increase from 2Gi
```

### Horizontal Scaling
WordPress can be scaled horizontally:

```bash
# Scale WordPress pods
kubectl scale deployment wordpress --replicas=3 -n avada-portfolio

# Note: MySQL should remain at 1 replica unless using a cluster setup
```