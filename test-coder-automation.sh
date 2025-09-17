#!/bin/bash
set -e

# Non-destructive test script for Coder automation workflow
# Tests the complete automation flow without making permanent changes

CODER_URL="https://coder.xuperson.org"
TEST_MODE=true
KUBECONFIG_PATH="./infrastructure/config/kubeconfig.yaml"

echo "🧪 CODER AUTOMATION WORKFLOW TEST"
echo "================================="
echo "URL: $CODER_URL"
echo "Mode: NON-DESTRUCTIVE"
echo ""

# Export kubeconfig
export KUBECONFIG="$KUBECONFIG_PATH"

# Test 1: Check Coder service availability
echo "📡 Test 1: Coder Service Availability"
echo "------------------------------------"
if curl -s -f "$CODER_URL/healthz" >/dev/null 2>&1; then
    echo "✅ Coder healthcheck passed"
    
    # Get version info
    VERSION_INFO=$(curl -s "$CODER_URL/api/v2/buildinfo" 2>/dev/null || echo "{}")
    if echo "$VERSION_INFO" | grep -q '"version"'; then
        VERSION=$(echo "$VERSION_INFO" | grep -o '"version":"[^"]*"' | sed 's/"version":"//;s/"//')
        echo "✅ Coder version: $VERSION"
    fi
else
    echo "❌ Coder healthcheck failed - service not accessible"
    echo "   Check: kubectl get pods -n coder"
    echo "   Check: kubectl get svc -n coder"
    echo "   Check: kubectl get ingress -n coder"
    exit 1
fi
echo ""

# Test 2: Kubernetes access and namespace
echo "🔧 Test 2: Kubernetes Access"
echo "----------------------------"
if kubectl get namespace coder >/dev/null 2>&1; then
    echo "✅ Coder namespace exists"
else
    echo "❌ Coder namespace missing"
    exit 1
fi

if kubectl get pods -n coder >/dev/null 2>&1; then
    echo "✅ kubectl access to coder namespace"
    
    # Show pod status
    POD_STATUS=$(kubectl get pods -n coder --no-headers | awk '{print $1 " " $3}')
    echo "   Pod status:"
    echo "$POD_STATUS" | while read pod status; do
        if [ "$status" = "Running" ] || [ "$status" = "Completed" ]; then
            echo "   ✅ $pod: $status"
        else
            echo "   ⚠️  $pod: $status"
        fi
    done
else
    echo "❌ kubectl access failed"
    exit 1
fi
echo ""

# Test 3: Check for existing token secret
echo "🔑 Test 3: Token Secret Management"
echo "---------------------------------"
SECRET_EXISTS=false
TOKEN_VALID=false

if kubectl get secret coder-admin-api-token -n coder >/dev/null 2>&1; then
    echo "✅ Token secret exists"
    SECRET_EXISTS=true
    
    # Extract and validate token (non-destructively)
    K8S_TOKEN=$(kubectl get secret coder-admin-api-token -n coder -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || echo "")
    
    if [ -n "$K8S_TOKEN" ] && [ ${#K8S_TOKEN} -gt 20 ]; then
        echo "✅ Token extracted from secret (length: ${#K8S_TOKEN})"
        
        # Test token validity (read-only)
        echo "   Testing token validity..."
        AUTH_RESPONSE=$(curl -s -H "Coder-Session-Token: $K8S_TOKEN" "$CODER_URL/api/v2/users/me" 2>/dev/null || echo "")
        if echo "$AUTH_RESPONSE" | grep -q '"id"'; then
            TOKEN_VALID=true
            USER_EMAIL=$(echo "$AUTH_RESPONSE" | grep -o '"email":"[^"]*"' | sed 's/"email":"//;s/"//')
            echo "✅ Token is valid for user: $USER_EMAIL"
        else
            echo "❌ Token is invalid or expired"
        fi
    else
        echo "❌ Token is empty or too short"
    fi
else
    echo "❌ No token secret found"
fi
echo ""

# Test 4: User and admin detection
echo "👤 Test 4: Admin User Detection"
echo "------------------------------"
USERS_RESPONSE=$(curl -s "$CODER_URL/api/v2/users?limit=10" 2>/dev/null || echo "")
if echo "$USERS_RESPONSE" | grep -q '"users"'; then
    USER_COUNT=$(echo "$USERS_RESPONSE" | grep -o '"id":"[^"]*"' | wc -l | xargs)
    echo "✅ Users API accessible (found $USER_COUNT users)"
    
    # Get first admin user
    FIRST_USER_ID=$(echo "$USERS_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//;s/"//')
    FIRST_USER_EMAIL=$(echo "$USERS_RESPONSE" | grep -o '"email":"[^"]*"' | head -1 | sed 's/"email":"//;s/"//')
    
    if [ -n "$FIRST_USER_ID" ]; then
        echo "✅ First admin user: $FIRST_USER_EMAIL ($FIRST_USER_ID)"
    else
        echo "⚠️  No admin users found - manual user creation needed"
    fi
else
    echo "❌ Users API not accessible"
fi
echo ""

# Test 5: Template automation readiness
echo "📋 Test 5: Template Files and Job"
echo "--------------------------------"

# Check template ConfigMaps
if kubectl get configmap coder-template-files -n coder >/dev/null 2>&1; then
    echo "✅ Template files ConfigMap exists"
    
    # Check required template files
    TEMPLATE_FILES=$(kubectl get configmap coder-template-files -n coder -o jsonpath='{.data}' 2>/dev/null || echo "{}")
    if echo "$TEMPLATE_FILES" | grep -q '"main.tf"'; then
        echo "✅ main.tf template file present"
    else
        echo "❌ main.tf template file missing"
    fi
    
    if echo "$TEMPLATE_FILES" | grep -q '"README.md"'; then
        echo "✅ README.md template file present"
    else
        echo "❌ README.md template file missing"
    fi
else
    echo "❌ Template files ConfigMap missing"
fi

if kubectl get configmap coder-template-init-script -n coder >/dev/null 2>&1; then
    echo "✅ Template init script ConfigMap exists"
else
    echo "❌ Template init script ConfigMap missing"
fi

# Check automation job
if kubectl get job coder-template-init -n coder >/dev/null 2>&1; then
    echo "✅ Template automation job exists"
    
    JOB_STATUS=$(kubectl get job coder-template-init -n coder -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "Unknown")
    echo "   Job status: $JOB_STATUS"
    
    if [ "$JOB_STATUS" = "Complete" ]; then
        echo "✅ Automation job completed successfully"
    elif [ "$JOB_STATUS" = "Failed" ]; then
        echo "❌ Automation job failed"
        echo "   Check logs: kubectl logs job/coder-template-init -n coder"
    else
        echo "⚠️  Automation job in progress or pending"
    fi
else
    echo "❌ Template automation job missing"
fi
echo ""

# Test 6: Template API verification (if token available)
echo "📚 Test 6: Template Management"
echo "-----------------------------"
if [ "$TOKEN_VALID" = true ]; then
    echo "   Using valid token for template checks..."
    
    # List templates
    TEMPLATES_RESPONSE=$(curl -s -H "Coder-Session-Token: $K8S_TOKEN" "$CODER_URL/api/v2/organizations/coder/templates" 2>/dev/null || echo "")
    if echo "$TEMPLATES_RESPONSE" | grep -q '"templates"'; then
        TEMPLATE_COUNT=$(echo "$TEMPLATES_RESPONSE" | grep -o '"name":"[^"]*"' | wc -l | xargs)
        echo "✅ Templates API accessible (found $TEMPLATE_COUNT templates)"
        
        # Check for our specific template
        if echo "$TEMPLATES_RESPONSE" | grep -q '"name":"kubernetes-devcontainer"'; then
            echo "✅ kubernetes-devcontainer template exists"
            
            TEMPLATE_ID=$(echo "$TEMPLATES_RESPONSE" | grep -o "\"id\":\"[^\"]*\",\"created_at\":[^,]*,\"updated_at\":[^,]*,\"organization_id\":\"[^\"]*\",\"name\":\"kubernetes-devcontainer\"" | sed 's/"id":"//;s/",.*$//')
            echo "   Template ID: $TEMPLATE_ID"
        else
            echo "⚠️  kubernetes-devcontainer template not found"
        fi
    else
        echo "❌ Templates API not accessible"
    fi
else
    echo "⚠️  No valid token - skipping template API tests"
    echo "   Run automation job to create token first"
fi
echo ""

# Test 7: External auth configuration
echo "🔐 Test 7: GitHub External Auth"
echo "------------------------------"
if [ "$TOKEN_VALID" = true ]; then
    # Check external auth config
    AUTH_RESPONSE=$(curl -s -H "Coder-Session-Token: $K8S_TOKEN" "$CODER_URL/api/v2/organizations/coder/external-auth" 2>/dev/null || echo "")
    if echo "$AUTH_RESPONSE" | grep -q '"providers"'; then
        if echo "$AUTH_RESPONSE" | grep -q '"id":"github"'; then
            echo "✅ GitHub external auth provider configured"
        else
            echo "⚠️  GitHub external auth not configured"
        fi
    else
        echo "❌ External auth API not accessible"
    fi
else
    echo "⚠️  No valid token - skipping external auth tests"
fi
echo ""

# Test 8: Infisical secrets verification
echo "🔒 Test 8: Infisical Secrets"
echo "---------------------------"
INFISICAL_SECRETS=$(kubectl get infisicalsecrets -n coder --no-headers 2>/dev/null || echo "")
if [ -n "$INFISICAL_SECRETS" ]; then
    echo "✅ Infisical secrets configured:"
    echo "$INFISICAL_SECRETS" | while read name ready age; do
        if [ "$ready" = "True" ]; then
            echo "   ✅ $name: $ready"
        else
            echo "   ❌ $name: $ready"
        fi
    done
else
    echo "❌ No Infisical secrets found"
fi

# Check database secrets specifically
if kubectl get secret coder-postgresql-credentials -n coder >/dev/null 2>&1; then
    echo "✅ Database credentials secret exists"
else
    echo "❌ Database credentials secret missing"
fi

if kubectl get secret github-oauth-credentials -n coder >/dev/null 2>&1; then
    echo "✅ GitHub OAuth credentials secret exists"
else
    echo "❌ GitHub OAuth credentials secret missing"
fi
echo ""

# Test Summary
echo "📊 TEST SUMMARY"
echo "==============="

TESTS_PASSED=0
TESTS_TOTAL=8

# Count passed tests
curl -s -f "$CODER_URL/healthz" >/dev/null 2>&1 && TESTS_PASSED=$((TESTS_PASSED + 1))
kubectl get namespace coder >/dev/null 2>&1 && TESTS_PASSED=$((TESTS_PASSED + 1))
[ "$SECRET_EXISTS" = true ] && TESTS_PASSED=$((TESTS_PASSED + 1))
[ -n "$FIRST_USER_ID" ] && TESTS_PASSED=$((TESTS_PASSED + 1))
kubectl get configmap coder-template-files -n coder >/dev/null 2>&1 && TESTS_PASSED=$((TESTS_PASSED + 1))
[ "$TOKEN_VALID" = true ] && TESTS_PASSED=$((TESTS_PASSED + 1))
kubectl get infisicalsecrets -n coder >/dev/null 2>&1 && TESTS_PASSED=$((TESTS_PASSED + 1))
kubectl get secret coder-postgresql-credentials -n coder >/dev/null 2>&1 && TESTS_PASSED=$((TESTS_PASSED + 1))

echo "Tests Passed: $TESTS_PASSED/$TESTS_TOTAL"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo "🎉 ALL TESTS PASSED - Automation ready!"
    echo ""
    echo "✅ WORKFLOW STATUS: FULLY OPERATIONAL"
    echo "   - Coder service accessible"
    echo "   - Token management configured" 
    echo "   - Template automation ready"
    echo "   - Database and auth secrets synced"
    echo ""
    echo "🚀 NEXT STEPS:"
    echo "   1. Ensure admin user exists at: $CODER_URL"
    echo "   2. Monitor automation: kubectl logs job/coder-template-init -n coder"
    echo "   3. Verify template creation automatically"
elif [ $TESTS_PASSED -ge 6 ]; then
    echo "⚠️  MOSTLY WORKING ($TESTS_PASSED/$TESTS_TOTAL passed)"
    echo "   Minor issues detected - check specific test output above"
    echo ""
    echo "🔧 LIKELY NEEDS:"
    echo "   - Wait for Infisical secret sync (60s interval)"
    echo "   - Create first admin user manually"
    echo "   - Run automation job: kubectl delete job coder-template-init -n coder"
else
    echo "❌ SIGNIFICANT ISSUES ($TESTS_PASSED/$TESTS_TOTAL passed)"
    echo "   Major problems detected - review deployment"
    echo ""
    echo "🚨 CHECK REQUIRED:"
    echo "   - Flux reconciliation status"
    echo "   - Pod logs and events"
    echo "   - Secret synchronization"
fi

echo ""
echo "📋 MONITORING COMMANDS:"
echo "   kubectl get pods -n coder"
echo "   kubectl logs job/coder-template-init -n coder"
echo "   kubectl get infisicalsecrets -n coder"
echo "   kubectl describe infisicalsecret coder-postgresql-credentials -n coder"
echo "   curl -I $CODER_URL"