---
display_name: Kubernetes (Devcontainer) - GitOps
description: Provision envbuilder pods as Coder workspaces with GitHub external auth
icon: ../../../site/static/icon/k8s.png
maintainer_github: coder
verified: true
tags: [container, kubernetes, devcontainer, github, gitops]
---

# Kubernetes Devcontainer Template

Provision devcontainer workspaces on Kubernetes with GitHub external authentication.

## Features

✅ **GitHub External Auth** - Access private repositories  
✅ **Envbuilder Integration** - Build devcontainers from .devcontainer/devcontainer.json  
✅ **Correct Namespace** - Workspaces deploy in coder namespace  
✅ **Claude Code Ready** - Automatically installs Claude Code CLI  

## Usage

1. **Link GitHub Account**: Account → External Authentication → Link GitHub
2. **Create Workspace**: Select this template
3. **Repository**: Provide repository URL (required for envbuilder)
4. **Configure Resources**: Set CPU, memory, storage as needed

## Template Behavior

- **With Repository**: Uses envbuilder to build devcontainer
- **GitHub Repos**: Automatically authenticated via external auth
- **Workspace Location**: `/workspaces` (persistent volume)
- **Claude Code**: Pre-installed in devcontainer environments

This template is deployed and managed via GitOps automation.