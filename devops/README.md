# DevOps Directory - ArgoCD Workflows & CI/CD

This directory contains ArgoCD-managed CI/CD workflows and development applications, separate from the core infrastructure managed by FluxCD in `clusters/`.

## Directory Structure

```
devops/
├── workflows/          # Argo Workflows for CI/CD pipelines
├── applications/       # ArgoCD Application manifests
├── projects/          # Development project deployments
└── templates/         # Workflow and application templates
```

## Purpose & Separation

### FluxCD (clusters/apps/) - Infrastructure & Core Services
- Core infrastructure components
- Production-ready stable applications
- Multi-tenancy and cluster-wide resources
- Uses HelmReleases for application deployment

### ArgoCD (devops/) - CI/CD & Development
- Development and staging applications
- CI/CD pipelines and workflows using Argo Workflows
- Progressive deployments with Argo Rollouts
- Event-driven workflows with Argo Events
- Source code → Build → Deploy automation

## Workflow Strategy

1. **Source**: Clone from Gitea repositories
2. **Build**: Use BuildKit for container builds (no Docker daemon)
3. **Registry**: Push to Gitea container registry
4. **Deploy**: ArgoCD deploys to Kubernetes
5. **Promote**: Progressive deployment with Argo Rollouts

## Integration Points

- **Gitea**: Source code repositories and container registry
- **BuildKit**: Containerless builds
- **ArgoCD**: Application deployment and workflow orchestration
- **Kubernetes**: Target deployment platform
- **Infisical**: Secrets management for CI/CD credentials

## WordPress Projects via Git Subtree

WordPress sites use a special **git subtree** pattern for centralized management:

### Structure
```
devops/projects/wp-cluster/               # Git subtree (NOT submodule)
├── wp-avada-portfolio.xuperson.org/      # Individual WordPress sites
├── wp-avada-spa.xuperson.org/           # Each with complete k8s manifests
├── sites/template/                       # Template for new sites
└── README.md                            # Monorepo documentation
```

### Key Points
- **Git Subtree**: Files are **physically present** in labinfra (not references)
- **Direct Editing**: Work directly in `devops/projects/wp-cluster/`
- **ArgoCD Applications**: Each site gets own ArgoCD app pointing to subtree path
- **Dual Sync**: Changes commit to labinfra → optionally sync to wp-cluster monorepo

### Development Workflow
```bash
# Edit WordPress files directly in labinfra
vim devops/projects/wp-cluster/wp-site.xuperson.org/wp-content/themes/style.css

# Commit to labinfra (triggers ArgoCD)
git add devops/projects/wp-cluster/ && git commit -m "Update WP theme" && git push

# Optional: Sync back to monorepo
git subtree push --prefix=devops/projects/wp-cluster \
  https://github.com/julesintime/wp-cluster.git main
```

**Advantage**: Edit files → Git push → ArgoCD deploys → Live WordPress updates!