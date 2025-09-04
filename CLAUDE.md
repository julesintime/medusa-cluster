# CLAUDE.md

Claude Code guidance for GitOps application deployment on the K3s cluster. For detailed architecture and infrastructure setup, see README.md.

**CRITICAL:** 
**PRODUCTION READY** Don't change `core` and `secrets` without approval.
**ALWAYS** make changes via git `commit` **AND THEN** `push` to GitHub for Flux reconciliation.
**NEVER** make changes with `kubectl`, read-only commands are allowed.
**INFISICAL ONLY** All secrets must be managed through Infisical - never hardcode in manifests.

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
├── *-infisical-secrets.yaml    # Infisical secret synchronization
├── rbac.yaml                   # Service account + permissions
└── README.md                   # Application-specific docs
```

### Secrets Management

**Critical**: Always use Infisical for secrets management with shared service token.

#### Creating Secrets in Infisical
```bash
# Create application secrets in Infisical (prod environment, root path)
infisical secrets set APP_SECRET_KEY=value --env=prod
infisical secrets set APP_DATABASE_PASSWORD=$(openssl rand -base64 32) --env=prod
infisical secrets set APP_DATABASE_URL="postgresql://user:password@host:5432/db" --env=prod
```

#### InfisicalSecret Template
```yaml
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: app-secrets
  namespace: app-namespace
spec:
  hostAPI: https://app.infisical.com/api
  resyncInterval: 60
  
  authentication:
    serviceToken:
      secretsScope:
        envSlug: prod
        secretsPath: "/"
        recursive: false
      serviceTokenSecretReference:
        secretName: infisical-service-token
        secretNamespace: infisical-operator  # Shared service token
  
  managedKubeSecretReferences:
    - secretName: app-secrets
      secretNamespace: app-namespace
      creationPolicy: "Orphan"
      template:
        data:
          secret-key: "{{ .APP_SECRET_KEY.Value }}"
          db-password: "{{ .APP_DATABASE_PASSWORD.Value }}"
          database-url: "{{ .APP_DATABASE_URL.Value }}"
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

# 3. Create secrets in Infisical (prod environment, root path)
infisical secrets set NEWAPP_SECRET_KEY=value --env=prod
infisical secrets set NEWAPP_DATABASE_PASSWORD=$(openssl rand -base64 32) --env=prod

# 4. Create InfisicalSecret manifest referencing shared service token
cat > newapp-infisical-secrets.yaml << EOF
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: newapp-secrets
  namespace: newapp
spec:
  hostAPI: https://app.infisical.com/api
  authentication:
    serviceToken:
      serviceTokenSecretReference:
        secretName: infisical-service-token
        secretNamespace: infisical-operator
      secretsScope:
        envSlug: prod
        secretsPath: "/"
EOF

# 5. Update application manifests (change app name, domain, secret references)

# 6. Add to applications kustomization
echo "  - newapp.xuperson.org" >> clusters/labinfra/apps/kustomization.yaml

# 7. Commit and push - Flux deploys automatically
git add . && git commit -m "Add newapp application with Infisical secrets" && git push
```

### Complex Applications (Database + App)

For applications requiring databases, see `apps/coder.xuperson.org/` as template:

- Use separate HelmReleases for database and application
- Store database passwords in Infisical (prod environment, root path)
- Create InfisicalSecret with shared service token from `infisical-operator` namespace
- Reference synced Kubernetes secrets in HelmRelease values
- Use dedicated LoadBalancer IPs for both services

#### Database Application Pattern
```yaml
# Example HelmRelease referencing Infisical-synced secrets
spec:
  values:
    auth:
      existingSecret: "app-database-secrets"  # ← Managed by InfisicalSecret
      secretKeys:
        adminPasswordKey: "postgres-admin-password"
        userPasswordKey: "app-user-password"
```

### Security Best Practices

- **Namespaces**: Each application gets dedicated namespace
- **RBAC**: Minimal service account permissions
- **Secrets**: All passwords stored in Infisical
- **Security Context**: Non-root containers, read-only filesystems
- **Resources**: CPU/memory limits for stability

### Common Issues

**Infisical secrets**: Use `prod` environment and root path `/` - shared service token in `infisical-operator` namespace
**Service names**: Helm releases create prefixed service names (e.g., `app-postgresql` becomes `app-app-postgresql`)
**WebSocket apps**: Add NGINX proxy headers and websocket-services annotation
**DNS**: Use root domain wildcard (`*.xuperson.org`) not subdomain wildcard
**Secret sync**: InfisicalSecret syncs every 60 seconds - check with `kubectl get infisicalsecrets -A`

### Verification Commands

```bash
export KUBECONFIG=./infrastructure/ansible/config/kubeconfig.yaml

# Check deployment
kubectl get pods -n [namespace]
kubectl get svc -n [namespace]
kubectl get ingress -n [namespace]

# Verify Infisical secret synchronization
kubectl get infisicalsecrets -n [namespace]
kubectl describe infisicalsecret [secret-name] -n [namespace]
kubectl get secrets -n [namespace] | grep [app-name]

# Verify shared service token
kubectl get secret infisical-service-token -n infisical-operator

# Test external access
curl -I https://[app-name].xuperson.org

# Check DNS records (should show CNAME)
nslookup [app-name].xuperson.org

# Monitor Flux reconciliation
flux get kustomizations -A
flux get helmreleases -A
```

For infrastructure details, troubleshooting, and architecture diagrams, refer to README.md.