# GitLab DevOps Platform

Complete GitLab installation with integrated CI/CD, registry, and runner capabilities for comprehensive DevOps workflows.

## Components

### Core GitLab
- **Webservice**: Main GitLab web interface
- **Sidekiq**: Background job processing
- **Gitaly**: Git repository storage service
- **Workhorse**: Intelligent reverse proxy for GitLab

### Databases & Storage
- **PostgreSQL**: Primary database (bundled)
- **Redis**: Caching and session storage (bundled)
- **Persistent Storage**: Git repositories and uploads

### CI/CD Infrastructure
- **GitLab Runner**: Kubernetes-based CI/CD execution
- **Container Registry**: Docker image storage and management

## Access

- **URL**: https://gitlab.xuperson.org
- **LoadBalancer IPs**:
  - GitLab: 192.168.80.104
  - PostgreSQL: 192.168.80.105
  - Redis: 192.168.80.106
- **Root Password**: Stored in Infisical as `GITLAB_ROOT_PASSWORD`

## Security

- All components run as non-root with dropped capabilities
- Read-only root filesystems where possible
- TLS termination handled by Cloudflare through ingress
- Database and service secrets managed via Infisical

## Runner Configuration

- **Executor**: Kubernetes
- **Base Image**: ubuntu:22.04
- **Security**: Non-privileged containers
- **Resources**: 1000m CPU / 2Gi memory per job
- **Registration**: Automatic via registration token

## Resources

- **CPU Requests**: ~1250m total
- **Memory Requests**: ~2.5Gi total
- **CPU Limits**: ~6500m total
- **Memory Limits**: ~12Gi total
- **Storage**: ~80Gi total (PostgreSQL: 20Gi, Redis: 8Gi, Gitaly: 50Gi)

## Dependencies

- Requires Infisical secrets: `GITLAB_ROOT_PASSWORD`, `GITLAB_POSTGRESQL_PASSWORD`, `GITLAB_POSTGRESQL_POSTGRES_PASSWORD`, `GITLAB_REDIS_PASSWORD`, `GITLAB_SHELL_SECRET`, `GITLAB_GITALY_SECRET`, `GITLAB_WORKHORSE_SECRET`, `GITLAB_RUNNER_REGISTRATION_TOKEN`
- Uses shared service token from `infisical-operator` namespace
- Requires nginx ingress controller and ExternalDNS