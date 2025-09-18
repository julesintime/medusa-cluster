#\!/bin/bash
set -e

# Template patcher script - adds GitHub auth to Coder templates
CODER_URL="${CODER_URL:-https://coder.xuperson.org}"
TOKEN="${CODER_ADMIN_TOKEN:-$(kubectl get secret coder-admin-api-token -n coder -o jsonpath='{.data.token}' | base64 -d)}"
TEMPLATE_ID="${TEMPLATE_ID:-4ae7450e-5805-44a7-98ae-58152fbddfd4}"

echo "🔧 Automated Coder Template Patcher"
echo "Template ID: $TEMPLATE_ID"
echo "Coder URL: $CODER_URL"

# Get current active template
CURRENT_VERSION=$(curl -s -H "Authorization: Bearer $TOKEN" "$CODER_URL/api/v2/templates/$TEMPLATE_ID" | jq -r '.active_version_id')
echo "Current version: $CURRENT_VERSION"

# Get template files
FILE_ID=$(curl -s -H "Authorization: Bearer $TOKEN" "$CODER_URL/api/v2/templateversions/$CURRENT_VERSION" | jq -r '.job.file_id')
echo "Downloading template files: $FILE_ID"

curl -s -H "Authorization: Bearer $TOKEN" "$CODER_URL/api/v2/files/$FILE_ID" > current.tar.gz
tar -xzf current.tar.gz

# Check if already patched
if grep -q "coder_external_auth.*github" main.tf; then
  echo "✅ Template already has GitHub auth - no patch needed"
  exit 0
fi

echo "🔨 Applying GitHub auth patch..."

# Add external auth data source after existing data sources
sed -i '/data "coder_workspace_owner" "me" {}/a\\n# External authentication for GitHub\ndata "coder_external_auth" "github" {\n  id = "github"\n  optional = true\n}' main.tf

# Add ENVBUILDER_GIT_USERNAME to environment
sed -i 's|"CODER_AGENT_URL" : replace(data.coder_workspace.me.access_url, "/localhost\|127\\.0\\.0\\.1/", "host.docker.internal"),|"CODER_AGENT_URL" : replace(data.coder_workspace.me.access_url, "/localhost\|127\\.0\\.0\\.1/", "host.docker.internal"),\n    "ENVBUILDER_GIT_USERNAME" : data.coder_external_auth.github.access_token,|' main.tf

# Verify patch applied
if grep -q "ENVBUILDER_GIT_USERNAME.*github" main.tf; then
  echo "✅ Patch applied successfully"
else
  echo "❌ Patch failed"
  exit 1
fi

# Upload patched template
tar -czf patched.tar.gz main.tf README.md
FILE_HASH=$(curl -s -X POST "$CODER_URL/api/v2/files" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/x-tar" \
  --data-binary @patched.tar.gz | jq -r '.hash')

echo "Uploaded file: $FILE_HASH"

# Create new version
VERSION_ID=$(curl -s -X POST "$CODER_URL/api/v2/templates/$TEMPLATE_ID/versions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"github-auth-$(date +%s)\", \"message\": \"Auto-patch: Add GitHub authentication\", \"file_id\": \"$FILE_HASH\"}" | jq -r '.id')

if [ "$VERSION_ID" \!= "null" ] && [ -n "$VERSION_ID" ]; then
  echo "✅ Template version created: $VERSION_ID"
  
  # Wait for build
  echo "⏳ Waiting for template build..."
  for i in {1..30}; do
    STATUS=$(curl -s -H "Authorization: Bearer $TOKEN" "$CODER_URL/api/v2/templateversions/$VERSION_ID" | jq -r '.job.status')
    if [ "$STATUS" = "succeeded" ]; then
      echo "✅ Template build succeeded"
      
      # Activate new version
      curl -X PATCH "$CODER_URL/api/v2/templates/$TEMPLATE_ID" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"active_version_id\": \"$VERSION_ID\"}" > /dev/null
      
      echo "🎉 Template activated with GitHub authentication\!"
      exit 0
    elif [ "$STATUS" = "failed" ]; then
      echo "❌ Template build failed"
      exit 1
    fi
    sleep 2
  done
  echo "⏰ Template build timeout"
  exit 1
else
  echo "❌ Failed to create template version"
  exit 1
fi
