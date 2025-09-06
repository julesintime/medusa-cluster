# Coder Templates

This directory contains Coder workspace templates. These templates must be **pushed via CLI**, not mounted as ConfigMaps.

## Available Templates

### containerd-workspace
- **Description**: Basic workspace with Docker access via containerd socket mounting
- **Features**: Docker support, configurable CPU/memory, persistent home directory
- **Use case**: Development workflows requiring Docker builds and containers

### kubernetes-devcontainer  
- **Description**: Advanced workspace with devcontainer support and Kubernetes access
- **Features**: Automatic devcontainer builds, persistent workspaces, Claude Code, JetBrains, VS Code
- **Use case**: Repository-based development with automatic environment setup

## Deployment Process

**CRITICAL**: Templates must be pushed via CLI, NOT mounted as ConfigMaps.

### Prerequisites
```bash
# Export kubeconfig for Coder CLI
export KUBECONFIG=./infrastructure/ansible/config/kubeconfig.yaml

# Ensure coder-workspaces namespace exists
kubectl get namespace coder-workspaces || kubectl create namespace coder-workspaces
```

### Push Templates to Coder

```bash
# From the template directory, push each template
cd clusters/labinfra/apps/coder.xuperson.org/templates/

# Push containerd workspace template
coder templates push containerd-workspace --directory ./containerd-workspace

# Push kubernetes devcontainer template  
coder templates push kubernetes-devcontainer --directory ./kubernetes-devcontainer \
  --var namespace="coder-workspaces"
```

### Verify Templates
```bash
# List available templates
coder templates list

# View template details
coder templates show containerd-workspace
coder templates show kubernetes-devcontainer
```

## Template Structure

Each template follows this structure:
```
template-name/
├── main.tf           # Terraform configuration
├── template.yaml     # Metadata (name, description, icon, tags)
└── README.md         # Template-specific documentation (optional)
```

## Troubleshooting

### Templates not showing in UI
- **Cause**: Templates mounted as ConfigMaps (incorrect approach)
- **Solution**: Remove ConfigMap, push via CLI as shown above

### Workspace creation fails
- **Check**: Namespace `coder-workspaces` exists
- **Check**: RBAC permissions for Coder service account
- **Check**: Template variables are set correctly

### Docker socket issues
- **Check**: Host has Docker daemon running
- **Check**: `/var/run/docker.sock` accessible on nodes
- **Check**: Security context allows privileged access

## Next Steps

1. Remove any existing template ConfigMaps from Kubernetes
2. Push templates via Coder CLI as documented above
3. Test workspace creation from Coder dashboard
4. Monitor workspace pods in `coder-workspaces` namespace