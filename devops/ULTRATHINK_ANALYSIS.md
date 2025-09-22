# Monorepo vs Multi-repo Architecture Analysis + Webhook Verification

## 🧠 Ultrathink Analysis Results

### 🔍 Critical Finding: Webhook Infrastructure Status

**✅ GOOD NEWS**: External webhook infrastructure exists and is partially working
- DNS resolves: webhooks.xuperson.org → Cloudflare
- Ingress exists: `git-webhook-ingress` routes `/git-webhook/*`
- Service exists: `git-webhook-eventsource-svc` with LoadBalancer IP
- Network path: GitHub → Cloudflare → Ingress → Service ✅

**❌ BLOCKER**: EventSource misconfiguration
- Current EventSource is invalid: "Invalid spec: git-webhook - git-push"
- No webhook pods running (503 Service Unavailable)
- Missing proper webhook configuration

## 🏗️ Repository Architecture Recommendation

### **HYBRID SELECTIVE APPROACH** (Optimal)

```
devops/
├── monorepo-apps/              ← Direct source code for simple apps
│   ├── wordpress-shared/       ← Shared WordPress base
│   │   ├── themes/
│   │   ├── plugins/
│   │   └── docker/
│   ├── static-sites/           ← Simple static websites
│   └── utilities/              ← Shared utilities
├── linked-apps/                ← Git subtree from Gitea repos
│   ├── wordpress-site1/        ← git subtree from git.xuperson.org/wp-site1
│   ├── wordpress-site2/        ← git subtree from git.xuperson.org/wp-site2
│   └── complex-microservice/   ← git subtree from git.xuperson.org/microservice
├── workflows/                  ← CI/CD workflow templates
├── applications/               ← ArgoCD Application manifests
└── projects/                   ← Deployment target manifests
```

### Decision Matrix
| App Type | Strategy | Reason |
|----------|----------|---------|
| **Shared WordPress Components** | Monorepo | Atomic updates across sites |
| **Site-specific WordPress** | Git Subtree | Independent development teams |
| **Simple Static Sites** | Monorepo | Minimal complexity |
| **Complex Microservices** | Git Subtree | Team autonomy + independent scaling |
| **Utilities/Shared Code** | Monorepo | Single source of truth |

## 🔗 Git Subtree Integration Strategy

### Implementation Commands
```bash
# Add Gitea repo as subtree
git subtree add --prefix=devops/linked-apps/wordpress-site1 \
  https://git.xuperson.org/julesintime/wordpress-site1.git main --squash

# Pull updates from Gitea
git subtree pull --prefix=devops/linked-apps/wordpress-site1 \
  https://git.xuperson.org/julesintime/wordpress-site1.git main --squash

# Push changes back to Gitea (optional)
git subtree push --prefix=devops/linked-apps/wordpress-site1 \
  https://git.xuperson.org/julesintime/wordpress-site1.git main
```

### Benefits
- **Team Autonomy**: Teams work in focused Gitea repos
- **Centralized CI/CD**: Single GitHub repo for ArgoCD workflows
- **Selective Sync**: Include/exclude apps as needed
- **Version Control**: Track subtree versions in main repo

## 🕸️ Webhook Architecture Design

### **DUAL-ENDPOINT STRATEGY** (Network Optimized)

#### External Webhooks (GitHub → ArgoCD)
```yaml
# Route: GitHub.com → Cloudflare → webhooks.xuperson.org → ArgoCD
POST https://webhooks.xuperson.org/git-webhook/github-push
```

#### Internal Webhooks (Gitea → ArgoCD)
```yaml
# Route: Gitea Pod → ArgoCD Pod (same cluster)
POST http://git-webhook-eventsource-svc.argocd.svc.cluster.local:12000/gitea-push
```

### Network Efficiency
- **External**: GitHub webhooks traverse internet (necessary)
- **Internal**: Gitea webhooks stay within cluster (optimal)
- **Security**: Internal webhooks avoid external exposure
- **Performance**: Reduced latency for internal events

## 🚀 Implementation Plan

### Phase 1: Fix Webhook Infrastructure (CRITICAL)
```bash
# 1. Fix EventSource configuration
kubectl delete eventsource git-webhook -n argocd

# 2. Apply corrected webhook configuration
kubectl apply -f devops/workflows/gitea-webhook-eventsource.yaml

# 3. Verify webhook pods start
kubectl get pods -n argocd | grep git-webhook

# 4. Test webhook endpoint
curl -X POST https://webhooks.xuperson.org/git-webhook/github-push \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/main","repository":{"full_name":"julesintime/labinfra"}}'
```

### Phase 2: Monorepo Structure
```bash
# Create monorepo apps structure
mkdir -p devops/monorepo-apps/{wordpress-shared,static-sites,utilities}

# Move simple apps to monorepo
cp -r clusters/labinfra/apps/hello.xuperson.org/source devops/monorepo-apps/hello-app/
```

### Phase 3: Git Subtree Integration
```bash
# Add complex WordPress sites as subtrees
git subtree add --prefix=devops/linked-apps/wp-portfolio \
  https://git.xuperson.org/julesintime/wp-portfolio.git main --squash

git subtree add --prefix=devops/linked-apps/wp-ecommerce \
  https://git.xuperson.org/julesintime/wp-ecommerce.git main --squash
```

### Phase 4: CI/CD Workflows
```bash
# Deploy workflow templates
kubectl apply -f devops/workflows/ci-cd-workflow-template.yaml

# Create application manifests
kubectl apply -f devops/applications/
```

## 🎯 WordPress-Specific Strategy

### Shared Components (Monorepo)
```
devops/monorepo-apps/wordpress-shared/
├── base-theme/           ← Custom base theme
├── shared-plugins/       ← Common plugins
├── docker/
│   ├── Dockerfile        ← WordPress + PHP optimizations
│   └── php.ini
└── config/
    ├── wp-config-base.php
    └── nginx.conf
```

### Site-Specific (Git Subtree)
```
devops/linked-apps/
├── wp-portfolio/         ← Subtree from git.xuperson.org
│   ├── custom-theme/
│   ├── site-plugins/
│   └── content/
└── wp-ecommerce/         ← Subtree from git.xuperson.org
    ├── woocommerce-customizations/
    ├── payment-plugins/
    └── product-data/
```

## 📊 Benefits Analysis

### vs Current Gitea Runner + Tekton
| Aspect | Current | Proposed ArgoCD |
|--------|---------|----------------|
| **Repository Model** | Single repo per app | Hybrid: monorepo + subtrees |
| **CI/CD Engine** | Gitea Actions + Tekton | Argo Workflows |
| **UI/Monitoring** | Limited dashboards | Rich ArgoCD interface |
| **Team Workflow** | Isolated repos | Flexible: team choice |
| **WordPress Management** | Scattered sites | Shared components + customization |
| **Webhook Complexity** | Single source (Gitea) | Dual: external + internal |
| **Network Efficiency** | Internal only | Optimized routing |

## ⚠️ Risk Assessment

### High Risk
- **Webhook misconfiguration**: Currently blocking (fixable)
- **Git subtree complexity**: Team training required
- **Large repo size**: Monitor with multiple WordPress sites

### Medium Risk
- **Subtree sync conflicts**: Needs clear procedures
- **Team coordination**: Multiple apps in single repo
- **Build time increases**: Mitigated by selective builds

### Low Risk
- **External webhook security**: Cloudflare protection
- **Network dependencies**: Proven infrastructure

## 🏁 Next Actions (Priority Order)

1. **[CRITICAL]** Fix EventSource webhook configuration
2. **[HIGH]** Test external webhook connectivity
3. **[MEDIUM]** Implement monorepo structure for simple apps
4. **[MEDIUM]** Add first WordPress site via git subtree
5. **[LOW]** Optimize CI/CD workflows for performance

## 💡 Recommendation Summary

**Use the HYBRID SELECTIVE approach** with:
- **Monorepo** for shared components and simple apps
- **Git subtree** for complex WordPress sites and team-owned apps
- **Dual webhook endpoints** for optimal network routing
- **Phase implementation** starting with webhook fixes

This provides maximum flexibility while leveraging the benefits of both monorepo and multi-repo approaches, specifically optimized for your WordPress-heavy use case and existing infrastructure.