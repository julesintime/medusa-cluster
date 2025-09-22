# ScrapeGraphAI Deployment

This directory contains the Kubernetes manifests for deploying ScrapeGraphAI as a web service on the K3s cluster.

## Overview

ScrapeGraphAI is a Python library that revolutionizes web scraping by integrating Large Language Models (LLMs) and modular graph-based pipelines. This deployment exposes it as a FastAPI web service with support for multiple LLM providers.

## Features

- **FastAPI Web Service**: RESTful API for web scraping with AI
- **Multiple LLM Support**: OpenAI, Anthropic, Google Gemini, Mistral
- **Kubernetes Native**: Deployed with ArgoCD on K3s
- **Security**: Runs as non-root user with read-only filesystem
- **Secrets Management**: LLM API keys managed via Infisical
- **Health Checks**: Kubernetes liveness and readiness probes

## API Endpoints

- `GET /health` - Health check
- `GET /ready` - Readiness check
- `GET /models` - List available LLM models
- `POST /scrape` - Scrape a website with AI

### Example Usage

```bash
# Scrape a website
curl -X POST "https://scrapegraph-ai.xuperson.org/scrape" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "prompt": "Extract the main heading and description",
    "llm_model": "openai/gpt-3.5-turbo"
  }'
```

## Configuration

### Required Secrets in Infisical

Set these secrets in Infisical (prod environment, root path):

```bash
infisical secrets set SCRAPEGRAPH_OPENAI_API_KEY=sk-... --env=prod
infisical secrets set SCRAPEGRAPH_ANTHROPIC_API_KEY=sk-ant-... --env=prod
infisical secrets set SCRAPEGRAPH_GEMINI_API_KEY=... --env=prod
infisical secrets set SCRAPEGRAPH_MISTRAL_API_KEY=... --env=prod
```

### Available LLM Models

- **OpenAI**: `openai/gpt-3.5-turbo`, `openai/gpt-4`
- **Anthropic**: `anthropic/claude-3-sonnet-20240229`
- **Google**: `google/gemini-pro`
- **Mistral**: `mistral/mistral-medium`

## Deployment

The application is deployed via ArgoCD:

```bash
# Deploy via ArgoCD
kubectl apply -f devops/applications/scrapegraph-ai-app.yaml

# Check deployment status
kubectl get pods -n scrapegraph-ai
kubectl get svc -n scrapegraph-ai
kubectl get ingress -n scrapegraph-ai
```

## External Access

- **URL**: https://scrapegraph-ai.xuperson.org
- **DNS**: Automatically managed by ExternalDNS
- **SSL**: Handled by Cloudflare

## Monitoring

```bash
# Check application logs
kubectl logs -n scrapegraph-ai deployment/scrapegraph-ai

# Check secret synchronization
kubectl get infisicalsecrets -n scrapegraph-ai
kubectl describe infisicalsecret scrapegraph-ai-secrets -n scrapegraph-ai

# Test health endpoints
curl https://scrapegraph-ai.xuperson.org/health
curl https://scrapegraph-ai.xuperson.org/ready
```

## Security Features

- Non-root container execution (user 1000)
- Read-only root filesystem
- No privilege escalation
- Resource limits enforced
- Secrets managed via Infisical (never hardcoded)

## Architecture

```
Internet → Cloudflare → NGINX Ingress → Service → Pod (FastAPI + ScrapeGraphAI)
                                                      ↓
                                               LLM APIs (OpenAI, etc.)
```