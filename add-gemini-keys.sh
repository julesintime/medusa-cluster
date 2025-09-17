#!/bin/bash

# Script to add multiple Gemini API keys to LiteLLM for load balancing
# Usage: ./add-gemini-keys.sh "key1,key2,key3,..."

LITELLM_URL="https://litellm.xuperson.org"
MASTER_KEY="lo2v6ewnDLY2JXapRNTqdYZGs6Up2kHmzGfGbw5STr8="

if [ -z "$1" ]; then
    echo "Usage: $0 'key1,key2,key3,...'"
    echo "Example: $0 'AIzaSyDLRSBbwgfj9qtHCXzVGGl9z7BScrd5iTY,AIzaSyAnotherKey,AIzaSyThirdKey'"
    exit 1
fi

# Split comma-separated keys into array
IFS=',' read -ra KEYS <<< "$1"

echo "Adding ${#KEYS[@]} Gemini API keys for load balancing..."

# Add each key as a separate deployment with the same model_name
for i in "${!KEYS[@]}"; do
    KEY="${KEYS[$i]}"
    DEPLOYMENT_NAME="gemini-deployment-$((i+1))"
    
    echo "Adding deployment: $DEPLOYMENT_NAME"
    
    curl -X POST "${LITELLM_URL}/model/new" \
        -H "Authorization: Bearer ${MASTER_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "model_name": "gemini-pro",
            "litellm_params": {
                "model": "gemini/gemini-1.5-flash",
                "api_key": "'${KEY}'"
            },
            "model_info": {
                "id": "'${DEPLOYMENT_NAME}'"
            }
        }' || echo "Failed to add deployment $DEPLOYMENT_NAME"
    
    echo "✓ Added deployment $DEPLOYMENT_NAME"
done

echo ""
echo "🎉 Load balancing setup complete!"
echo "All requests to 'gemini-pro' will now automatically rotate between ${#KEYS[@]} API keys"

# Test the deployment
echo ""
echo "Testing load balancing..."
curl -X POST "${LITELLM_URL}/chat/completions" \
    -H "Authorization: Bearer sk-7t0P4XcTNGoIPiMP5OmrNQ" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemini-pro",
        "messages": [{"role": "user", "content": "Hello! Which API key are you using? (Test for load balancing)"}],
        "max_tokens": 50
    }'

echo ""
echo "🔧 Admin Panel: ${LITELLM_URL}/ui"
echo "📊 View models: curl -H \"Authorization: Bearer ${MASTER_KEY}\" ${LITELLM_URL}/model/info"