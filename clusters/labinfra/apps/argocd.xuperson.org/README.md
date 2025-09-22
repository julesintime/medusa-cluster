# ArgoCD GitOps Platform

ArgoCD deployment with complete ecosystem including workflows, events, and rollouts for comprehensive GitOps automation.

## Components

### Core ArgoCD
- **ArgoCD Server**: GitOps dashboard and API server
- **Application Controller**: Manages application lifecycle
- **Repository Server**: Handles manifest generation
- **ApplicationSet Controller**: Multi-cluster application management
- **Notifications Controller**: Event notifications and alerting
- **Redis**: Caching and session storage

### Ecosystem Components
- **Argo Workflows**: Kubernetes-native workflow engine
- **Argo Events**: Event-driven workflow automation
- **Argo Rollouts**: Progressive delivery for deployments

## Access

- **URL**: https://argocd.xuperson.org
- **LoadBalancer IP**: 192.168.80.102
- **Admin Username**: Stored in Infisical as `ARGOCD_ADMIN_USERNAME`
- **Admin Password**: Stored in Infisical as `ARGOCD_ADMIN_PASSWORD`

## Security

- All components run as non-root with read-only root filesystem
- Dropped Linux capabilities for enhanced security
- TLS termination handled by Cloudflare through ingress
- Admin credentials managed via Infisical

## Resources

- **CPU Requests**: ~700m total
- **Memory Requests**: ~1.5Gi total
- **CPU Limits**: ~3000m total
- **Memory Limits**: ~6Gi total

## Dependencies

- Requires Infisical secrets: `ARGOCD_ADMIN_USERNAME`, `ARGOCD_ADMIN_PASSWORD`, `ARGOCD_SERVER_SECRET_KEY`
- Uses shared service token from `infisical-operator` namespace
- Requires nginx ingress controller and ExternalDNS