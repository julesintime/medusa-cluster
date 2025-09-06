#!/bin/sh
set -e

echo "🔄 Creating Gitea admin API token..."

# Get admin credentials from Kubernetes secrets
ADMIN_USER=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.password}' | base64 -d)

echo "📡 Testing Gitea API connection..."
if ! curl -s -f -u "$ADMIN_USER:$ADMIN_PASS" "http://localhost:3000/api/v1/version" >/dev/null; then
  echo "❌ Cannot connect to Gitea API. Make sure port-forward is running: kubectl port-forward -n gitea svc/gitea-http 3000:3000"
  exit 1
fi
echo "✅ Gitea API is accessible"

# Check for existing admin API token
if kubectl get secret gitea-admin-api-token -n gitea >/dev/null 2>&1; then
  EXISTING_TOKEN=$(kubectl get secret gitea-admin-api-token -n gitea -o jsonpath='{.data.token}' | base64 -d)
  if [ ! -z "$EXISTING_TOKEN" ] && [ ${#EXISTING_TOKEN} -eq 40 ]; then
    if curl -s -f -H "Authorization: token $EXISTING_TOKEN" "http://localhost:3000/api/v1/user" >/dev/null; then
      echo "✅ Valid admin token already exists (length: ${#EXISTING_TOKEN})"
      exit 0
    fi
  fi
  echo "⚠️  Existing token is invalid, will create new one"
fi

# Clean up existing tokens in Gitea
echo "🧹 Cleaning up existing API tokens..."
TOKENS_RESPONSE=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "http://localhost:3000/api/v1/users/$ADMIN_USER/tokens")
TOKEN_IDS=$(echo "$TOKENS_RESPONSE" | grep -o '"id":[0-9]*' | sed 's/"id"://' || echo "")

if [ ! -z "$TOKEN_IDS" ]; then
  echo "   Deleting existing tokens..."
  for token_id in $TOKEN_IDS; do
    curl -s -X DELETE "http://localhost:3000/api/v1/users/$ADMIN_USER/tokens/$token_id" \
      -u "$ADMIN_USER:$ADMIN_PASS" >/dev/null
  done
fi

# Create new admin token
echo "🏗️ Creating new admin API token..."
RESPONSE=$(curl -s -X POST "http://localhost:3000/api/v1/users/$ADMIN_USER/tokens" \
  -H "Content-Type: application/json" \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  -d '{
    "name": "flux-automation", 
    "scopes": ["all"]
  }')

# Extract token
ADMIN_TOKEN=$(echo "$RESPONSE" | grep -o '"sha1":"[a-f0-9]*"' | sed 's/"sha1":"//;s/"//')

if [ -z "$ADMIN_TOKEN" ] || [ ${#ADMIN_TOKEN} -ne 40 ]; then
  echo "❌ Failed to create admin token"
  echo "Response: $RESPONSE"
  exit 1
fi

echo "✅ Admin token created (length: ${#ADMIN_TOKEN})"

# Test the token
if ! curl -s -f -H "Authorization: token $ADMIN_TOKEN" "http://localhost:3000/api/v1/user" >/dev/null; then
  echo "❌ New token failed validation"
  exit 1
fi
echo "✅ Token validation successful"

# Store in Kubernetes secret
kubectl create secret generic gitea-admin-api-token \
  --from-literal=token="$ADMIN_TOKEN" \
  --namespace=gitea \
  --dry-run=client -o yaml | kubectl apply -f -

echo "💾 Admin token stored in secret 'gitea-admin-api-token'"