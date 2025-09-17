#!/bin/bash
set -e

# Test the automation job creation and execution
# This creates the job but monitors it carefully for testing

export KUBECONFIG=./infrastructure/config/kubeconfig.yaml
CODER_URL="https://coder.xuperson.org"

echo "🧪 TESTING CODER AUTOMATION JOB"
echo "==============================="
echo ""

# Step 1: Verify prerequisites
echo "✅ Step 1: Prerequisites Check"
echo "-----------------------------"

# Check if coder is deployed
if ! kubectl get deployment coder -n coder >/dev/null 2>&1; then
    echo "❌ Coder deployment not found"
    echo "   Deploy first: Add coder.xuperson.org to apps/kustomization.yaml"
    exit 1
fi

# Check if service is ready
if ! curl -s -f "$CODER_URL/healthz" >/dev/null 2>&1; then
    echo "❌ Coder service not accessible"
    exit 1
fi

echo "✅ Coder deployment ready"
echo "✅ Coder service accessible"
echo ""

# Step 2: Check for existing automation job
echo "🔍 Step 2: Automation Job Status"
echo "-------------------------------"

if kubectl get job coder-template-init -n coder >/dev/null 2>&1; then
    echo "✅ Automation job already exists"
    
    JOB_STATUS=$(kubectl get job coder-template-init -n coder -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "Unknown")
    JOB_SUCCEEDED=$(kubectl get job coder-template-init -n coder -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
    JOB_FAILED=$(kubectl get job coder-template-init -n coder -o jsonpath='{.status.failed}' 2>/dev/null || echo "0")
    
    echo "   Status: $JOB_STATUS"
    echo "   Succeeded: $JOB_SUCCEEDED"
    echo "   Failed: $JOB_FAILED"
    
    if [ "$JOB_STATUS" = "Complete" ]; then
        echo "✅ Job completed successfully"
        echo "   Checking logs from successful run..."
        kubectl logs job/coder-template-init -n coder | tail -10
    elif [ "$JOB_STATUS" = "Failed" ]; then
        echo "❌ Job failed - showing recent logs..."
        kubectl logs job/coder-template-init -n coder --tail=20
    else
        echo "⚠️  Job in progress - showing live logs..."
        kubectl logs job/coder-template-init -n coder --tail=10
    fi
else
    echo "❌ No automation job found"
    echo "   Creating job from manifest..."
    
    # Apply the job manifest
    if kubectl apply -f clusters/labinfra/apps/coder.xuperson.org/coder-template-init-job.yaml; then
        echo "✅ Automation job created"
        
        # Wait and monitor the job
        echo "⏱️  Monitoring job execution (max 5 minutes)..."
        for i in $(seq 1 30); do
            sleep 10
            
            JOB_STATUS=$(kubectl get job coder-template-init -n coder -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "Unknown")
            
            if [ "$JOB_STATUS" = "Complete" ]; then
                echo "✅ Job completed successfully!"
                break
            elif [ "$JOB_STATUS" = "Failed" ]; then
                echo "❌ Job failed!"
                break
            else
                echo "   Attempt $i/30: Job status = $JOB_STATUS"
            fi
        done
        
        # Show final logs
        echo ""
        echo "📋 Final Job Logs:"
        echo "=================="
        kubectl logs job/coder-template-init -n coder --tail=30
    else
        echo "❌ Failed to create automation job"
        exit 1
    fi
fi
echo ""

# Step 3: Verify automation results
echo "🎯 Step 3: Automation Results"
echo "----------------------------"

# Check token secret
if kubectl get secret coder-admin-api-token -n coder >/dev/null 2>&1; then
    echo "✅ Admin API token secret created"
    
    # Test token validity
    TOKEN=$(kubectl get secret coder-admin-api-token -n coder -o jsonpath='{.data.token}' | base64 -d)
    AUTH_RESPONSE=$(curl -s -H "Coder-Session-Token: $TOKEN" "$CODER_URL/api/v2/users/me" 2>/dev/null || echo "")
    
    if echo "$AUTH_RESPONSE" | grep -q '"id"'; then
        USER_EMAIL=$(echo "$AUTH_RESPONSE" | grep -o '"email":"[^"]*"' | sed 's/"email":"//;s/"//')
        echo "✅ Token is valid for user: $USER_EMAIL"
    else
        echo "❌ Token is invalid"
    fi
else
    echo "❌ No admin API token secret found"
fi

# Check templates
if [ -n "$TOKEN" ] && echo "$AUTH_RESPONSE" | grep -q '"id"'; then
    echo "   Checking templates..."
    TEMPLATES_RESPONSE=$(curl -s -H "Coder-Session-Token: $TOKEN" "$CODER_URL/api/v2/organizations/coder/templates")
    
    if echo "$TEMPLATES_RESPONSE" | grep -q '"name":"kubernetes-devcontainer"'; then
        echo "✅ kubernetes-devcontainer template created"
        
        # Get template details
        TEMPLATE_ID=$(echo "$TEMPLATES_RESPONSE" | grep -o "\"id\":\"[^\"]*\",\"created_at\":[^,]*,\"updated_at\":[^,]*,\"organization_id\":\"[^\"]*\",\"name\":\"kubernetes-devcontainer\"" | sed 's/"id":"//;s/",.*$//')
        echo "   Template ID: $TEMPLATE_ID"
    else
        echo "❌ kubernetes-devcontainer template not found"
    fi
fi
echo ""

# Step 4: Test workspace creation (dry run)
echo "🏗️  Step 4: Workspace Creation Test"
echo "----------------------------------"

if [ -n "$TOKEN" ] && [ -n "$TEMPLATE_ID" ]; then
    echo "   Testing workspace creation (dry run)..."
    
    # Get template parameters
    TEMPLATE_DETAILS=$(curl -s -H "Coder-Session-Token: $TOKEN" "$CODER_URL/api/v2/templates/$TEMPLATE_ID")
    if echo "$TEMPLATE_DETAILS" | grep -q '"active_version_id"'; then
        ACTIVE_VERSION=$(echo "$TEMPLATE_DETAILS" | grep -o '"active_version_id":"[^"]*"' | sed 's/"active_version_id":"//;s/"//')
        echo "   ✅ Active template version: $ACTIVE_VERSION"
        
        # Test dry run
        DRY_RUN_RESPONSE=$(curl -s -X POST "$CODER_URL/api/v2/templateversions/$ACTIVE_VERSION/dry-run" \
          -H "Content-Type: application/json" \
          -H "Coder-Session-Token: $TOKEN" \
          -d '{
            "workspace_name": "test-workspace",
            "rich_parameter_values": [
              {"name": "cpu", "value": "1"},
              {"name": "memory", "value": "2"},
              {"name": "workspaces_volume_size", "value": "10"},
              {"name": "repo", "value": "https://github.com/coder/envbuilder-starter-devcontainer"}
            ]
          }' 2>/dev/null || echo "")
        
        if echo "$DRY_RUN_RESPONSE" | grep -q '"job"'; then
            echo "✅ Workspace dry run successful"
        else
            echo "❌ Workspace dry run failed"
            echo "   Response: $DRY_RUN_RESPONSE"
        fi
    else
        echo "❌ No active template version found"
    fi
else
    echo "⚠️  Cannot test workspace creation - missing token or template"
fi
echo ""

# Final assessment
echo "🎯 FINAL ASSESSMENT"
echo "=================="

# Check critical components
CODER_READY=$(curl -s -f "$CODER_URL/healthz" >/dev/null 2>&1 && echo "true" || echo "false")
NAMESPACE_OK=$(kubectl get namespace coder >/dev/null 2>&1 && echo "true" || echo "false")
PODS_RUNNING=$(kubectl get pods -n coder --no-headers | grep Running | wc -l | xargs)
SECRETS_SYNCED=$(kubectl get secrets -n coder | grep -c "coder-.*-secrets" || echo "0")

echo "Coder Service: $CODER_READY"
echo "Namespace: $NAMESPACE_OK"  
echo "Running Pods: $PODS_RUNNING"
echo "Synced Secrets: $SECRETS_SYNCED"

if [ "$CODER_READY" = "true" ] && [ "$NAMESPACE_OK" = "true" ] && [ "$PODS_RUNNING" -ge 2 ]; then
    if [ "$SECRETS_SYNCED" -ge 2 ]; then
        echo ""
        echo "🎉 AUTOMATION INFRASTRUCTURE: READY"
        echo "✅ All core components operational"
        echo "✅ Secrets properly synced"
        echo ""
        echo "🚀 TO RUN AUTOMATION:"
        echo "   kubectl apply -f clusters/labinfra/apps/coder.xuperson.org/coder-template-init-job.yaml"
        echo "   kubectl logs job/coder-template-init -n coder -f"
    else
        echo ""
        echo "⚠️  AUTOMATION INFRASTRUCTURE: PARTIAL"
        echo "✅ Core components ready"
        echo "❌ Secrets need time to sync"
        echo ""
        echo "🔄 WAIT AND RETRY:"
        echo "   Infisical syncs every 60 seconds"
        echo "   kubectl get infisicalsecrets -n coder"
        echo "   Wait for all secrets to show 'True' status"
    fi
else
    echo ""
    echo "❌ AUTOMATION INFRASTRUCTURE: NOT READY"
    echo "   Core deployment issues detected"
    echo "   Check pod logs and Flux status"
fi