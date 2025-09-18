# Kubernetes Devcontainer Template with GitHub Authentication

This template builds development environments using envbuilder on Kubernetes with GitHub external authentication support.

## Features

- **GitHub Authentication**: Automatically uses GitHub access tokens for private repository access
- **Envbuilder Integration**: Builds devcontainers from repositories using envbuilder
- **Kubernetes Native**: Runs on Kubernetes with proper resource management
- **Caching Support**: Optional container registry caching for faster builds

## GitHub Authentication

When GitHub external authentication is configured and the user is authenticated, the template will automatically:
- Set `ENVBUILDER_GIT_USERNAME` to the GitHub access token
- Display authentication status in workspace metadata
- Allow access to private GitHub repositories