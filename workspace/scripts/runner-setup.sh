#!/bin/sh
set -e

echo "🔄 Setting up Gitea runner registration..."

# Wait for admin API token to be available
echo "📦 Waiting for admin API token..."
until kubectl get secret gitea-admin-api-token -n gitea >/dev/null 2>&1; do
  echo "   Admin token not ready, waiting 10 seconds..."
  sleep 10
done

ADMIN_TOKEN=$(kubectl get secret gitea-admin-api-token -n gitea -o jsonpath='{.data.token}' | base64 -d)
echo "✅ Got admin API token (length: ${#ADMIN_TOKEN})"

# Get admin credentials for registration token API
ADMIN_USER=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.password}' | base64 -d)

# Test Gitea API connection
echo "📡 Testing Gitea API connection..."
if ! curl -s -f -u "$ADMIN_USER:$ADMIN_PASS" "http://localhost:3000/api/v1/version" >/dev/null; then
  echo "❌ Cannot connect to Gitea API. Make sure port-forward is running: kubectl port-forward -n gitea svc/gitea-http 3000:3000"
  exit 1
fi
echo "✅ Gitea API is accessible"

# Get fresh registration token
echo "🎫 Getting fresh registration token..."
TOKEN_RESPONSE=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "http://localhost:3000/api/v1/admin/runners/registration-token")

if [ $? -ne 0 ]; then
  echo "❌ Failed to call registration token API"
  exit 1
fi

REGISTRATION_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

if [ -z "$REGISTRATION_TOKEN" ] || [ ${#REGISTRATION_TOKEN} -lt 20 ]; then
  echo "❌ Failed to get valid registration token"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Got registration token (length: ${#REGISTRATION_TOKEN})"

# Clean up old runner secret and create new one
echo "🧹 Cleaning up old runner registration..."
kubectl delete secret runner-secret -n gitea --ignore-not-found=true

kubectl create secret generic runner-secret \
  --from-literal=token="$REGISTRATION_TOKEN" \
  --namespace=gitea

echo "💾 Fresh runner registration token stored in 'runner-secret'"
echo "🎯 Ready for clean runner registration"