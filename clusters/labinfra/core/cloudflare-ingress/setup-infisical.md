# Infisical Setup for Cloudflare Secrets

## Prerequisites
1. Infisical account and project created
2. Cloudflare API tokens/credentials stored in Infisical

## Steps to Configure

### 1. Get Infisical Project Information
- Log into your Infisical dashboard
- Navigate to your project
- Copy the Project ID from the project settings
- Note the environment name (usually 'prod' or 'dev')

### 2. Create Service Token in Infisical
- Go to Project Settings > Service Tokens
- Create a new service token with permissions to read secrets from the cloudflare path
- Copy the generated service token

### 3. Update Configuration Files

#### Update cloudflare-sealed-secrets.yaml:
```bash
# Replace REPLACE_WITH_PROJECT_ID with your actual project ID
# Replace REPLACE_WITH_ACTUAL_SERVICE_TOKEN with your service token
```

#### Or create the secret manually:
```bash
kubectl create secret generic infisical-service-token \
  --from-literal=serviceToken="YOUR_ACTUAL_SERVICE_TOKEN" \
  -n cloudflare
```

### 4. Store Cloudflare Secrets in Infisical
Create the following secrets in your Infisical project under the path `/cloudflare`:
- `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token
- `CLOUDFLARE_EMAIL`: Your Cloudflare email (if using API key)
- `CLOUDFLARE_API_KEY`: Your Cloudflare API key (if not using token)

### 5. Enable in Kustomization
Uncomment the cloudflare-sealed-secrets.yaml line in kustomization.yaml

## Verification
```bash
# Check if InfisicalSecret is created
kubectl get infisicalsecrets -n cloudflare

# Check if the managed secret is created
kubectl get secrets -n cloudflare

# Check operator logs
kubectl logs -n infisical-operator-system -l app.kubernetes.io/name=infisical-secrets-operator
```
