#!/bin/bash
# Demo script to deploy 3 sites with different tiers to prove scalability

set -e

echo "🚀 MASSIVE GITOPS DEMO: Deploying 3 WordPress sites in different tiers!"
echo

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy-site.sh"

echo "📋 Sites to deploy:"
echo "  1. test1.xuperson.org (shared tier - $1/month)"
echo "  2. test2.xuperson.org (dedicated tier - $10/month)"
echo "  3. test3.xuperson.org (enterprise tier - $100/month)"
echo

# Deploy Site 1: Shared tier
echo "🌟 Deploying Site 1: Shared Tier"
echo "─────────────────────────────────"
$DEPLOY_SCRIPT \
  --template=wordpress-shared \
  --domain=test1.xuperson.org \
  --tier=shared \
  --theme=twentytwentyfour

echo
echo "✅ Site 1 deployed!"
echo

# Deploy Site 2: Dedicated tier
echo "🌟 Deploying Site 2: Dedicated Tier"
echo "───────────────────────────────────"
$DEPLOY_SCRIPT \
  --template=wordpress-shared \
  --domain=test2.xuperson.org \
  --tier=dedicated \
  --theme=twentytwentyfour

echo
echo "✅ Site 2 deployed!"
echo

# Deploy Site 3: Enterprise tier
echo "🌟 Deploying Site 3: Enterprise Tier"
echo "────────────────────────────────────"
$DEPLOY_SCRIPT \
  --template=wordpress-shared \
  --domain=test3.xuperson.org \
  --tier=enterprise \
  --theme=twentytwentyfour

echo
echo "✅ Site 3 deployed!"
echo

echo "🎉 ALL 3 SITES DEPLOYED SUCCESSFULLY!"
echo
echo "📊 Deployment Summary:"
echo "  • test1.xuperson.org (shared)     - 64MB RAM, shared MySQL"
echo "  • test2.xuperson.org (dedicated)  - 256MB RAM, dedicated MariaDB"
echo "  • test3.xuperson.org (enterprise) - 1GB RAM, high-performance MariaDB"
echo
echo "🌐 Access URLs:"
echo "  • https://test1.xuperson.org"
echo "  • https://test2.xuperson.org"
echo "  • https://test3.xuperson.org"
echo
echo "⏰ Sites will be live once:"
echo "  1. Changes are committed and pushed to Git"
echo "  2. Flux reconciles the manifests (1-2 minutes)"
echo "  3. Pods are running and healthy"
echo "  4. DNS propagates (1-5 minutes)"
echo
echo "🔍 Monitor with:"
echo "  kubectl get pods -n test1"
echo "  kubectl get pods -n test2"
echo "  kubectl get pods -n test3"
echo
echo "💡 To deploy 100 more sites:"
echo "  for i in {4..103}; do"
echo "    $DEPLOY_SCRIPT --template=wordpress-shared --domain=test\$i.xuperson.org --tier=shared"
echo "  done"
echo
echo "🚀 PROOF: This system can scale to hundreds of sites with automation!"