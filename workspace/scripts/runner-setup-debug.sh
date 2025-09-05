#!/bin/sh
set -e

echo "🔄 Setting up Gitea runner registration..."
echo "🔍 DEBUG: Current environment:"
echo "PATH: $PATH"
echo "Current dir: $(pwd)"
echo "User: $(id)"

echo "🔍 DEBUG: Checking kubectl binary:"
ls -la /usr/local/bin/ || echo "No /usr/local/bin/"
which kubectl || echo "kubectl not in PATH"
/usr/local/bin/kubectl version --client || echo "kubectl binary failed"

# Wait for admin API token to be available
echo "📦 Waiting for admin API token..."
echo "🔍 DEBUG: Testing kubectl access to secrets..."
/usr/local/bin/kubectl get secrets -n gitea || echo "Failed to list secrets"

until /usr/local/bin/kubectl get secret gitea-admin-api-token -n gitea >/dev/null 2>&1; do
  echo "   Admin token not ready, waiting 10 seconds..."
  echo "   DEBUG: Available secrets:"
  /usr/local/bin/kubectl get secrets -n gitea --no-headers 2>/dev/null | head -5 || echo "Failed to list secrets"
  sleep 10
done

ADMIN_TOKEN=$(/usr/local/bin/kubectl get secret gitea-admin-api-token -n gitea -o jsonpath='{.data.token}' | base64 -d)
echo "✅ Got admin API token (length: ${#ADMIN_TOKEN})"

# Get admin credentials for registration token API
ADMIN_USER=$(/usr/local/bin/kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(/usr/local/bin/kubectl get secret gitea-admin-secrets -n gitea -o jsonpath='{.data.password}' | base64 -d)

# Test Gitea API connection
echo "📡 Testing Gitea API connection..."
until curl -s -f -u "$ADMIN_USER:$ADMIN_PASS" "http://gitea-http:3000/api/v1/version" >/dev/null; do
  echo "   Gitea API not ready, waiting 5 seconds..."
  sleep 5
done
echo "✅ Gitea API is accessible"

# Get fresh registration token
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

# Clean up old runner secret and create new one
echo "🧹 Cleaning up old runner registration..."
/usr/local/bin/kubectl delete secret runner-secret -n gitea --ignore-not-found=true

/usr/local/bin/kubectl create secret generic runner-secret \
  --from-literal=token="$REGISTRATION_TOKEN" \
  --namespace=gitea

echo "💾 Fresh runner registration token stored in 'runner-secret'"
echo "🎯 Ready for clean runner registration"