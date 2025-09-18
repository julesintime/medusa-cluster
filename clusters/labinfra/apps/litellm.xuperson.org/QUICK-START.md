# 🚀 LiteLLM Enterprise Key Pool - Quick Start

## Three Simple Commands

### 1. **Initialize Secrets** 🔐
```bash
./deploy-enterprise-key-pool.sh --init-keys
```
**What it does:**
- 📁 Stores secrets in `/litellm` folder in Infisical
- 🔍 Uses your existing `GEMINI_API_KEY` for both `GEMINI_KEY_1` and `GEMINI_KEY_2`
- 🛡️ Auto-generates `LITELLM_MASTER_KEY` and `LITELLM_SALT_KEY`
- 💾 Preserves existing `DATABASE_URL`

### 2. **Deploy Key Pool** 🚀
```bash
./deploy-enterprise-key-pool.sh --deploy
```
**What it does:**
- ✅ Deploys all Kubernetes resources
- ⏳ Waits for pods to be ready
- 🔧 Sets up dynamic key pool via API
- 🔑 Generates single virtual key for external access

### 3. **Validate Setup** ✅
```bash
./deploy-enterprise-key-pool.sh --validate
```
**What it does:**
- 🔍 Checks deployment status
- 🏥 Tests health endpoint
- 🌟 **Tests wildcard routing**: `gpt-4` → `gemini-2.0-flash`
- 📝 Shows API response and success/failure

---

## Key Features

✅ **Infisical Folder Organization**: Secrets stored in `/litellm` folder  
✅ **Uses Current Keys**: Automatically detects and reuses existing `GEMINI_API_KEY`  
✅ **Wildcard Routing**: `gpt-4`, `claude-3-opus` → routes to best Gemini model  
✅ **Intelligent Fallbacks**: Auto-rotation when rate limits hit  
✅ **Single Virtual Key**: One key to access entire key pool  
✅ **Non-Stress Validation**: Single API call test (not load testing)  

---

## Expected Output

### After `--init-keys`:
```
✅ All secrets configured in Infisical /litellm folder!

📋 Secrets created:
   • LITELLM_MASTER_KEY (auto-generated)
   • LITELLM_SALT_KEY (auto-generated)  
   • DATABASE_URL (from existing or default)
   • GEMINI_KEY_1 (from your existing key)
   • GEMINI_KEY_2 (from your existing key)
   • GEMINI_API_KEY (legacy compatibility)
```

### After `--deploy`:
```
🎉 Deployment completed successfully!

🔑 Virtual Key: sk-abc123def456...
📊 Total Models: 6
🌐 API Endpoint: https://litellm.xuperson.org
```

### After `--validate`:
```
🎉 VALIDATION SUCCESSFUL! 🎉

🔑 Virtual Key: sk-abc123def456...
🌐 API Endpoint: https://litellm.xuperson.org
✅ HTTP Status: 200

📝 API Response:
{
  "choices": [
    {
      "message": {
        "content": "Key pool working!",
        "role": "assistant"
      }
    }
  ]
}

🎊 Your LiteLLM Enterprise Key Pool is working perfectly!
```

---

## Troubleshooting

### **Get Help**
```bash
./deploy-enterprise-key-pool.sh --help
```

### **Check Logs**
```bash
# Key pool setup logs
kubectl logs -n litellm deployment/litellm-deployment -c key-pool-setup -f

# Main LiteLLM logs
kubectl logs -n litellm deployment/litellm-deployment -c litellm -f
```

### **Manual Test**
```bash
# Get virtual key
VIRTUAL_KEY=$(kubectl logs -n litellm deployment/litellm-deployment -c key-pool-setup | grep "Virtual Key:" | tail -1 | awk '{print $NF}')

# Test wildcard routing
curl -X POST 'https://litellm.xuperson.org/v1/chat/completions' \
  -H "Authorization: Bearer $VIRTUAL_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model": "gpt-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```

---

## Next Steps

After successful validation:

1. **Use your virtual key** with any OpenAI-compatible application
2. **Add more keys** to scale: `infisical secrets set GEMINI_KEY_3=new_key --env=prod --path=/litellm`
3. **Monitor usage** via kubectl logs
4. **Scale horizontally** by updating `key-pool-config.json`

🎉 **Your LiteLLM is now an enterprise AI gateway!**