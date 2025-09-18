# LiteLLM Enterprise Key Pool Setup

🚀 **Enterprise-grade LiteLLM configuration with intelligent key pool management, wildcard routing, and automatic fallbacks.**

## Overview

This setup transforms your LiteLLM deployment into a sophisticated load balancer that:

✅ **Removes hardcoded API keys** from GitOps configuration  
✅ **Manages hundreds of API keys** via JSON configuration  
✅ **Provides wildcard model routing** for OpenAI compatibility  
✅ **Automatically rotates models** when rate limits are hit  
✅ **Single virtual key** acts as load balancer for all providers  

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Single        │    │    LiteLLM       │    │  Key Pool       │
│   Virtual Key   │───▶│   Load Balancer  │───▶│  (100s of keys) │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │  Intelligent    │              │
         └──────────────│  Routing &      │──────────────┘
                        │  Fallbacks      │
                        └─────────────────┘
```

## Key Features

### 🔑 **Dynamic Key Pool Management**
- API keys stored in JSON configuration (not GitOps)
- Support for hundreds of keys per provider
- Automatic key rotation when limits hit
- Zero-downtime key updates

### 🌐 **OpenAI Compatibility**
- Any OpenAI model request routes to best available provider
- `gpt-4` → routes to `gemini-2.0-flash` (highest rate limit)
- `gpt-3.5-turbo` → intelligent routing based on availability
- `claude-3-opus` → automatic provider mapping

### ⚡ **Intelligent Fallbacks**
- Primary: `gemini-2.0-flash` (highest limits)
- Secondary: `gemini-2.0-flash-exp` (medium limits) 
- Tertiary: `gemini-1.5-pro-latest` (fallback)
- Automatic cooldown and recovery

### 📊 **Enterprise Features**
- Single virtual key for external access
- Load balancing across multiple keys
- Rate limit detection and handling
- Health checks and monitoring
- Resource limits and scaling

## Quick Start

### 1. **Add API Keys to Infisical**

```bash
# Add your Gemini API keys to Infisical (prod environment)
infisical secrets set GEMINI_KEY_1=your_first_api_key --env=prod
infisical secrets set GEMINI_KEY_2=your_second_api_key --env=prod

# Add more keys as needed (update key-pool-config.json accordingly)
infisical secrets set GEMINI_KEY_3=your_third_api_key --env=prod
# ... up to 100+ keys
```

### 2. **Configure Key Pool** 

Edit `key-pool-config.json` to add more keys:

```json
{
  "providers": {
    "gemini": {
      "keys": [
        {
          "api_key": "GEMINI_KEY_1_PLACEHOLDER",
          "key_id": "gemini-key-1",
          "rpm_limit": 15,
          "priority_models": [
            {"model": "gemini-2.0-flash", "weight": 10, "priority": 1}
          ]
        },
        {
          "api_key": "GEMINI_KEY_2_PLACEHOLDER", 
          "key_id": "gemini-key-2",
          "rpm_limit": 15,
          "priority_models": [
            {"model": "gemini-2.0-flash", "weight": 10, "priority": 1}
          ]
        }
        // Add more keys here...
      ]
    }
  }
}
```

### 3. **Deploy to Kubernetes**

```bash
# Deploy the updated configuration
git add .
git commit -m "Deploy LiteLLM Enterprise Key Pool"
git push

# Monitor the deployment
kubectl get pods -n litellm -w
kubectl logs -n litellm deployment/litellm-deployment -c key-pool-setup -f
```

### 4. **Get Your Virtual Key**

```bash
# Extract the virtual key from logs
kubectl logs -n litellm deployment/litellm-deployment -c key-pool-setup | grep "Virtual Key:"

# Or get it from the saved file
kubectl exec -n litellm deployment/litellm-deployment -c litellm -- cat /tmp/litellm-virtual-key.txt
```

## Usage Examples

### **OpenAI Compatible Requests**

```bash
# Your virtual key works with any OpenAI model name
export VIRTUAL_KEY="sk-your-generated-virtual-key"

# GPT-4 request → routes to best Gemini model
curl -X POST 'https://litellm.xuperson.org/v1/chat/completions' \
  -H "Authorization: Bearer $VIRTUAL_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# GPT-3.5 request → intelligent routing
curl -X POST 'https://litellm.xuperson.org/v1/chat/completions' \
  -H "Authorization: Bearer $VIRTUAL_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-3.5-turbo", 
    "messages": [{"role": "user", "content": "Explain quantum computing"}]
  }'

# Claude request → routes to available models
curl -X POST 'https://litellm.xuperson.org/v1/chat/completions' \
  -H "Authorization: Bearer $VIRTUAL_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "claude-3-opus",
    "messages": [{"role": "user", "content": "Write a poem"}]
  }'
```

### **Direct Model Requests**

```bash
# Directly request specific Gemini models (also load balanced)
curl -X POST 'https://litellm.xuperson.org/v1/chat/completions' \
  -H "Authorization: Bearer $VIRTUAL_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemini-2.0-flash",
    "messages": [{"role": "user", "content": "Hello Gemini!"}]
  }'
```

## How It Works

### **Intelligent Routing Logic**

1. **Request Received**: User sends request with `gpt-4` model
2. **Wildcard Matching**: LiteLLM matches `gpt-4` to `*` wildcard 
3. **Key Pool Selection**: Router selects best available key-model combination
4. **Priority Routing**: Routes to highest priority model (`gemini-2.0-flash`)
5. **Rate Limit Detection**: If rate limit hit, automatic fallback to next model
6. **Load Balancing**: Spreads load across multiple keys for same model

### **Fallback Chain Example**

```
gpt-4 request → gemini-key-1/gemini-2.0-flash (primary)
                     ↓ (rate limit hit)
                gemini-key-2/gemini-2.0-flash (same model, different key)
                     ↓ (rate limit hit)  
                gemini-key-1/gemini-2.0-flash-exp (fallback model)
                     ↓ (rate limit hit)
                gemini-key-1/gemini-1.5-pro-latest (final fallback)
```

## Scaling to 100+ Keys

### **Adding More Keys**

1. **Add keys to Infisical**:
```bash
infisical secrets set GEMINI_KEY_3=new_key --env=prod
infisical secrets set GEMINI_KEY_4=new_key --env=prod
# ... up to GEMINI_KEY_100
```

2. **Update key-pool-config.json**:
```json
{
  "providers": {
    "gemini": {
      "keys": [
        // ... existing keys ...
        {
          "api_key": "GEMINI_KEY_3_PLACEHOLDER",
          "key_id": "gemini-key-3",
          "rpm_limit": 15,
          "priority_models": [...]
        }
        // Add up to 100+ keys
      ]
    }
  }
}
```

3. **Update Infisical secrets template**:
```yaml
# Add to litellm-infisical-secrets.yaml
template:
  data:
    GEMINI_KEY_3: "{{ .GEMINI_KEY_3.Value }}"
    GEMINI_KEY_4: "{{ .GEMINI_KEY_4.Value }}"
    # ... up to 100+ keys
```

4. **Redeploy**:
```bash
git add . && git commit -m "Scale to 100+ keys" && git push
```

## Monitoring and Troubleshooting

### **Check Key Pool Status**

```bash
# Monitor bootstrap process
kubectl logs -n litellm deployment/litellm-deployment -c key-pool-setup -f

# Check LiteLLM main logs
kubectl logs -n litellm deployment/litellm-deployment -c litellm -f

# Verify models are loaded
curl -H "Authorization: Bearer $VIRTUAL_KEY" \
  https://litellm.xuperson.org/v1/models
```

### **Health Checks**

```bash
# Check LiteLLM health
curl https://litellm.xuperson.org/health

# Test virtual key
curl -X POST 'https://litellm.xuperson.org/v1/chat/completions' \
  -H "Authorization: Bearer $VIRTUAL_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model": "gpt-4", "messages": [{"role": "user", "content": "test"}]}'
```

### **Common Issues**

**Bootstrap fails**: Check Infisical secret sync
```bash
kubectl get secrets -n litellm
kubectl describe infisicalsecret litellm-secrets -n litellm
```

**No virtual key generated**: Check key pool setup logs
```bash
kubectl logs -n litellm deployment/litellm-deployment -c key-pool-setup
```

**Rate limit errors**: Keys are working, system is detecting limits correctly
```bash
# Check fallback behavior in logs
kubectl logs -n litellm deployment/litellm-deployment -c litellm | grep -i "rate\|fallback"
```

## Benefits

### **Before (Static Configuration)**
❌ Hardcoded API keys in ConfigMaps  
❌ Manual GitOps changes for new keys  
❌ No intelligent routing  
❌ No automatic fallbacks  
❌ Limited to single key per provider  

### **After (Enterprise Key Pool)**
✅ Dynamic API key management  
✅ Zero-GitOps key updates  
✅ OpenAI compatibility layer  
✅ Automatic rate limit handling  
✅ Scale to hundreds of keys  
✅ Single virtual key interface  
✅ Enterprise monitoring and health checks  

## Security Features

- **API keys never in GitOps**: All keys stored in Infisical
- **Virtual key isolation**: External access only via single virtual key
- **Rate limit protection**: Automatic fallbacks prevent abuse
- **Health monitoring**: Continuous validation of key pool status
- **Resource limits**: Containers have memory/CPU constraints

---

🎉 **Your LiteLLM is now an enterprise-grade AI gateway with intelligent key pool management!**

For support, check the logs and ensure all Infisical secrets are properly configured.