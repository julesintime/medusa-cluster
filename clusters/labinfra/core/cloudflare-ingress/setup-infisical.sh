#!/bin/bash

# Infisical Cloudflare Setup Script
# This script helps configure Infisical secrets operator for Cloudflare

set -e

echo "🔧 Infisical Cloudflare Setup"
echo "=============================="

# Check if required tools are available
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }

# Function to validate input
validate_not_empty() {
    if [[ -z "$1" ]]; then
        echo "❌ Error: $2 cannot be empty"
        exit 1
    fi
}

# Check if namespace exists
if ! kubectl get namespace cloudflare >/dev/null 2>&1; then
    echo "⚠️  Cloudflare namespace not found. Creating it..."
    kubectl create namespace cloudflare
fi

# Get inputs
echo ""
echo "📋 Please provide the following information:"
echo ""

read -p "Infisical Project ID: " PROJECT_ID
validate_not_empty "$PROJECT_ID" "Project ID"

read -s -p "Infisical Service Token: " SERVICE_TOKEN
echo ""
validate_not_empty "$SERVICE_TOKEN" "Service Token"

read -p "Environment (default: prod): " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-prod}

read -p "Secret Path (default: /cloudflare): " SECRET_PATH
SECRET_PATH=${SECRET_PATH:-/cloudflare}

echo ""
echo "🔐 Creating service token secret..."
kubectl create secret generic infisical-service-token \
    --from-literal=serviceToken="$SERVICE_TOKEN" \
    -n cloudflare \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Service token secret created successfully"

echo ""
echo "📝 Creating InfisicalSecret resource..."

cat <<EOF | kubectl apply -f -
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: cloudflare-secrets
  namespace: cloudflare
spec:
  hostAPI: https://app.infisical.com/api
  projectId: "$PROJECT_ID"
  environment: $ENVIRONMENT
  secretPath: "$SECRET_PATH"
  managedSecretReference:
    secretName: cloudflare-secrets
    secretNamespace: cloudflare
  authentication:
    serviceToken:
      serviceTokenSecretReference:
        secretName: infisical-service-token
        secretNamespace: cloudflare
EOF

echo "✅ InfisicalSecret resource created successfully"

echo ""
echo "🔍 Checking status..."
sleep 5

# Check the InfisicalSecret status
echo "InfisicalSecret status:"
kubectl get infisicalsecrets -n cloudflare -o wide

echo ""
echo "Secrets in cloudflare namespace:"
kubectl get secrets -n cloudflare

echo ""
echo "📚 Next steps:"
echo "1. Verify that secrets are synced: kubectl describe infisicalsecret cloudflare-secrets -n cloudflare"
echo "2. Check operator logs if there are issues: kubectl logs -n infisical-operator-system -l app.kubernetes.io/name=infisical-secrets-operator"
echo "3. Uncomment cloudflare-sealed-secrets.yaml in kustomization.yaml when ready"

echo ""
echo "🎉 Setup complete!"
