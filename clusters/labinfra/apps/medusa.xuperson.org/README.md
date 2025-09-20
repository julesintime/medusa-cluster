# Medusa E-commerce Platform K8s Deployment

## Overview
Complete Kubernetes manifests for deploying Medusa e-commerce platform with GitOps.

## Architecture
- **Backend**: Medusa API server with PostgreSQL
- **Storefront**: Next.js frontend application
- **Database**: PostgreSQL via Helm chart
- **Secrets**: Managed via Infisical

## Deployment Instructions

### 1. Copy to GitOps Repository
```bash
# From the GitOps repository root
cp -r /path/to/this/folder clusters/labinfra/apps/medusa.xuperson.org/
```

### 2. Add to Apps Kustomization
```bash
# Edit clusters/labinfra/apps/kustomization.yaml
echo "  - medusa.xuperson.org" >> clusters/labinfra/apps/kustomization.yaml
```

### 3. Update Image Tags
After CI/CD builds complete, update the image tags in:
- `medusa-backend-deployment.yaml`
- `medusa-storefront-deployment.yaml`

### 4. Commit and Push
```bash
git add clusters/labinfra/apps/medusa.xuperson.org/
git commit -m "Add Medusa e-commerce platform deployment"
git push
```

## URLs
- **Storefront**: https://medusa.xuperson.org
- **Backend API**: https://medusa-api.xuperson.org
- **Admin Panel**: https://medusa.xuperson.org/admin

## Secrets Configuration
All secrets are managed via Infisical in the `/medusa-fresh` folder (prod environment).

Required secrets:
- JWT_SECRET
- COOKIE_SECRET
- DATABASE_URL
- POSTGRES_PASSWORD
- ADMIN_EMAIL / ADMIN_PASSWORD
- NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY
- NEXT_PUBLIC_DEFAULT_REGION
- NEXT_PUBLIC_BASE_URL
- STORE_CORS / ADMIN_CORS

## Monitoring
```bash
# Check deployment status
kubectl get pods -n medusa
kubectl get ingress -n medusa
kubectl get infisicalsecrets -n medusa

# View logs
kubectl logs -n medusa deploy/medusa-backend
kubectl logs -n medusa deploy/medusa-storefront
```