# Claude Code OpenAI Wrapper

This directory contains the GitOps deployment for the Claude Code OpenAI Wrapper application, which provides an OpenAI-compatible API interface for Claude Code.

## Application Overview

The Claude Code OpenAI Wrapper is a FastAPI-based Python service that:
- Provides OpenAI-compatible chat completions API (`/v1/chat/completions`)
- Supports streaming and non-streaming responses
- Handles session management for conversation continuity
- Supports multiple Claude Code authentication methods
- Includes optional API key protection

## External Access

- **URL**: https://claude-wrapper.xuperson.org
- **Health Check**: https://claude-wrapper.xuperson.org/health
- **Models Endpoint**: https://claude-wrapper.xuperson.org/v1/models
- **Chat Completions**: https://claude-wrapper.xuperson.org/v1/chat/completions

## Required Infisical Secrets

Before deploying, create the following secrets in Infisical (prod environment, root path):

### Claude Code Authentication (Choose ONE method)

#### Option 1: Anthropic API Key
```bash
infisical secrets set CLAUDE_WRAPPER_ANTHROPIC_API_KEY="sk-ant-..." --env=prod
```

#### Option 2: OAuth (JSON file content - as mentioned by user)
```bash
infisical secrets set CLAUDE_WRAPPER_CLAUDE_OAUTH_CONFIG='{"client_id":"...","client_secret":"...","refresh_token":"..."}' --env=prod
```

#### Option 3: AWS Bedrock
```bash
infisical secrets set CLAUDE_WRAPPER_CLAUDE_CODE_USE_BEDROCK="1" --env=prod
infisical secrets set CLAUDE_WRAPPER_AWS_ACCESS_KEY_ID="AKIA..." --env=prod
infisical secrets set CLAUDE_WRAPPER_AWS_SECRET_ACCESS_KEY="..." --env=prod
infisical secrets set CLAUDE_WRAPPER_AWS_REGION="us-east-1" --env=prod
```

#### Option 4: Google Vertex AI
```bash
infisical secrets set CLAUDE_WRAPPER_CLAUDE_CODE_USE_VERTEX="1" --env=prod
infisical secrets set CLAUDE_WRAPPER_ANTHROPIC_VERTEX_PROJECT_ID="your-project-id" --env=prod
infisical secrets set CLAUDE_WRAPPER_CLOUD_ML_REGION="us-central1" --env=prod
infisical secrets set CLAUDE_WRAPPER_GOOGLE_APPLICATION_CREDENTIALS='{"type":"service_account",...}' --env=prod
```

### Optional Configuration
```bash
# Optional API key protection for wrapper endpoints
infisical secrets set CLAUDE_WRAPPER_API_KEY="your-secure-api-key" --env=prod

# Timeout and CORS settings (optional)
infisical secrets set CLAUDE_WRAPPER_MAX_TIMEOUT="600000" --env=prod
infisical secrets set CLAUDE_WRAPPER_CORS_ORIGINS='["*"]' --env=prod
```

## Usage Examples

### OpenAI SDK Compatible
```python
import openai

client = openai.OpenAI(
    base_url="https://claude-wrapper.xuperson.org/v1",
    api_key="your-api-key"  # Only if API_KEY is set in secrets
)

response = client.chat.completions.create(
    model="claude-3-5-sonnet-20241022",
    messages=[
        {"role": "user", "content": "Hello, world!"}
    ]
)
```

### cURL Example
```bash
curl -X POST "https://claude-wrapper.xuperson.org/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": false
  }'
```

## Supported Models

- claude-sonnet-4-20250514
- claude-opus-4-20250514  
- claude-3-7-sonnet-20250219
- claude-3-5-sonnet-20241022
- claude-3-5-haiku-20241022

## Resource Structure

- `claude-wrapper-namespace.yaml` - Dedicated namespace
- `claude-wrapper-infisical-secrets.yaml` - Infisical secret synchronization
- `claude-wrapper-app-configmap.yaml` - Application code and Dockerfile
- `claude-wrapper-deployment.yaml` - Kubernetes deployment
- `claude-wrapper-service.yaml` - Internal service
- `claude-wrapper-ingress.yaml` - External HTTPS access via ExternalDNS
- `kustomization.yaml` - Resource orchestration

## Monitoring

```bash
# Check pod status
kubectl get pods -n claude-wrapper

# View logs
kubectl logs -n claude-wrapper deployment/claude-wrapper

# Check secret synchronization
kubectl get infisicalsecrets -n claude-wrapper
kubectl describe infisicalsecret claude-wrapper-secrets -n claude-wrapper

# Test health endpoint
curl https://claude-wrapper.xuperson.org/health
```

## Next Steps

1. Configure Claude Code authentication secrets in Infisical
2. Flux will automatically deploy the application
3. DNS record will be created via ExternalDNS
4. Test the API endpoints once the pod is running

The application will be accessible at https://claude-wrapper.xuperson.org once deployed.