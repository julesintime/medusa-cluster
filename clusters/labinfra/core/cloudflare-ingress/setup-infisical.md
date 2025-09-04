# Infisical GitOps Setup for Cloudflare Secrets

## Overview
This guide provides two authentication approaches for unattended Infisical operation in GitOps environments:

1. **Service Token Authentication** (Simple, less secure)
2. **Kubernetes Native Authentication** (Recommended, more secure)

## Prerequisites
- Infisical account and project created
- Cloudflare secrets stored in Infisical project
- Kubernetes cluster with Infisical operator installed

## Approach 1: Service Token Authentication (Quick Start)

### Step 1: Create Machine Identity in Infisical
1. Go to Infisical Dashboard → Project Settings → Machine Identities
2. Create a new Machine Identity with read permissions for `/cloudflare` path
3. Generate and copy the service token

### Step 2: Create Service Token Secret
```bash
# Create secret with service token (use only access token portion before last '.')
kubectl create secret generic infisical-service-token \
  --from-literal=serviceToken="YOUR_SERVICE_TOKEN_ACCESS_PORTION" \
  -n cloudflare
```

### Step 3: Update Configuration
Edit `cloudflare-sealed-secrets.yaml`:
- Replace `REPLACE_WITH_PROJECT_ID` with your Infisical project ID
- Replace `REPLACE_WITH_ACTUAL_SERVICE_TOKEN` with your service token

### Step 4: Enable in Kustomization
Uncomment the `cloudflare-sealed-secrets.yaml` line in `kustomization.yaml`

## Approach 2: Kubernetes Native Authentication (Recommended)

### Step 1: Setup Machine Identity for Kubernetes Auth
1. In Infisical Dashboard → Project Settings → Machine Identities
2. Create new Machine Identity
3. Configure **Kubernetes Auth** method:
   - **Kubernetes Host**: Your cluster API server URL
   - **Token Reviewer JWT**: Get from step 2 below
   - **Allowed Names**: `system:serviceaccount:cloudflare:infisical-auth`
   - **Allowed Audiences**: (leave default or specify custom)
   - **Bound Claims**: (optional, for additional security)

### Step 2: Get Token Reviewer JWT
```bash
# Apply the service account and RBAC from cloudflare-sealed-secrets.yaml first
kubectl apply -f cloudflare-sealed-secrets.yaml

# Wait for token to be created
kubectl wait --for=condition=ready secret/infisical-auth-token -n cloudflare

# Get the JWT token for Infisical configuration
kubectl get secret infisical-auth-token -n cloudflare -o jsonpath='{.data.token}' | base64 --decode
```

### Step 3: Update Configuration
Edit `cloudflare-sealed-secrets.yaml`:
- Replace `REPLACE_WITH_MACHINE_IDENTITY_ID` with your Machine Identity ID
- Replace `your-project-slug` with your actual project slug

### Step 4: Enable in Kustomization
Choose which InfisicalSecret to use by uncommenting the appropriate resource

## GitOps Integration Options

### Option A: Using Sealed Secrets
```bash
# Create sealed secret for service token
echo -n 'YOUR_SERVICE_TOKEN' | kubectl create secret generic infisical-service-token \
  --dry-run=client --from-file=serviceToken=/dev/stdin -o yaml | \
  kubeseal -o yaml > infisical-service-token-sealed.yaml
```

### Option B: Using External Secrets Operator
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: cloudflare
spec:
  vault:
    server: "https://your-vault.example.com"
    path: "secret"
    auth:
      kubernetes:
        mountPath: "kubernetes"
        role: "cloudflare-secrets"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: infisical-service-token
  namespace: cloudflare
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: infisical-service-token
    creationPolicy: Owner
  data:
  - secretKey: serviceToken
    remoteRef:
      key: infisical
      property: service-token
```

## Secrets to Store in Infisical

Create the following secrets in your Infisical project under the path `/cloudflare`:

### Required Cloudflare Secrets
- `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token
- `CLOUDFLARE_EMAIL`: Your Cloudflare account email (if using API key method)
- `CLOUDFLARE_API_KEY`: Your Cloudflare API key (alternative to token)
- `CLOUDFLARE_ZONE_ID`: Zone ID for your domain (optional)

### Example Secret Structure in Infisical
```
Project: your-project
Environment: prod
Path: /cloudflare/
├── CLOUDFLARE_API_TOKEN=your_api_token_here
├── CLOUDFLARE_EMAIL=your@email.com
└── CLOUDFLARE_ZONE_ID=your_zone_id
```

## Verification Steps

### Check InfisicalSecret Status
```bash
# Check if InfisicalSecret is created and syncing
kubectl get infisicalsecrets -n cloudflare
kubectl describe infisicalsecret cloudflare-secrets-service-token -n cloudflare

# Check if managed secret is created
kubectl get secrets -n cloudflare
kubectl describe secret cloudflare-secrets -n cloudflare
```

### Check Operator Logs
```bash
# Check operator logs for any issues
kubectl logs -n infisical-operator-system -l app.kubernetes.io/name=infisical-secrets-operator -f
```

### Test Secret Access
```bash
# Verify secrets are properly synced
kubectl get secret cloudflare-secrets -n cloudflare -o jsonpath='{.data}' | jq -r 'to_entries[]|"\(.key): \(.value|@base64d)"'
```

## Troubleshooting

### Common Issues

1. **"Invalid token" errors**
   - Ensure you're using only the access token portion (before last '.')
   - Verify token has correct permissions in Infisical

2. **"Authentication failed" for Kubernetes Auth**
   - Check that Token Reviewer JWT is correctly configured in Infisical
   - Verify service account has `system:auth-delegator` permissions
   - Ensure cluster API server URL is correct

3. **"Project not found" errors**
   - Verify project ID/slug is correct
   - Check that machine identity has access to the project

4. **Sync issues**
   - Check network connectivity to Infisical API
   - Verify `resyncInterval` setting
   - Check operator pod logs for detailed errors

### Debug Commands
```bash
# Get detailed InfisicalSecret status
kubectl get infisicalsecret -n cloudflare -o yaml

# Check service account token
kubectl get secret infisical-auth-token -n cloudflare -o yaml

# Test manual authentication (for debugging)
curl -X POST https://app.infisical.com/api/v1/auth/kubernetes-auth/login \
  -H "Content-Type: application/json" \
  -d '{"identityId":"YOUR_IDENTITY_ID","jwt":"YOUR_SERVICE_ACCOUNT_JWT"}'
```

## Security Best Practices

1. **Use Kubernetes Native Auth** instead of service tokens when possible
2. **Limit secret scope** to minimum required paths
3. **Use short resync intervals** for sensitive secrets
4. **Monitor access logs** in Infisical dashboard
5. **Rotate credentials regularly** if using service tokens
6. **Use RBAC** to limit which services can access secrets
