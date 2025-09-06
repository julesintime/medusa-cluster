#!/bin/sh
set -e

echo "🏗️ Setting up hello demo repository in Gitea (LOCAL TEST)..."

# For local testing, use localhost:3001 (port-forward)
GITEA_URL="http://localhost:3001"

# Get admin credentials
ADMIN_USER=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.password}' | base64 -d)

echo "🔑 Using admin user: $ADMIN_USER"

# Test Gitea API connection
echo "📡 Testing Gitea API connection..."
until curl -s -f -u "$ADMIN_USER:$ADMIN_PASS" "$GITEA_URL/api/v1/version" >/dev/null; do
  echo "   Gitea API not ready, waiting 5 seconds..."
  sleep 5
done
echo "✅ Gitea API is accessible"

# Get or create admin API token
echo "🔑 Getting admin API token..."
TOKENS_RESPONSE=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "$GITEA_URL/api/v1/users/$ADMIN_USER/tokens")

# Extract first token if exists
ADMIN_TOKEN=$(echo "$TOKENS_RESPONSE" | grep -o '"sha1":"[a-f0-9]*"' | head -1 | sed 's/"sha1":"//;s/"//')

# If no token exists, create one
if [ -z "$ADMIN_TOKEN" ]; then
  echo "🏗️ Creating new admin API token..."
  RESPONSE=$(curl -s -X POST "$GITEA_URL/api/v1/users/$ADMIN_USER/tokens" \
    -H "Content-Type: application/json" \
    -u "$ADMIN_USER:$ADMIN_PASS" \
    -d '{"name": "repo-automation-test", "scopes": ["all"]}')
  
  ADMIN_TOKEN=$(echo "$RESPONSE" | grep -o '"sha1":"[a-f0-9]*"' | sed 's/"sha1":"//;s/"//')
fi

if [ -z "$ADMIN_TOKEN" ] || [ ${#ADMIN_TOKEN} -ne 40 ]; then
  echo "❌ Failed to get admin token"
  echo "Response: $TOKENS_RESPONSE"
  exit 1
fi
echo "✅ Got admin API token (length: ${#ADMIN_TOKEN})"

# Check if hello repository already exists
echo "📋 Checking if hello repository exists..."
REPO_CHECK=$(curl -s -H "Authorization: token $ADMIN_TOKEN" "$GITEA_URL/api/v1/repos/$ADMIN_USER/hello" 2>/dev/null || echo "")

if echo "$REPO_CHECK" | grep -q '"name":"hello"'; then
  echo "⚠️  Repository 'hello' already exists - deleting for clean test..."
  curl -s -X DELETE "$GITEA_URL/api/v1/repos/$ADMIN_USER/hello" \
    -H "Authorization: token $ADMIN_TOKEN"
  sleep 2
fi

# Create hello repository
echo "🏗️ Creating hello repository..."
CREATE_RESPONSE=$(curl -s -X POST "$GITEA_URL/api/v1/user/repos" \
  -H "Authorization: token $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hello",
    "description": "Hello World CI/CD Demo",
    "private": false,
    "auto_init": true,
    "default_branch": "main"
  }')

if echo "$CREATE_RESPONSE" | grep -q '"name":"hello"'; then
  echo "✅ Repository 'hello' created successfully"
else
  echo "❌ Failed to create repository"
  echo "Response: $CREATE_RESPONSE"
  exit 1
fi

# Wait for repository initialization
sleep 3

echo "🎉 LOCAL TEST COMPLETED SUCCESSFULLY!"
echo "🎯 Repository created: $GITEA_URL/$ADMIN_USER/hello"
echo "🔑 Admin token available for API operations"
echo ""
echo "Next steps:"
echo "1. Repository is ready for code push"
echo "2. Can proceed with ConfigMap deployment"
echo "3. Test workflow execution after deployment"