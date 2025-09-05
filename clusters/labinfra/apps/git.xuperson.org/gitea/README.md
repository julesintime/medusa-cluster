# Gitea Deployment

Minimal single-pod Gitea deployment for git.xuperson.org.

## Architecture

- **Type**: Single-pod, non-HA deployment
- **Database**: SQLite (built-in, no external dependencies)
- **Cache/Session**: Memory-based (no external Redis/Valkey)
- **Storage**: 10Gi PVC for Git repositories and data
- **Domain**: git.xuperson.org
- **Admin**: Managed via Infisical secrets

## Required Infisical Secrets

Create these secrets in Infisical (prod environment, root path):

```bash
# Gitea admin user credentials
infisical secrets set GITEA_ADMIN_USERNAME=admin --env=prod
infisical secrets set GITEA_ADMIN_PASSWORD=$(openssl rand -base64 32) --env=prod  
infisical secrets set GITEA_ADMIN_EMAIL=admin@xuperson.org --env=prod
```

## Components

- **Namespace**: `gitea`
- **HelmRepository**: Official Gitea charts from `https://dl.gitea.com/charts/`
- **HelmRelease**: Gitea application with minimal configuration
- **InfisicalSecret**: Admin credentials synchronization
- **Admin Token Job**: One-time job to create admin API token
- **Ingress**: External HTTPS access via NGINX
- **Storage**: PVC for persistent data

## API Token Management

The deployment includes a one-time job (`gitea-admin-token-job`) that:

1. Creates an admin API token with appropriate scopes
2. Stores it in `gitea-admin-api-token` secret
3. Is idempotent (safe to run multiple times)

### Token Scopes
- `write:admin` - Admin operations
- `write:repository` - Repository management
- `write:user` - User management  
- `read:admin` - Admin read access
- `read:repository` - Repository read access

### Usage
```bash
# Check if token exists
kubectl get secret gitea-admin-api-token -n gitea

# Get token value
kubectl get secret gitea-admin-api-token -n gitea -o jsonpath='{.data.token}' | base64 -d
```

## Access

- **Web UI**: https://git.xuperson.org
- **SSH**: git.xuperson.org:22 (via SSH LoadBalancer service)
- **Admin Login**: Use credentials from Infisical secrets

## Scaling

This is a minimal single-pod setup. For production HA deployment:
- Enable PostgreSQL HA (`postgresql-ha.enabled: true`)
- Enable Valkey cluster (`valkey-cluster.enabled: true`) 
- Increase `replicaCount`
- Configure external database connection

## Monitoring

```bash
# Check deployment status
kubectl get pods -n gitea
kubectl get helmreleases -n gitea
kubectl get ingress -n gitea

# Check Infisical secret sync
kubectl get infisicalsecrets -n gitea
kubectl describe infisicalsecret gitea-secrets -n gitea
```
