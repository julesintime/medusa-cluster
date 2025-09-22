# ArgoCD Workflows CI/CD Implementation

**🎯 Mission**: Replace Gitea Act Runner + Tekton with ArgoCD Workflows for complete CI/CD automation

## Overview

This implementation provides a complete CI/CD solution using the Argo ecosystem to replace the existing Gitea Act Runner and Tekton setup, while maintaining compatibility with the existing Flux CD GitOps infrastructure.

## Architecture

### Core Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Git Push      │───▶│   Argo Events    │───▶│ Argo Workflows  │
│   (Webhook)     │    │   (EventSource   │    │ (Build Pipeline) │
└─────────────────┘    │    + Sensor)     │    └─────────────────┘
                       └──────────────────┘             │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │◀───│     ArgoCD       │◀───│  Updated        │
│   Running       │    │   (Deployment)   │    │  Manifests      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Component Roles

| Component | Replaces | Purpose |
|-----------|----------|---------|
| **Argo Events** | Gitea Webhooks | Receives Git push events, triggers workflows |
| **Argo Workflows** | Gitea Act Runner | Builds container images, runs tests |
| **ArgoCD Applications** | Tekton Pipelines | Manages application deployments |
| **Flux CD** | - | Continues managing infrastructure and ArgoCD itself |

## Deployed Applications

### 1. Avada Portfolio (`avada-portfolio.xuperson.org`)
- **WordPress + MySQL** application
- **URL**: https://avada-portfolio.xuperson.org
- **LoadBalancer**: 192.168.80.115
- **Secrets**: Managed via Infisical

### 2. Argo Workflows CI/CD (`argo-workflows-cicd.argocd`)
- **WorkflowTemplates**: Build and deployment pipelines
- **CronWorkflows**: Scheduled CI/CD runs
- **RBAC**: Service accounts and permissions

### 3. Argo Events Webhooks (`argo-events-webhooks.argocd`)
- **EventSources**: Git webhook receivers
- **Sensors**: Workflow trigger logic
- **Ingress**: Public webhook endpoints

## CI/CD Pipeline Flow

### 1. Webhook Trigger
```bash
# Webhook endpoints
https://webhooks.xuperson.org/portfolio-webhook  # Portfolio-specific
https://webhooks.xuperson.org/git-webhook        # Generic Git events
```

### 2. Build Pipeline (`portfolio-build-pipeline`)
```yaml
Steps:
1. git-clone      # Clone repository
2. kaniko-build   # Build container images (replaces Docker builds)
3. update-manifests # Update deployment manifests with new image tags
```

### 3. Deploy Pipeline (`portfolio-deploy-pipeline`)
```yaml
Steps:
1. pre-deployment-check   # Health checks
2. argocd-sync           # Trigger ArgoCD application sync
3. wait-sync-complete    # Wait for deployment completion
4. post-deployment-test  # Integration tests
5. notify-completion     # Success notifications
```

## Replacement Strategy

### ❌ Old (Gitea Act Runner + Tekton)
```
Git Push → Gitea Webhook → Gitea Act Runner → Docker Build → Tekton Pipeline → kubectl apply
```

### ✅ New (ArgoCD Workflows)
```
Git Push → Argo Events → Argo Workflows → Kaniko Build → Update Manifests → ArgoCD Sync
```

### Key Improvements

| Aspect | Old | New |
|--------|-----|-----|
| **Build Engine** | Docker-in-Docker | Kaniko (secure, rootless) |
| **Pipeline Definition** | Tekton YAML | Argo Workflow YAML |
| **Deployment** | kubectl apply | ArgoCD GitOps |
| **Webhook Handling** | Gitea-specific | Universal (GitHub, GitLab, Gitea) |
| **Secret Management** | Manual | Infisical integration |
| **Monitoring** | Limited | Argo UI + Kubernetes events |

## Operational Procedures

### Trigger Manual Build
```bash
# Start manual CI/CD pipeline
argo submit --from workflowtemplate/portfolio-manual-trigger \
  -p trigger-reason="Deploy new feature" \
  -p revision="feature-branch"

# Monitor workflow
argo get @latest
argo logs @latest
```

### Scheduled Builds
```bash
# View scheduled workflows
kubectl get cronworkflows -n argocd

# Check last run
argo cron list
```

### Monitor Webhooks
```bash
# Check webhook events
kubectl logs -n argocd deployment/argo-events-controller-manager

# Test webhook
curl -X POST https://webhooks.xuperson.org/portfolio-webhook \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/main","repository":{"full_name":"test/repo"}}'
```

### ArgoCD Application Management
```bash
# View applications
argocd app list

# Sync application
argocd app sync avada-portfolio

# Check application health
argocd app get avada-portfolio
```

## Required Secrets in Infisical

### Application Secrets
```bash
# Avada Portfolio WordPress
AVADA_MYSQL_ROOT_PASSWORD=<generated>
AVADA_MYSQL_DATABASE=wordpress
AVADA_MYSQL_USER=wp_user
AVADA_MYSQL_PASSWORD=<generated>
AVADA_WP_AUTH_KEY=<from WordPress.org API>
AVADA_WP_SECURE_AUTH_KEY=<from WordPress.org API>
AVADA_WP_LOGGED_IN_KEY=<from WordPress.org API>
AVADA_WP_NONCE_KEY=<from WordPress.org API>

# CI/CD Pipeline (if using private registries)
GITEA_ADMIN_USERNAME=<admin-user>
GITEA_ADMIN_PASSWORD=<admin-password>
DOCKER_REGISTRY_USERNAME=<registry-user>
DOCKER_REGISTRY_PASSWORD=<registry-password>
```

## Integration Points

### With Existing Flux CD
- **No Conflicts**: Flux manages ArgoCD installation, ArgoCD manages applications
- **Namespace Separation**: `flux-system` (Flux) vs `argocd` (ArgoCD) vs `avada-portfolio` (Apps)
- **GitOps Harmony**: Both tools monitor Git, different scopes

### With Existing Infrastructure
- **MetalLB**: LoadBalancer IPs allocated from existing pool
- **ExternalDNS**: Automatic DNS record creation
- **Ingress**: Uses existing NGINX ingress controller
- **Storage**: Longhorn persistent volumes
- **Secrets**: Infisical integration maintained

## Monitoring & Alerting

### Argo Workflows
```bash
# View workflow history
argo list

# Check failed workflows
argo list --status Failed

# View workflow details
argo get <workflow-name>
argo logs <workflow-name>
```

### ArgoCD Applications
```bash
# Check application sync status
argocd app list
argocd app get avada-portfolio

# View application in UI
open https://argocd.xuperson.org
```

### Webhook Health
```bash
# Check EventSource status
kubectl get eventsources -n argocd
kubectl describe eventsource portfolio-git-webhook -n argocd

# Check Sensor status
kubectl get sensors -n argocd
kubectl describe sensor portfolio-ci-sensor -n argocd
```

## Troubleshooting

### Common Issues

#### 1. Webhook Not Triggering
```bash
# Check EventSource logs
kubectl logs -n argocd deployment/portfolio-git-webhook-eventsource

# Verify webhook URL accessibility
curl -X POST https://webhooks.xuperson.org/portfolio-webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

#### 2. Build Pipeline Failing
```bash
# Check workflow status
argo get @latest

# View build logs
argo logs @latest

# Common fixes:
# - Check Kaniko permissions
# - Verify registry credentials
# - Check image repository accessibility
```

#### 3. ArgoCD Sync Issues
```bash
# Check application status
argocd app get avada-portfolio

# Force refresh
argocd app refresh avada-portfolio

# Manual sync
argocd app sync avada-portfolio --force
```

### Debug Commands
```bash
# Workflow debugging
kubectl get workflows -n argocd
kubectl describe workflow <workflow-name> -n argocd

# ArgoCD debugging
kubectl get applications -n argocd
kubectl describe application avada-portfolio -n argocd

# Event debugging
kubectl get events -n argocd --sort-by='.firstTimestamp'
```

## Migration Checklist

### Pre-Migration
- [ ] ArgoCD fully deployed and healthy
- [ ] Argo Workflows controller running
- [ ] Argo Events controller running
- [ ] Infisical secrets configured
- [ ] Webhook endpoints accessible

### Migration Steps
- [ ] Deploy avada-portfolio ArgoCD application
- [ ] Deploy Argo Workflows CI/CD pipelines
- [ ] Deploy Argo Events webhook handlers
- [ ] Configure Git repository webhooks
- [ ] Test manual workflow trigger
- [ ] Test webhook-triggered workflows
- [ ] Verify application deployment and health

### Post-Migration
- [ ] Monitor workflow executions
- [ ] Validate application accessibility
- [ ] Test rollback procedures
- [ ] Update documentation and runbooks
- [ ] Train team on new operational procedures

### Deprecation (Future)
- [ ] Disable Gitea Act Runner
- [ ] Remove Tekton pipelines
- [ ] Clean up old CI/CD configurations
- [ ] Archive old build artifacts

## Performance Considerations

### Scaling
- **Argo Workflows**: Can run multiple concurrent workflows
- **ArgoCD**: Supports multiple applications and projects
- **Webhooks**: Multiple EventSources for different repositories

### Resource Usage
- **Minimal Overhead**: Replaces external CI runners with in-cluster workflows
- **Efficient Builds**: Kaniko vs Docker-in-Docker
- **Shared Resources**: Uses existing cluster infrastructure

## Security

### RBAC
- **Namespace Isolation**: Each component has minimal required permissions
- **Service Accounts**: Dedicated SAs for workflows, sensors, applications
- **Secret Management**: Infisical integration for sensitive data

### Network Security
- **Internal Communication**: Components communicate via Kubernetes services
- **External Access**: Only webhook endpoints exposed publicly
- **TLS**: All external communications use HTTPS

## Conclusion

This ArgoCD Workflows implementation provides:

✅ **Complete CI/CD Replacement**: Replaces Gitea Act Runner + Tekton
✅ **Enhanced Security**: Rootless builds, RBAC, secret management
✅ **GitOps Integration**: Works alongside existing Flux CD
✅ **Scalability**: Kubernetes-native scaling and scheduling
✅ **Observability**: Rich UI and monitoring capabilities
✅ **Flexibility**: Supports multiple repositories and deployment strategies

The system is now ready for production use with the avada-portfolio application as the first workload, with the capability to easily add more applications and repositories to the CI/CD pipeline.