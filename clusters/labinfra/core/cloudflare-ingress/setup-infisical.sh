#!/bin/bash

# Infisical Cloudflare GitOps Setup Script
# This script helps configure Infisical secrets operator for Cloudflare in GitOps environments
# Supports both Service Token and Kubernetes Native Authentication

set -e

echo "🔧 Infisical Cloudflare GitOps Setup"
echo "====================================="

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

echo ""
echo "📋 Choose authentication method:"
echo "1. Service Token Authentication (Simple, less secure)"
echo "2. Kubernetes Native Authentication (Recommended, more secure)"
echo ""
read -p "Enter choice (1 or 2): " AUTH_CHOICE

case $AUTH_CHOICE in
    1)
        echo ""
        echo "🔑 Setting up Service Token Authentication"
        echo "=========================================="
        
        read -p "Infisical Project ID: " PROJECT_ID
        validate_not_empty "$PROJECT_ID" "Project ID"
        
        read -s -p "Infisical Service Token: " SERVICE_TOKEN
        echo ""
        validate_not_empty "$SERVICE_TOKEN" "Service Token"
        
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
  resyncInterval: 60
  projectId: "$PROJECT_ID"
  environment: prod
  secretPath: "/cloudflare"
  authentication:
    serviceToken:
      serviceTokenSecretReference:
        secretName: infisical-service-token
        secretNamespace: cloudflare
        keyName: serviceToken
  managedKubeSecretReferences:
    - secretName: cloudflare-secrets
      secretNamespace: cloudflare
      creationPolicy: "Orphan"
EOF

        echo "✅ InfisicalSecret resource created successfully"
        ;;
        
    2)
        echo ""
        echo "🔑 Setting up Kubernetes Native Authentication"
        echo "=============================================="
        
        read -p "Machine Identity ID: " IDENTITY_ID
        validate_not_empty "$IDENTITY_ID" "Machine Identity ID"
        
        read -p "Project Slug: " PROJECT_SLUG
        validate_not_empty "$PROJECT_SLUG" "Project Slug"
        
        echo ""
        echo "🔐 Creating service account and RBAC..."
        
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: infisical-auth
  namespace: cloudflare
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: infisical-auth-token
  namespace: cloudflare
  annotations:
    kubernetes.io/service-account.name: "infisical-auth"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: infisical-cloudflare-auth-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: infisical-auth
    namespace: cloudflare
EOF

        echo "✅ Service account and RBAC created successfully"
        
        echo ""
        echo "⏳ Waiting for service account token to be created..."
        kubectl wait --for=condition=ready secret/infisical-auth-token -n cloudflare --timeout=60s
        
        echo ""
        echo "🔍 Getting Token Reviewer JWT for Infisical configuration..."
        TOKEN_REVIEWER_JWT=$(kubectl get secret infisical-auth-token -n cloudflare -o jsonpath='{.data.token}' | base64 --decode)
        
        echo ""
        echo "📋 IMPORTANT: Configure this Token Reviewer JWT in Infisical:"
        echo "============================================================"
        echo "1. Go to Infisical Dashboard → Project Settings → Machine Identities"
        echo "2. Edit your Machine Identity → Kubernetes Auth"
        echo "3. Set Token Reviewer JWT to:"
        echo ""
        echo "$TOKEN_REVIEWER_JWT"
        echo ""
        echo "4. Set Allowed Names to: system:serviceaccount:cloudflare:infisical-auth"
        echo "5. Save the configuration"
        echo ""
        
        read -p "Press Enter after configuring the Token Reviewer JWT in Infisical..."
        
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
  resyncInterval: 60
  authentication:
    kubernetesAuth:
      identityId: "$IDENTITY_ID"
      serviceAccountRef:
        name: infisical-auth
        namespace: cloudflare
      secretsScope:
        projectSlug: "$PROJECT_SLUG"
        envSlug: prod
        secretsPath: "/cloudflare"
        recursive: true
  managedKubeSecretReferences:
    - secretName: cloudflare-secrets
      secretNamespace: cloudflare
      creationPolicy: "Orphan"
EOF

        echo "✅ InfisicalSecret resource created successfully"
        ;;
        
    *)
        echo "❌ Invalid choice. Please run the script again and choose 1 or 2."
        exit 1
        ;;
esac

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
echo "3. Store your Cloudflare credentials in Infisical under the path '/cloudflare':"
echo "   - CLOUDFLARE_API_TOKEN"
echo "   - CLOUDFLARE_EMAIL (if using API key)"
echo "   - CLOUDFLARE_API_KEY (alternative to token)"
echo "4. Uncomment cloudflare-sealed-secrets.yaml in kustomization.yaml when ready"

echo ""
echo "🎉 Setup complete!"
