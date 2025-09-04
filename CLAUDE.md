# CLAUDE.md

Claude Code guidance for GitOps application deployment on the K3s cluster. For detailed architecture and infrastructure setup, see README.md.

**CRITICAL:** 
**PRODUCTION READY** Don't change `core` and `secrets` without approval.
**ALWAYS** make changes via git `commit` **AND THEN** `push` to GitHub for Flux reconciliation.
**NEVER** make changes with `kubectl`, read-only commands are allowed.

Export your kubeconfig and use kubectl only for monitoring
```
export KUBECONFIG=infrastructure/ansible/config/kubeconfig.yaml
```

## Application Deployment Convention

All applications follow the `apps/[domain.name]/` pattern for consistent GitOps deployment.

### Standard Directory Structure
```
clusters/labinfra/apps/[app.domain.org]/
├── kustomization.yaml          # Resource orchestration
├── namespace.yaml              # Dedicated namespace
├── *-helmrelease.yaml          # Application deployment (if using Helm)
├── *-ingress.yaml              # External access + ExternalDNS
├── rbac.yaml                   # Service account + permissions
└── README.md                   # Application-specific docs
```

### Secrets Management

**Critical**: Always use Infisical for secrets management.

```bash
# Create application secrets in Infisical
infisical secrets set SECRET_KEY=value --env=prod --path=/apps/[app.domain.org]

# Reference secrets using Infisical Ansible lookup or Kubernetes integration
# See infrastructure playbooks for examples
```

### Domain & DNS Pattern

- **Primary**: `app-name.xuperson.org` 
- **Wildcard**: `*.xuperson.org` (for workspace subdomains)
- **DNS**: ExternalDNS automatically creates CNAME records
- **SSL**: Cloudflare handles certificates

### External Access Template

Every application needs an ingress for external HTTPS access:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-name
  namespace: app-namespace
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "app-name.xuperson.org"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # For WebSocket/real-time apps:
    nginx.ingress.kubernetes.io/websocket-services: "app-service"
    nginx.ingress.kubernetes.io/proxy-set-headers: "ingress-nginx/proxy-headers"
spec:
  ingressClassName: nginx
  rules:
  - host: app-name.xuperson.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### LoadBalancer Services

Use MetalLB for external access with fixed IPs:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  type: LoadBalancer
  loadBalancerIP: "192.168.80.xxx"  # Pick available IP from pool
  ports:
  - port: 80
    targetPort: 8080
```

**IP Pool**: 192.168.80.100-150 (check `kubectl get svc -A` for used IPs)

### Deployment Workflow

```bash
# 1. Create application directory
mkdir -p clusters/labinfra/apps/newapp.xuperson.org

# 2. Copy template from existing app (e.g., hello.xuperson.org for simple apps)
cp -r clusters/labinfra/apps/hello.xuperson.org/* clusters/labinfra/apps/newapp.xuperson.org/

# 3. Create secrets if needed
infisical secrets set SECRET_KEY=value --env=prod --path=/apps/newapp.xuperson.org

# 4. Update application manifests (change app name, domain, etc.)

# 5. Add to applications kustomization
echo "  - newapp.xuperson.org" >> clusters/labinfra/apps/kustomization.yaml

# 6. Commit and push - Flux deploys automatically
git add . && git commit -m "Add newapp application" && git push
```

### Complex Applications (Database + App)

For applications requiring databases, see `apps/coder.xuperson.org/` as template:

- Use separate HelmReleases for database and application
- Store database passwords in Infisical secrets
- Reference secrets in both database and application configurations
- Use dedicated LoadBalancer IPs for both services

### Security Best Practices

- **Namespaces**: Each application gets dedicated namespace
- **RBAC**: Minimal service account permissions
- **Secrets**: All passwords stored in Infisical
- **Security Context**: Non-root containers, read-only filesystems
- **Resources**: CPU/memory limits for stability

### Common Issues

**Infisical secrets**: Use proper environment and path references
**Service names**: Helm releases create prefixed service names (e.g., `app-postgresql` becomes `app-app-postgresql`)
**WebSocket apps**: Add NGINX proxy headers and websocket-services annotation
**DNS**: Use root domain wildcard (`*.xuperson.org`) not subdomain wildcard

### Verification Commands

```bash
export KUBECONFIG=./infrastructure/ansible/config/kubeconfig.yaml

# Check deployment
kubectl get pods -n [namespace]
kubectl get svc -n [namespace]
kubectl get ingress -n [namespace]

# Test external access
curl -I https://[app-name].xuperson.org

# Check DNS records (should show CNAME)
nslookup [app-name].xuperson.org
```

For infrastructure details, troubleshooting, and architecture diagrams, refer to README.md.