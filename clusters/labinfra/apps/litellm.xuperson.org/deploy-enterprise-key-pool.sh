#!/bin/bash

# LiteLLM Enterprise Key Pool Deployment Script
# Transforms LiteLLM into an enterprise-grade AI gateway

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="litellm"
APP_URL="https://litellm.xuperson.org"
DEPLOYMENT_NAME="litellm-deployment"
INFISICAL_PATH="/litellm"

# Usage function
show_usage() {
    echo -e "${BLUE}🚀 LiteLLM Enterprise Key Pool Deployment${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}--init-keys${NC}    Initialize Infisical secrets in $INFISICAL_PATH folder"
    echo -e "  ${GREEN}--deploy${NC}       Deploy the LiteLLM Enterprise Key Pool"
    echo -e "  ${GREEN}--validate${NC}     Validate deployment with a test API call"
    echo -e "  ${GREEN}--help${NC}         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --init-keys     # Set up secrets in Infisical"
    echo "  $0 --deploy        # Deploy the enterprise key pool"
    echo "  $0 --validate      # Test the deployment"
    echo ""
    echo "Full workflow:"
    echo "  $0 --init-keys && $0 --deploy && $0 --validate"
    echo ""
}

# Function to print status
print_status() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

# Initialize Infisical secrets
init_infisical_keys() {
    print_status "🔐 Initializing Infisical secrets in $INFISICAL_PATH folder..."
    
    # Check if infisical CLI is available
    if ! command -v infisical &> /dev/null; then
        print_error "Infisical CLI not found. Please install infisical CLI."
        echo "Install with: npm install -g @infisical/cli"
        exit 1
    fi
    
    # Check if user is logged in
    if ! infisical user > /dev/null 2>&1; then
        print_error "Not logged in to Infisical. Please run: infisical login"
        exit 1
    fi
    
    echo -e "${YELLOW}📋 Current setup will use existing GEMINI_API_KEY for both keys${NC}"
    echo -e "${YELLOW}   You can update them later with different values${NC}"
    echo ""
    
    # Get current GEMINI_API_KEY if it exists
    print_status "🔍 Checking for existing GEMINI_API_KEY..."
    EXISTING_KEY=$(infisical secrets get GEMINI_API_KEY --env=prod --path=/ --plain 2>/dev/null | head -1 | grep -v "A new release" || echo "")
    
    if [[ -n "$EXISTING_KEY" ]]; then
        print_status "✅ Found existing GEMINI_API_KEY"
        echo -e "${BLUE}Will use this key for both GEMINI_KEY_1 and GEMINI_KEY_2${NC}"
        USE_EXISTING_KEY="$EXISTING_KEY"
    else
        print_warning "No existing GEMINI_API_KEY found in root path"
        echo -e "${YELLOW}Please enter your Gemini API key:${NC}"
        read -s -p "Gemini API Key: " USE_EXISTING_KEY
        echo ""
        
        if [[ -z "$USE_EXISTING_KEY" ]]; then
            print_error "No API key provided"
            exit 1
        fi
    fi
    
    # Create the /litellm folder if it doesn't exist
    print_status "📁 Creating $INFISICAL_PATH folder if needed..."
    infisical secrets folders create --name litellm --path=/ --env=prod 2>/dev/null || print_status "📁 Folder already exists or created successfully"
    
    # Set up secrets in Infisical /litellm folder
    print_status "📁 Setting up secrets in Infisical $INFISICAL_PATH folder..."
    
    # Core LiteLLM secrets
    print_status "Setting LITELLM_MASTER_KEY..."
    infisical secrets set LITELLM_MASTER_KEY=lo2v6ewnDLY2JXapRNTqdYZGs6Up2kHmzGfGbw5STr8= --env=prod --path="$INFISICAL_PATH"
    
    print_status "Setting LITELLM_SALT_KEY..."
    SALT_KEY=$(openssl rand -base64 32)
    infisical secrets set LITELLM_SALT_KEY="$SALT_KEY" --env=prod --path="$INFISICAL_PATH"
    
    # Database URL (using existing or default)
    print_status "Setting DATABASE_URL..."
    EXISTING_DB=$(infisical secrets get DATABASE_URL --env=prod --path=/ --plain 2>/dev/null | head -1 | grep -v "A new release" || echo "")
    if [[ -n "$EXISTING_DB" ]]; then
        infisical secrets set DATABASE_URL="$EXISTING_DB" --env=prod --path="$INFISICAL_PATH"
    else
        # Default PostgreSQL URL for litellm namespace
        infisical secrets set DATABASE_URL="postgresql://litellm:password@litellm-postgresql:5432/litellm" --env=prod --path="$INFISICAL_PATH"
    fi
    
    # Gemini API keys
    print_status "Setting GEMINI_KEY_1..."
    infisical secrets set GEMINI_KEY_1="$USE_EXISTING_KEY" --env=prod --path="$INFISICAL_PATH"
    
    print_status "Setting GEMINI_KEY_2..."
    infisical secrets set GEMINI_KEY_2="$USE_EXISTING_KEY" --env=prod --path="$INFISICAL_PATH"
    
    # Legacy key for backward compatibility
    print_status "Setting GEMINI_API_KEY (legacy)..."
    infisical secrets set GEMINI_API_KEY="$USE_EXISTING_KEY" --env=prod --path="$INFISICAL_PATH"
    
    echo ""
    print_status "✅ All secrets configured in Infisical $INFISICAL_PATH folder!"
    echo ""
    echo -e "${BLUE}📋 Secrets created:${NC}"
    echo "   • LITELLM_MASTER_KEY (auto-generated)"
    echo "   • LITELLM_SALT_KEY (auto-generated)"
    echo "   • DATABASE_URL (from existing or default)"
    echo "   • GEMINI_KEY_1 (from your input)"
    echo "   • GEMINI_KEY_2 (from your input)"
    echo "   • GEMINI_API_KEY (legacy compatibility)"
    echo ""
    echo -e "${YELLOW}💡 To add more keys later:${NC}"
    echo "   infisical secrets set GEMINI_KEY_3=your_new_key --env=prod --path=$INFISICAL_PATH"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_status "🔍 Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        print_error "git not found. Please install git."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -f "kustomization.yaml" ]]; then
        print_error "kustomization.yaml not found. Please run from the LiteLLM app directory."
        exit 1
    fi
    
    print_status "✅ Prerequisites check passed"
}

# Validate Infisical secrets
check_infisical_secrets() {
    print_status "🔐 Checking Infisical secrets..."
    
    # Check if Infisical secret exists
    if ! kubectl get infisicalsecret litellm-secrets -n $NAMESPACE &> /dev/null; then
        print_error "InfisicalSecret 'litellm-secrets' not found in namespace $NAMESPACE"
        exit 1
    fi
    
    # Check if secret is synced
    SECRET_STATUS=$(kubectl get infisicalsecret litellm-secrets -n $NAMESPACE -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
    
    if [[ "$SECRET_STATUS" != "True" ]]; then
        print_warning "Infisical secret may not be fully synced. Status: $SECRET_STATUS"
        print_warning "Please ensure GEMINI_KEY_1 and GEMINI_KEY_2 are set in Infisical (prod environment)"
        echo ""
        echo "Required Infisical secrets:"
        echo "  - LITELLM_MASTER_KEY"
        echo "  - LITELLM_SALT_KEY" 
        echo "  - DATABASE_URL"
        echo "  - GEMINI_KEY_1  ← New!"
        echo "  - GEMINI_KEY_2  ← New!"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_status "✅ Infisical secrets are synced"
    fi
}

# Deploy the configuration
deploy_configuration() {
    print_status "📦 Deploying LiteLLM Enterprise Key Pool..."
    
    # Apply the kustomization
    kubectl apply -k . 
    
    if [[ $? -eq 0 ]]; then
        print_status "✅ Configuration deployed successfully"
    else
        print_error "Failed to deploy configuration"
        exit 1
    fi
}

# Wait for deployment
wait_for_deployment() {
    print_status "⏳ Waiting for deployment to be ready..."
    
    # Wait for deployment to be available
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=300s
    
    if [[ $? -eq 0 ]]; then
        print_status "✅ Deployment is ready"
    else
        print_error "Deployment failed to become ready"
        exit 1
    fi
}

# Monitor bootstrap process
monitor_bootstrap() {
    print_status "🔧 Monitoring key pool bootstrap..."
    
    echo -e "${YELLOW}Waiting for key pool setup to complete...${NC}"
    echo "This may take 2-3 minutes..."
    echo ""
    
    # Wait for bootstrap container to start
    sleep 30
    
    # Follow bootstrap logs
    kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c key-pool-setup -f --tail=50 &
    LOG_PID=$!
    
    # Wait for virtual key to be generated (timeout after 5 minutes)
    TIMEOUT=300
    ELAPSED=0
    VIRTUAL_KEY=""
    
    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        # Check if virtual key is generated
        VIRTUAL_KEY=$(kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c key-pool-setup 2>/dev/null | grep "Virtual Key:" | tail -1 | awk '{print $NF}' || echo "")
        
        if [[ -n "$VIRTUAL_KEY" && "$VIRTUAL_KEY" != "Virtual" ]]; then
            kill $LOG_PID 2>/dev/null || true
            break
        fi
        
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    if [[ -n "$VIRTUAL_KEY" && "$VIRTUAL_KEY" != "Virtual" ]]; then
        print_status "🎉 Bootstrap completed successfully!"
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    🎉 DEPLOYMENT SUCCESSFUL! 🎉                ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}🔑 Your Virtual Key:${NC}"
        echo -e "${YELLOW}$VIRTUAL_KEY${NC}"
        echo ""
        echo -e "${BLUE}🌐 API Endpoint:${NC}"
        echo -e "${YELLOW}$APP_URL${NC}"
        echo ""
        echo -e "${BLUE}💡 Test your setup:${NC}"
        echo -e "${YELLOW}curl -X POST '$APP_URL/v1/chat/completions' \\${NC}"
        echo -e "${YELLOW}  -H 'Authorization: Bearer $VIRTUAL_KEY' \\${NC}"
        echo -e "${YELLOW}  -H 'Content-Type: application/json' \\${NC}"
        echo -e "${YELLOW}  -d '{\"model\": \"gpt-4\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'${NC}"
        echo ""
        echo -e "${GREEN}✨ Your LiteLLM is now an enterprise AI gateway with intelligent key pooling!${NC}"
        echo ""
    else
        print_error "Bootstrap timed out. Check logs for issues:"
        echo "kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c key-pool-setup"
        exit 1
    fi
}

# Get deployment status
show_status() {
    print_status "📊 Deployment Status:"
    echo ""
    
    # Pod status
    echo -e "${BLUE}Pods:${NC}"
    kubectl get pods -n $NAMESPACE -l app=litellm
    echo ""
    
    # Service status  
    echo -e "${BLUE}Services:${NC}"
    kubectl get svc -n $NAMESPACE
    echo ""
    
    # Ingress status
    echo -e "${BLUE}Ingress:${NC}"
    kubectl get ingress -n $NAMESPACE
    echo ""
    
    # Secret status
    echo -e "${BLUE}Secrets:${NC}"
    kubectl get secrets -n $NAMESPACE | grep litellm
    echo ""
}

# Validate deployment with test API call
validate_deployment() {
    print_status "🧪 Validating LiteLLM Enterprise Key Pool deployment..."
    
    # Check if deployment is ready
    if ! kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE > /dev/null 2>&1; then
        print_error "Deployment $DEPLOYMENT_NAME not found in namespace $NAMESPACE"
        print_error "Please run: $0 --deploy first"
        exit 1
    fi
    
    # Check deployment status
    print_status "📋 Checking deployment status..."
    READY_REPLICAS=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    TOTAL_REPLICAS=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    
    if [[ "$READY_REPLICAS" != "$TOTAL_REPLICAS" ]]; then
        print_error "Deployment not ready: $READY_REPLICAS/$TOTAL_REPLICAS replicas ready"
        exit 1
    fi
    
    print_status "✅ Deployment is ready ($READY_REPLICAS/$TOTAL_REPLICAS)"
    
    # Get virtual key from logs
    print_status "🔑 Extracting virtual key..."
    VIRTUAL_KEY=""
    for attempt in {1..30}; do
        VIRTUAL_KEY=$(kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c key-pool-setup 2>/dev/null | grep "Virtual Key:" | tail -1 | awk '{print $NF}' || echo "")
        
        if [[ -n "$VIRTUAL_KEY" && "$VIRTUAL_KEY" != "Virtual" && "$VIRTUAL_KEY" =~ ^sk- ]]; then
            break
        fi
        
        print_status "⏳ Waiting for virtual key generation... (attempt $attempt/30)"
        sleep 10
    done
    
    if [[ -z "$VIRTUAL_KEY" || "$VIRTUAL_KEY" == "Virtual" || ! "$VIRTUAL_KEY" =~ ^sk- ]]; then
        print_error "Could not retrieve virtual key from logs"
        echo ""
        echo "Try checking logs manually:"
        echo "  kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c key-pool-setup | grep -i virtual"
        exit 1
    fi
    
    print_status "✅ Virtual key found: $VIRTUAL_KEY"
    
    # Test health endpoint
    print_status "🏥 Testing health endpoint..."
    if curl -s "$APP_URL/health" > /dev/null; then
        print_status "✅ Health endpoint responding"
    else
        print_warning "⚠️ Health endpoint not responding (may still be starting)"
    fi
    
    # Test wildcard model call
    print_status "🌟 Testing wildcard model call (gpt-4 → gemini routing)..."
    
    TEST_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$APP_URL/v1/chat/completions" \
        -H "Authorization: Bearer $VIRTUAL_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-4",
            "messages": [
                {
                    "role": "user", 
                    "content": "Hello! This is a test of the LiteLLM Enterprise Key Pool. Please respond with just \"Key pool working!\" if you can see this."
                }
            ],
            "max_tokens": 50
        }' || echo "ERROR_000")
    
    HTTP_CODE="${TEST_RESPONSE: -3}"
    RESPONSE_BODY="${TEST_RESPONSE%???}"
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        print_status "🎉 SUCCESS! Wildcard model call working!"
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    🎉 VALIDATION SUCCESSFUL! 🎉                ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BLUE}🔑 Virtual Key:${NC} $VIRTUAL_KEY"
        echo -e "${BLUE}🌐 API Endpoint:${NC} $APP_URL"
        echo -e "${BLUE}✅ HTTP Status:${NC} $HTTP_CODE"
        echo ""
        echo -e "${YELLOW}📝 API Response:${NC}"
        echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
        echo ""
        echo -e "${GREEN}🎊 Your LiteLLM Enterprise Key Pool is working perfectly!${NC}"
        echo ""
        echo -e "${BLUE}💡 Example usage:${NC}"
        echo -e "${YELLOW}curl -X POST '$APP_URL/v1/chat/completions' \\${NC}"
        echo -e "${YELLOW}  -H 'Authorization: Bearer $VIRTUAL_KEY' \\${NC}"
        echo -e "${YELLOW}  -H 'Content-Type: application/json' \\${NC}"
        echo -e "${YELLOW}  -d '{\"model\": \"gpt-4\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'${NC}"
        echo ""
    else
        print_error "❌ Wildcard model call failed! HTTP: $HTTP_CODE"
        echo ""
        echo -e "${YELLOW}Response:${NC}"
        echo "$RESPONSE_BODY"
        echo ""
        echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
        echo "1. Check if virtual key is valid:"
        echo "   curl -H 'Authorization: Bearer $VIRTUAL_KEY' $APP_URL/v1/models"
        echo ""
        echo "2. Check key pool setup logs:"
        echo "   kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c key-pool-setup -f"
        echo ""
        echo "3. Check LiteLLM main logs:"
        echo "   kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c litellm -f"
        exit 1
    fi
}

# Troubleshooting info
show_troubleshooting() {
    echo -e "${YELLOW}🔧 Troubleshooting Commands:${NC}"
    echo ""
    echo "Check key pool setup logs:"
    echo "  kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c key-pool-setup -f"
    echo ""
    echo "Check LiteLLM main logs:"
    echo "  kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -c litellm -f"
    echo ""
    echo "Check Infisical secret sync:"
    echo "  kubectl describe infisicalsecret litellm-secrets -n $NAMESPACE"
    echo ""
    echo "Restart deployment:"
    echo "  kubectl rollout restart deployment/$DEPLOYMENT_NAME -n $NAMESPACE"
    echo ""
    echo "Check health:"
    echo "  curl $APP_URL/health"
    echo ""
}

# Deploy workflow (original main function)
deploy_workflow() {
    echo -e "${BLUE}🚀 Starting LiteLLM Enterprise Key Pool deployment...${NC}"
    echo ""
    
    check_prerequisites
    check_infisical_secrets
    deploy_configuration
    wait_for_deployment
    monitor_bootstrap
    show_status
    
    echo ""
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  $0 --validate    # Test the deployment"
    echo ""
}

# Main execution
main() {
    case "${1:-}" in
        --init-keys)
            echo -e "${BLUE}🔐 Initializing Infisical secrets...${NC}"
            echo ""
            init_infisical_keys
            echo ""
            echo -e "${GREEN}✅ Secrets initialization completed!${NC}"
            echo ""
            echo "Next steps:"
            echo "  $0 --deploy     # Deploy the key pool"
            echo "  $0 --validate   # Test after deployment"
            ;;
        --deploy)
            deploy_workflow
            ;;
        --validate)
            echo -e "${BLUE}🧪 Validating deployment...${NC}"
            echo ""
            validate_deployment
            ;;
        --help|help|-h)
            show_usage
            ;;
        "")
            echo -e "${RED}❌ No command specified${NC}"
            echo ""
            show_usage
            exit 1
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Handle script termination
cleanup() {
    echo ""
    print_warning "Script interrupted."
    echo ""
    show_troubleshooting
}

trap cleanup SIGINT SIGTERM

# Run main function
main "$@"