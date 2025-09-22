# ULTRATHINK: Single Source of Truth GitHub Architecture

## 🧠 Analysis: Eliminate Confusion, Embrace Simplicity

**User Insight**: "Hybrid subtree will be very much confused!" → **ABSOLUTELY CORRECT**

## 🎯 **SIMPLIFIED ARCHITECTURE**

### **Single Source of Truth: GitHub Only**
```
GitHub (Source of Truth):
├── julesintime/labinfra          ← GitOps repository (Flux + ArgoCD)
├── julesintime/wordpress-site1   ← Project repository
├── julesintime/wordpress-site2   ← Project repository
└── julesintime/microservice-app  ← Project repository

Gitea (Mirrors Only):
├── mirror/labinfra          ← Auto-sync from GitHub
├── mirror/wordpress-site1   ← Auto-sync from GitHub
├── mirror/wordpress-site2   ← Auto-sync from GitHub
└── mirror/microservice-app  ← Auto-sync from GitHub
```

## 🔧 **Tea CLI Mirror Creation**

### **Perfect Solution Found**: `tea repos migrate --mirror`

```bash
# Create mirror repositories in Gitea (one-time setup)
tea repos migrate \
  --mirror \
  --clone-url https://github.com/julesintime/labinfra.git \
  --name labinfra \
  --mirror-interval "1h"

tea repos migrate \
  --mirror \
  --clone-url https://github.com/julesintime/wordpress-site1.git \
  --name wordpress-site1 \
  --mirror-interval "1h"
```

### **Benefits**:
- ✅ **Automatic sync** from GitHub to Gitea every hour
- ✅ **Read-only mirrors** - no confusion about source of truth
- ✅ **Internal access** via Gitea UI for teams
- ✅ **Single workflow** - all changes through GitHub

## 🌳 **Git Subtree vs Submodule Analysis**

### **Use Case**: "Edit source directly in GitOps repo but push differently"

## **WINNER: Git Subtree** 🏆

### **Git Subtree Workflow** (RECOMMENDED)
```bash
# 1. Add project as subtree in GitOps repo
git subtree add --prefix=projects/wordpress-site1 \
  https://github.com/julesintime/wordpress-site1.git main --squash

# 2. Edit source code directly in GitOps repo
vim projects/wordpress-site1/src/theme.php
vim projects/wordpress-site1/docker/Dockerfile

# 3. Commit to GitOps repo (triggers ArgoCD)
git add projects/wordpress-site1/
git commit -m "🎨 Update WordPress theme styling"
git push origin main  # → labinfra repo (GitOps)

# 4. Push changes back to project repo
git subtree push --prefix=projects/wordpress-site1 \
  https://github.com/julesintime/wordpress-site1.git main
```

### **Git Submodule Workflow** (NOT RECOMMENDED)
```bash
# 1. Add project as submodule
git submodule add https://github.com/julesintime/wordpress-site1.git projects/wordpress-site1

# 2. Edit requires entering submodule directory
cd projects/wordpress-site1/
vim src/theme.php

# 3. Two-step commit process
git add . && git commit -m "Update theme" && git push  # → project repo
cd ../..
git add projects/wordpress-site1/
git commit -m "Update wordpress-site1 reference"        # → GitOps repo
```

## 📊 **Comparison Matrix**

| Aspect | Git Subtree | Git Submodule |
|--------|-------------|---------------|
| **Direct Editing** | ✅ Edit files directly in main repo | ❌ Must enter subdirectory |
| **Single Workflow** | ✅ Edit once, push to both repos | ❌ Two-step commit process |
| **ArgoCD Compatibility** | ✅ All files physically present | ⚠️ Requires submodule init |
| **File Visibility** | ✅ Files visible in main repo | ❌ Just reference pointer |
| **Learning Curve** | ⚠️ Moderate (subtree commands) | ❌ Complex (submodule lifecycle) |
| **History** | ⚠️ Flattened history with --squash | ✅ Preserves separate history |

## 🏗️ **Repository Structure Design**

### **labinfra Repository Layout**
```
julesintime/labinfra/
├── clusters/                    ← Flux CD (Infrastructure)
│   └── labinfra/apps/
├── devops/                      ← ArgoCD (CI/CD workflows)
│   ├── workflows/
│   ├── applications/
│   └── templates/
└── projects/                    ← Project Source Code (Subtrees)
    ├── wordpress-site1/         ← git subtree from julesintime/wordpress-site1
    ├── wordpress-site2/         ← git subtree from julesintime/wordpress-site2
    └── microservice-app/        ← git subtree from julesintime/microservice-app
```

## 🔄 **Push Strategy Design**

### **Three-Tier Push Strategy**
```bash
# Tier 1: Project Changes → Both Repos
vim projects/wordpress-site1/src/app.php
git add projects/wordpress-site1/
git commit -m "🐛 Fix authentication bug"

# Push to GitOps repo (triggers ArgoCD deployment)
git push origin main  # → julesintime/labinfra

# Push to project repo (maintains project history)
git subtree push --prefix=projects/wordpress-site1 \
  https://github.com/julesintime/wordpress-site1.git main

# Tier 2: Infrastructure Changes → GitOps Only
vim clusters/labinfra/apps/new-service.yaml
git add clusters/
git commit -m "🚀 Add new service deployment"
git push origin main  # → julesintime/labinfra (Flux deploys)

# Tier 3: CI/CD Changes → GitOps Only
vim devops/workflows/new-pipeline.yaml
git add devops/
git commit -m "⚡ Add deployment pipeline"
git push origin main  # → julesintime/labinfra (ArgoCD uses)
```

## 🔍 **Webhook Architecture Simplified**

### **Single Webhook Source: GitHub**
```
GitHub Push → webhooks.xuperson.org/github/github-push → ArgoCD Workflow
```

### **No Gitea Webhooks Needed**
- Gitea mirrors are read-only
- All changes flow through GitHub
- ArgoCD pulls from GitHub directly
- Simplified webhook configuration

## 🎯 **Implementation Plan**

### **Phase 1: Create GitHub Project Repositories**
```bash
# Create dedicated repos for each project
gh repo create julesintime/wordpress-site1 --public
gh repo create julesintime/wordpress-site2 --public
gh repo create julesintime/microservice-app --public
```

### **Phase 2: Setup Gitea Mirrors**
```bash
# Create mirrors in Gitea (using tea CLI)
tea repos migrate --mirror \
  --clone-url https://github.com/julesintime/wordpress-site1.git \
  --name wordpress-site1 --mirror-interval "1h"
```

### **Phase 3: Add Projects as Subtrees**
```bash
# Add projects to labinfra as subtrees
git subtree add --prefix=projects/wordpress-site1 \
  https://github.com/julesintime/wordpress-site1.git main --squash
```

### **Phase 4: Configure ArgoCD Applications**
```yaml
# ArgoCD Application pointing to subtree
spec:
  source:
    repoURL: https://github.com/julesintime/labinfra.git
    path: projects/wordpress-site1
    targetRevision: HEAD
```

## 🏆 **Benefits of This Architecture**

### **Developer Experience**
- ✅ **Single repo editing** - all code in one place
- ✅ **Familiar git workflow** - standard add/commit/push
- ✅ **No mental overhead** - clear source of truth
- ✅ **IDE-friendly** - entire codebase in one workspace

### **Operations Excellence**
- ✅ **GitOps compliance** - all changes via git
- ✅ **Atomic deployments** - related changes in single commit
- ✅ **Clear audit trail** - git log shows all changes
- ✅ **Easy rollbacks** - standard git revert

### **Team Collaboration**
- ✅ **Single PR workflow** - review all changes together
- ✅ **Cross-project dependencies** - manage in single repo
- ✅ **Shared tooling** - common CI/CD for all projects
- ✅ **Unified documentation** - everything in one place

## ⚠️ **Considerations & Trade-offs**

### **Repository Size**
- **Risk**: Large repo with multiple projects
- **Mitigation**: Use `--squash` for subtrees, exclude media files

### **Team Access Control**
- **Risk**: All teams need access to entire repo
- **Mitigation**: Use branch protection, CODEOWNERS file

### **Build Performance**
- **Risk**: Large checkouts for CI/CD
- **Mitigation**: Sparse checkouts, selective builds

## 🚀 **Migration Strategy**

### **From Current Setup**
1. ✅ **Keep existing Flux infrastructure** - no changes needed
2. ✅ **Create GitHub project repos** - migrate from current sources
3. ✅ **Setup Gitea mirrors** - use tea CLI
4. ✅ **Add projects as subtrees** - one by one
5. ✅ **Update ArgoCD applications** - point to subtree paths

### **Gradual Migration**
- Start with one WordPress site
- Validate workflow and tooling
- Migrate additional projects incrementally
- Retire old Gitea-based workflows

## 💡 **Recommendation Summary**

**USE GIT SUBTREE** for single source of truth GitHub architecture:

1. **Create dedicated GitHub repos** for each project
2. **Setup Gitea mirrors** using `tea repos migrate --mirror`
3. **Add projects as subtrees** to labinfra repo
4. **Edit source directly** in GitOps repo
5. **Push changes** to both GitOps and project repos

This approach eliminates confusion, maintains single source of truth, and provides the direct editing workflow you requested while keeping project separation for team autonomy.

**The tea CLI mirror functionality is PERFECT** for maintaining internal Gitea access while keeping GitHub as the authoritative source.