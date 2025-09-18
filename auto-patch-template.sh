#\!/bin/bash
set -e

# Minimal automated template patcher for Coder GitHub auth
TOKEN=$(kubectl get secret coder-admin-api-token -n coder -o jsonpath='{.data.token}' | base64 -d)
CODER_URL="https://coder.xuperson.org"
TEMPLATE_ID="4ae7450e-5805-44a7-98ae-58152fbddfd4"

echo "🔧 Automated Coder Template GitHub Auth Patcher"

# Get current template
echo "📥 Getting current template..."
TEMPLATE_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$CODER_URL/api/v2/templates/$TEMPLATE_ID")
CURRENT_VERSION=$(echo "$TEMPLATE_RESPONSE" | jq -r '.active_version_id // empty')

if [ -z "$CURRENT_VERSION" ]; then
  echo "❌ Failed to get current template version"
  echo "Response: $TEMPLATE_RESPONSE"
  exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Get template files
VERSION_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$CODER_URL/api/v2/templateversions/$CURRENT_VERSION")
FILE_ID=$(echo "$VERSION_RESPONSE" | jq -r '.job.file_id // empty')

if [ -z "$FILE_ID" ]; then
  echo "❌ Failed to get file ID"
  exit 1
fi

echo "📁 Downloading template files: $FILE_ID"
curl -s -H "Authorization: Bearer $TOKEN" "$CODER_URL/api/v2/files/$FILE_ID" > template.tar.gz
tar -xzf template.tar.gz

# Check if already patched
if grep -q "ENVBUILDER_GIT_USERNAME.*github" main.tf; then
  echo "✅ Template already has GitHub auth"
  exit 0
fi

echo "🔨 Applying GitHub auth patch..."

# Create backup
cp main.tf main.tf.backup

# Apply the two-line patch
# 1. Add external auth data source
sed -i '/data "coder_workspace_owner" "me" {}/a\\n# External authentication for GitHub\ndata "coder_external_auth" "github" {\n  id = "github"\n  optional = true\n}' main.tf

# 2. Add environment variable
sed -i 's|"CODER_AGENT_URL" : replace(data\.coder_workspace\.me\.access_url, "/localhost\\|127\\\\\.0\\\\\.0\\\\\.1/", "host\.docker\.internal"),|"CODER_AGENT_URL" : replace(data.coder_workspace.me.access_url, "/localhost\\|127\\\\.0\\\\.0\\\\.1/", "host.docker.internal"),\n    "ENVBUILDER_GIT_USERNAME" : data.coder_external_auth.github.access_token,|' main.tf

# Verify patch
if grep -q "ENVBUILDER_GIT_USERNAME" main.tf && grep -q "coder_external_auth.*github" main.tf; then
  echo "✅ Patch applied successfully"
  echo "Changes:"
  diff main.tf.backup main.tf || true
else
  echo "❌ Patch verification failed"
  exit 1
fi

echo "📤 Uploading patched template..."
tar -czf patched-template.tar.gz main.tf README.md

FILE_RESPONSE=$(curl -s -X POST "$CODER_URL/api/v2/files" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/x-tar" \
  --data-binary @patched-template.tar.gz)

FILE_HASH=$(echo "$FILE_RESPONSE" | jq -r '.hash // empty')

if [ -z "$FILE_HASH" ]; then
  echo "❌ File upload failed"
  echo "Response: $FILE_RESPONSE"
  exit 1
fi

echo "📁 File uploaded: $FILE_HASH"

# Create new template version
VERSION_RESPONSE=$(curl -s -X POST "$CODER_URL/api/v2/templates/$TEMPLATE_ID/versions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"auto-github-auth-$(date +%s)\", \"message\": \"Automated GitHub authentication patch\", \"file_id\": \"$FILE_HASH\"}")

VERSION_ID=$(echo "$VERSION_RESPONSE" | jq -r '.id // empty')

if [ -z "$VERSION_ID" ]; then
  echo "❌ Template version creation failed"
  echo "Response: $VERSION_RESPONSE"
  exit 1
fi

echo "📦 Template version created: $VERSION_ID"
echo "🎉 Automated GitHub auth patch completed\!"
echo ""
echo "To activate: curl -X PATCH '$CODER_URL/api/v2/templates/$TEMPLATE_ID' -H 'Authorization: Bearer \$TOKEN' -d '{\"active_version_id\": \"$VERSION_ID\"}'"

