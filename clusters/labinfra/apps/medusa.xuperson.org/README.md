# Medusa E-commerce Backend

GitOps deployment of Medusa.js headless commerce platform using Tekton CI/CD.

## Overview

This deployment uses:
- **Official Medusa GitHub Repo**: `https://github.com/medusajs/medusa-starter-default.git`
- **Tekton Pipelines**: CI/CD builds from official source
- **PostgreSQL + Redis**: Data layer with Bitnami Helm charts
- **Infisical Secrets**: Enterprise secrets management
- **Auto-scaling**: HPA with pod disruption budget

## Architecture

```
GitHub Repo (medusajs/medusa-starter-default)
    ↓ (Tekton Pipeline)
Container Registry (registry.xuperson.org)
    ↓ (GitOps/Flux)
Kubernetes Deployment
    ↓
PostgreSQL + Redis + Medusa Backend
    ↓
External Access (medusa.xuperson.org)
```

## Required Secrets in Infisical

Set these secrets in Infisical (prod environment, root path `/`):

```bash
# Database secrets
MEDUSA_POSTGRES_ADMIN_PASSWORD=<random-password>
MEDUSA_POSTGRES_PASSWORD=<random-password>

# Redis secret
MEDUSA_REDIS_PASSWORD=<random-password>

# Application secrets
MEDUSA_DATABASE_URL="postgresql://medusa:${MEDUSA_POSTGRES_PASSWORD}@medusa-postgres-postgresql.medusa.svc.cluster.local:5432/medusa"
MEDUSA_REDIS_URL="redis://:${MEDUSA_REDIS_PASSWORD}@medusa-redis-master.medusa.svc.cluster.local:6379"
MEDUSA_JWT_SECRET=<random-jwt-secret>
MEDUSA_COOKIE_SECRET=<random-cookie-secret>
MEDUSA_ADMIN_EMAIL="admin@medusa.xuperson.org"
MEDUSA_ADMIN_PASSWORD=<admin-password>

# Registry credentials
REGISTRY_DOCKER_CONFIG_JSON=<docker-config-json>
```

## Deployment Steps

1. **Create secrets in Infisical** (see above)
2. **Apply GitOps manifests**:
   ```bash
   flux reconcile kustomization apps --with-source
   ```
3. **Trigger initial build**:
   ```bash
   kubectl create -f clusters/labinfra/apps/medusa.xuperson.org/medusa-tekton-pipelinerun.yaml
   ```
4. **Create admin user**:
   ```bash
   kubectl exec -n medusa deployment/medusa -- npx medusa user -e admin@medusa.xuperson.org -p <password>
   ```

## Access Points

- **API**: https://medusa.xuperson.org
- **Console**: https://medusa-console.xuperson.org/app
- **LoadBalancer**: http://192.168.80.115:9000

## Monitoring

```bash
# Check deployment status
kubectl get pods -n medusa

# Check pipeline runs
kubectl get pipelineruns -n medusa

# Check secrets sync
kubectl get infisicalsecrets -n medusa

# View logs
kubectl logs -n medusa deployment/medusa -f
```

## Tekton Pipeline

The pipeline:
1. **Clones** official Medusa starter repository
2. **Creates** Dockerfile if missing
3. **Builds** container image using Buildah
4. **Pushes** to registry.xuperson.org
5. **Updates** deployment automatically via GitOps

## Components

- `medusa-namespace.yaml`: Dedicated namespace
- `medusa-tekton-pipeline.yaml`: CI/CD pipeline with RBAC
- `medusa-tekton-pipelinerun.yaml`: Pipeline trigger
- `medusa-postgres-helmrelease.yaml`: PostgreSQL database
- `medusa-redis-helmrelease.yaml`: Redis cache
- `medusa-infisical-secrets.yaml`: Secrets management
- `medusa-deployment.yaml`: Application deployment + PVC
- `medusa-service.yaml`: Internal + LoadBalancer services
- `medusa-ingress.yaml`: HTTPS ingress for API + Admin
- `medusa-hpa.yaml`: Auto-scaling + PDB

## Troubleshooting

**Pipeline fails:**
```bash
kubectl logs -n medusa <pipelinerun-pod-name>
```

**Database connection issues:**
```bash
kubectl exec -n medusa deployment/medusa -- pg_isready -h medusa-postgres-postgresql -p 5432
```

**Secrets not syncing:**
```bash
kubectl describe infisicalsecret medusa-app-secrets -n medusa
```

**Check official Medusa docs**: https://docs.medusajs.com/