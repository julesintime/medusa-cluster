#!/bin/bash
set -euo pipefail

echo "🚀 Setting up Infisical CloudFlare secrets using CLI..."

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
command -v infisical >/dev/null 2>&1 || { echo "❌ infisical CLI not found"; exit 1; }

# Fetch service token from Infisical using CLI
echo "🔐 Fetching Infisical service token from secrets..."
INFISICAL_SERVICE_TOKEN=$(infisical secrets get INFISICAL_SERVICE_TOKEN --env=dev --plain --silent)

if [[ -z "$INFISICAL_SERVICE_TOKEN" ]]; then
  echo "❌ Failed to fetch INFISICAL_SERVICE_TOKEN from Infisical"
  exit 1
fi

# Ensure namespace exists
echo "📂 Ensuring cloudflare namespace exists..."
kubectl create namespace cloudflare --dry-run=client -o yaml | kubectl apply -f -

# Create the service token secret with correct key name
echo "📦 Creating infisical service token secret..."
kubectl create secret generic infisical-service-token \
  --namespace=cloudflare \
  --from-literal=infisicalToken="$INFISICAL_SERVICE_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Service token secret created successfully!"
echo "🔍 You can now apply the InfisicalSecret configuration to sync CloudFlare secrets."
echo "📋 Run: kubectl apply -f clusters/labinfra/core/cloudflare-ingress/infisical-cloudflare.yaml"
