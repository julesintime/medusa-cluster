#!/bin/sh
set -e

echo "🔄 Setting up fresh Gitea runner registration..."

# Step 1: Wait for admin API token
echo "📦 Getting admin API token..."
if ! ADMIN_TOKEN=$(kubectl get secret gitea-admin-api-token -n gitea -o jsonpath='{.data.token}' 2>/dev/null | base64 -d); then
  echo "❌ Admin API token not found. Make sure gitea-admin-token-sync is working."
  exit 1
fi

if [ -z "$ADMIN_TOKEN" ] || [ ${#ADMIN_TOKEN} -lt 20 ]; then
  echo "❌ Invalid admin API token (length: ${#ADMIN_TOKEN})"
  exit 1
fi

echo "✅ Got admin API token (length: ${#ADMIN_TOKEN})"

# Step 2: Get admin credentials for API call
ADMIN_USER=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.password}' | base64 -d)

# Step 3: Wait for Gitea API to be ready
echo "📡 Waiting for Gitea API to be ready..."
until curl -s -f -u "$ADMIN_USER:$ADMIN_PASS" "http://gitea-http:3000/api/v1/version" >/dev/null 2>&1; do
  echo "   Gitea API not ready, waiting 5 seconds..."
  sleep 5
done
echo "✅ Gitea API is ready"

# Step 4: Get fresh registration token
echo "🎫 Getting fresh registration token..."
TOKEN_RESPONSE=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "http://gitea-http:3000/api/v1/admin/runners/registration-token")

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

# Step 5: Clean up old runner secret and create new one
echo "🧹 Cleaning up old runner registration..."
kubectl delete secret runner-secret -n gitea --ignore-not-found=true

kubectl create secret generic runner-secret \
  --from-literal=token="$REGISTRATION_TOKEN" \
  --namespace=gitea

echo "💾 Fresh runner registration token stored in 'runner-secret'"
echo "🎯 Ready for clean runner registration"