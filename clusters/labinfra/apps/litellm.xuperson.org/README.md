# LiteLLM Key Pool

**Single API call with automatic key rotation for maximum rate limits.**

## Quick Setup

### 1. Add API Keys to Infisical
```bash
# Add your Gemini API keys to Infisical (prod environment, root path)
infisical secrets set LITELLM_GEMINI_KEY_1="your-first-gemini-api-key" --env=prod --path=/
infisical secrets set LITELLM_GEMINI_KEY_2="your-second-gemini-api-key" --env=prod --path=/

# Database and master keys (already configured)
infisical secrets set LITELLM_DATABASE_URL="postgresql://postgres:wFG4VmtVO6iCqsEzqTHL1xRMeD8SltU1@postgresql:5432/litellm" --env=prod --path=/
infisical secrets set LITELLM_MASTER_KEY="$(openssl rand -base64 32)" --env=prod --path=/
infisical secrets set LITELLM_SALT_KEY="$(openssl rand -base64 32)" --env=prod --path=/
```

### 2. Deploy
```bash
# Commit and push - Flux deploys automatically
git add . && git commit -m "Deploy LiteLLM with key pool" && git push
```

### 3. Use
```bash
# Single API call rotates through all keys and models automatically
curl -H "Authorization: Bearer <LITELLM_MASTER_KEY>" \
     -H "Content-Type: application/json" \
     -d '{"model": "gpt-4", "messages": [{"role": "user", "content": "Hello!"}]}' \
     https://litellm.xuperson.org/v1/chat/completions
```

## How It Works

**Single Call** → **4 Automatic Rotations:**
1. `GEMINI_KEY_1` + `gemini-2.0-flash`
2. `GEMINI_KEY_1` + `gemini-1.5-pro`  
3. `GEMINI_KEY_2` + `gemini-2.0-flash`
4. `GEMINI_KEY_2` + `gemini-1.5-pro`

When rate limits hit, LiteLLM automatically tries the next combination.

## Endpoints

- **API**: `https://litellm.xuperson.org/v1/chat/completions`
- **Health**: `https://litellm.xuperson.org/health`
- **Models**: `https://litellm.xuperson.org/model/info`

## Files

- `litellm-configmap.yaml` - Key pool configuration (4 gpt-4 models)
- `litellm-deployment.yaml` - Single container deployment  
- `litellm-infisical-secrets.yaml` - Secret synchronization
- Other files - Standard K8s resources (namespace, ingress, etc.)

**That's it!** Minimal setup for maximum rate limit avoidance.