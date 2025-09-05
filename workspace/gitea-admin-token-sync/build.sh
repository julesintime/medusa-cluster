#!/bin/bash

# Build and push the production image
# Replace with your registry
REGISTRY="your-registry.com"
IMAGE_NAME="gitea-token-sync"
TAG="latest"

echo "Building production image..."
docker build -f Dockerfile.prod -t $REGISTRY/$IMAGE_NAME:$TAG .

echo "Pushing image..."
docker push $REGISTRY/$IMAGE_NAME:$TAG

echo "Image ready: $REGISTRY/$IMAGE_NAME:$TAG"
