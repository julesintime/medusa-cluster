#!/bin/bash
# Deploy Coder Templates
# This script pushes all templates to the Coder instance

set -e

# Check if coder CLI is available
if ! command -v coder &> /dev/null; then
    echo "❌ coder CLI not found. Please install it first."
    exit 1
fi

# Check if kubeconfig is set
if [ -z "$KUBECONFIG" ]; then
    echo "❌ KUBECONFIG not set. Please export your kubeconfig:"
    echo "   export KUBECONFIG=./infrastructure/ansible/config/kubeconfig.yaml"
    exit 1
fi

echo "🚀 Deploying Coder Templates..."

# Navigate to templates directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure coder-workspaces namespace exists
echo "📋 Checking coder-workspaces namespace..."
if ! kubectl get namespace coder-workspaces >/dev/null 2>&1; then
    echo "⚡ Creating coder-workspaces namespace..."
    kubectl create namespace coder-workspaces
fi

# Push containerd-workspace template
echo "📦 Pushing containerd-workspace template..."
if [ -d "./containerd-workspace" ]; then
    coder templates push containerd-workspace --directory ./containerd-workspace
    echo "✅ containerd-workspace template deployed"
else
    echo "⚠️  containerd-workspace directory not found"
fi

# Push kubernetes-devcontainer template
echo "📦 Pushing kubernetes-devcontainer template..."
if [ -d "./kubernetes-devcontainer" ]; then
    coder templates push kubernetes-devcontainer --directory ./kubernetes-devcontainer \
        --var namespace="coder-workspaces"
    echo "✅ kubernetes-devcontainer template deployed"
else
    echo "⚠️  kubernetes-devcontainer directory not found"
fi

echo ""
echo "🎉 Template deployment complete!"
echo ""
echo "📋 Available templates:"
coder templates list

echo ""
echo "🔗 Access Coder at: https://coder.xuperson.org"
echo "💡 Create a new workspace to test the templates!"