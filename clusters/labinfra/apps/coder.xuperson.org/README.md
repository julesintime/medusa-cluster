# Coder Development Environment

Production-ready Coder deployment with PostgreSQL backend, GitHub OAuth external authentication, and GitOps template automation.

## 🎯 **SOLUTION OVERVIEW**

This deployment provides complete development environment infrastructure with:

✅ **GitHub External Authentication** - Private repository access for devcontainers  
✅ **Template Automation** - Automated template deployment via Kubernetes Jobs  
✅ **Infisical Secret Management** - All secrets managed in GitOps-friendly way  
✅ **Namespace-Correct Deployments** - Workspaces deploy in `coder` namespace  
✅ **Claude Code Integration** - Automatically installed in devcontainer environments  

## 🚀 **QUICK START**

### Deploy Infrastructure

```bash
# Add to main apps and deploy
echo "  - coder.xuperson.org" >> clusters/labinfra/apps/kustomization.yaml
git add clusters/labinfra/apps/coder.xuperson.org/
git commit -m "Deploy Coder with GitHub external auth and template automation"
git push

# Monitor deployment
export KUBECONFIG=./infrastructure/config/kubeconfig.yaml
kubectl get pods -n coder -w
```

### Automatic Template Deployment

```bash
# Template automation runs automatically - NO MANUAL STEPS REQUIRED!
# Job will:
# 1. Wait for first admin user creation
# 2. Automatically create API token via bootstrap API
# 3. Deploy template with GitHub external auth
# 4. Template ready for immediate use

# Check automation status
kubectl get jobs -n coder
kubectl logs job/coder-template-init -n coder -f

# If first user doesn't exist, create admin account:
# Visit https://coder.xuperson.org → Create first admin user
# Automation will detect and continue automatically
```

### Setup GitHub Authentication

```bash
# 1. Link your GitHub account
# Visit Account → External Authentication → Link GitHub

# 2. Create workspace
# Templates → Kubernetes (Devcontainer) - GitOps
# Repository: https://github.com/your-username/your-private-repo
```

## 🔧 **CONFIGURATION**

### GitHub OAuth App

- **Client ID**: `Ov23lip5k6y5G2Q6wWck`
- **Authorization callback URL**: `https://coder.xuperson.org/external-auth/github/callback`
- **Secrets**: Managed in Infisical (`prod` environment, root path)

### Required Infisical Secrets

```bash
# Database secrets
infisical secrets set CODER_POSTGRES_ADMIN_PASSWORD=$(openssl rand -base64 32) --env=prod
infisical secrets set CODER_USER_PASSWORD=$(openssl rand -base64 32) --env=prod
infisical secrets set CODER_DATABASE_URL="postgresql://coder:PASSWORD@coder-postgresql:5432/coder?sslmode=disable" --env=prod

# GitHub OAuth secrets  
infisical secrets set CODER_GITHUB_EXTERNAL_AUTH_CLIENT_ID="Ov23lip5k6y5G2Q6wWck" --env=prod
infisical secrets set CODER_GITHUB_EXTERNAL_AUTH_CLIENT_SECRET="6172a6c647f1dc380a6d92a6aa815059ca1fb785" --env=prod
```

## 🏗 **ARCHITECTURE**

```
Internet → Cloudflare → NGINX Ingress → Coder Service → PostgreSQL
                              ↓
                      GitHub OAuth External Auth
                              ↓
                      Template Automation Job
                              ↓
                   Workspace Pods (coder namespace)
```

### Network Configuration

- **Coder Web UI**: `https://coder.xuperson.org`
- **Workspace Access**: `*.xuperson.org` 
- **Coder Service IP**: `192.168.80.105`
- **PostgreSQL IP**: `192.168.80.103`

## 📋 **TROUBLESHOOTING**

### Template Automation Issues

```bash
# Check job status
kubectl get jobs -n coder
kubectl logs job/coder-template-init -n coder

# Check API token
kubectl get secret coder-admin-api-token -n coder -o yaml

# Restart automation
kubectl delete job coder-template-init -n coder
```

### GitHub Authentication Issues

```bash
# Check external auth secrets
kubectl get secret coder-github-external-auth-secrets -n coder
kubectl get infisicalsecrets -n coder

# Verify Coder configuration  
kubectl logs -n coder deployment/coder | grep -i external
```

### Database Connection Issues

```bash
# Check PostgreSQL status
kubectl get pods -n coder -l app.kubernetes.io/name=postgresql

# Test database connectivity
kubectl exec -n coder deployment/coder -- pg_isready -h coder-postgresql -p 5432
```

## 🔍 **VERIFICATION**

### Health Checks

```bash
# Web UI accessible
curl -I https://coder.xuperson.org

# All components running
kubectl get pods -n coder

# Secrets synced
kubectl get infisicalsecrets -n coder

# Template deployed
curl -H "Coder-Session-Token: $TOKEN" "https://coder.xuperson.org/api/v2/templates"
```

### Test Workspace Creation

1. Visit https://coder.xuperson.org
2. Create workspace with template "Kubernetes (Devcontainer) - GitOps"
3. Provide repository URL (e.g., `https://github.com/coder/envbuilder-starter-devcontainer`)
4. Verify workspace builds and GitHub authentication works

## 📁 **DIRECTORY STRUCTURE**

```
clusters/labinfra/apps/coder.xuperson.org/
├── README.md                                      # This file
├── kustomization.yaml                            # Resource orchestration
├── coder-namespace.yaml                          # Dedicated namespace
├── coder-rbac.yaml                              # Service account and permissions
├── postgresql-helmrepository.yaml               # PostgreSQL Helm repository
├── postgresql-helmrelease.yaml                  # PostgreSQL database
├── coder-helmrepository.yaml                    # Coder Helm repository
├── coder-helmrelease.yaml                       # Coder with GitHub external auth
├── coder-ingress.yaml                           # External access
├── proxy-headers.yaml                           # NGINX WebSocket support
├── coder-infisical-secrets.yaml                 # Database secrets
├── coder-github-external-auth-infisical-secrets.yaml # GitHub OAuth secrets
├── coder-template-files-configmap.yaml          # Template files
├── coder-template-init-script-configmap.yaml    # Template automation script
└── coder-template-init-job.yaml                 # Template automation job
```

---

**Ready for production use with GitHub external authentication and automated template management.**

## 🧪 **DISASTER RECOVERY TEST HISTORY**

- **2025-09-17**: Complete namespace destruction → GitOps recovery validation