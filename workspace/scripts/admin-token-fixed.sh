#!/bin/sh
set -e

echo "🔄 Syncing Gitea admin API token..."

# Get admin credentials from Kubernetes secrets
ADMIN_USER=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.password}' | base64 -d)

echo "📡 Testing Gitea API connection..."
until curl -s -f -u "$ADMIN_USER:$ADMIN_PASS" "http://gitea-http:3000/api/v1/version" >/dev/null; do
  echo "   Gitea API not ready, waiting 5 seconds..."
  sleep 5
done
echo "✅ Gitea API is accessible"

# SYNC Logic: Check existing K8s secret first
if kubectl get secret gitea-admin-api-token -n gitea >/dev/null 2>&1; then
  EXISTING_TOKEN=$(kubectl get secret gitea-admin-api-token -n gitea -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || echo "")
  
  if [ ! -z "$EXISTING_TOKEN" ] && [ ${#EXISTING_TOKEN} -eq 40 ]; then
    # Test if existing token still works
    if curl -s -f -H "Authorization: token $EXISTING_TOKEN" "http://gitea-http:3000/api/v1/user" >/dev/null; then
      echo "✅ Existing admin token is valid and working (length: ${#EXISTING_TOKEN})"
      echo "🔄 SYNC: No update needed"
      exit 0
    else
      echo "⚠️  Existing token is invalid, needs update"
    fi
  else
    echo "⚠️  Invalid token in K8s secret, needs update"
  fi
else
  echo "📋 No admin token secret exists, will create"
fi

# Get list of existing tokens in Gitea
echo "📋 Checking existing tokens in Gitea..."
TOKENS_RESPONSE=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "http://gitea-http:3000/api/v1/users/$ADMIN_USER/tokens")

if [ $? -ne 0 ] || [ -z "$TOKENS_RESPONSE" ]; then
  echo "❌ Failed to fetch tokens from Gitea API"
  exit 1
fi

# Clean up existing tokens to ensure only one exists
TOKEN_IDS=$(echo "$TOKENS_RESPONSE" | grep -o '"id":[0-9]*' | sed 's/"id"://' || echo "")

if [ ! -z "$TOKEN_IDS" ]; then
  echo "🧹 Cleaning up existing tokens to ensure single token..."
  for token_id in $TOKEN_IDS; do
    echo "   Deleting token ID: $token_id"
    curl -s -X DELETE "http://gitea-http:3000/api/v1/users/$ADMIN_USER/tokens/$token_id" \
      -u "$ADMIN_USER:$ADMIN_PASS" >/dev/null
  done
fi

# Create new admin token
echo "🏗️ Creating new admin API token..."
RESPONSE=$(curl -s -X POST "http://gitea-http:3000/api/v1/users/$ADMIN_USER/tokens" \
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

# Test the new token
if ! curl -s -f -H "Authorization: token $ADMIN_TOKEN" "http://gitea-http:3000/api/v1/user" >/dev/null; then
  echo "❌ New token failed validation"
  exit 1
fi
echo "✅ Token validation successful"

# SYNC: Store/Update in Kubernetes secret
kubectl create secret generic gitea-admin-api-token \
  --from-literal=token="$ADMIN_TOKEN" \
  --namespace=gitea \
  --dry-run=client -o yaml | kubectl apply -f -

echo "💾 SYNC: Admin token synced to secret 'gitea-admin-api-token'"