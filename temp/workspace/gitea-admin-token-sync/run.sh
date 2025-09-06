#!/bin/bash

# Build the Docker image
echo "Building Docker image..."
docker build -t gitea-token-sync .

# Run the container with kubeconfig mounted
# Note: Adjust paths as needed. Assumes kubeconfig at ~/.kube/config
# For Gitea access, ensure port-forward is running: kubectl port-forward -n gitea svc/gitea-http 3000:3000
# Then, the script will use http://localhost:3000 instead of http://gitea-http:3000 for simulation

echo "Running simulation..."
docker run --rm -v ~/.kube:/root/.kube -v $(pwd):/workspace gitea-token-sync
