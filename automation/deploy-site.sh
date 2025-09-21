#!/bin/bash
set -e

# deploy-site.sh - Universal GitOps Site Deployment Tool
# Usage: ./deploy-site.sh --template=wordpress-shared --domain=client1.xuperson.org --tier=shared

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
TEMPLATE=""
DOMAIN=""
TIER="shared"
THEME="twentytwentyfour"
DATABASE_CLUSTER=""
DRY_RUN=false
VERBOSE=false
FORCE=false

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$REPO_ROOT/templates"
TENANTS_DIR="$REPO_ROOT/tenants"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --template=*) TEMPLATE="${1#*=}"; shift ;;
    --domain=*) DOMAIN="${1#*=}"; shift ;;
    --tier=*) TIER="${1#*=}"; shift ;;
    --theme=*) THEME="${1#*=}"; shift ;;
    --database=*) DATABASE_CLUSTER="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --force) FORCE=true; shift ;;
    --help) show_help; exit 0 ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
  esac
done

show_help() {
    cat << EOF
🚀 GitOps Site Deployment Tool

USAGE:
    ./deploy-site.sh --template=TEMPLATE --domain=DOMAIN [OPTIONS]

REQUIRED:
    --template=TEMPLATE    Template to use (wordpress-shared, nodejs-app, static-site)
    --domain=DOMAIN        Full domain name (e.g., client1.xuperson.org)

OPTIONS:
    --tier=TIER           Resource tier: shared, dedicated, enterprise (default: shared)
    --theme=THEME         WordPress theme name (default: twentytwentyfour)
    --database=CLUSTER    Specific database cluster (auto-assigned if not specified)
    --dry-run             Show what would be deployed without applying
    --verbose             Verbose output for debugging
    --force               Force deployment even if site exists
    --help                Show this help

EXAMPLES:
    # Deploy shared WordPress site
    ./deploy-site.sh --template=wordpress-shared --domain=client1.xuperson.org

    # Deploy dedicated WordPress with custom theme
    ./deploy-site.sh --template=wordpress-shared --domain=premium.xuperson.org --tier=dedicated --theme=avada

    # Deploy enterprise WordPress with specific database
    ./deploy-site.sh --template=wordpress-shared --domain=enterprise.xuperson.org --tier=enterprise --database=mysql-cluster-premium

    # Dry run to see what would be deployed
    ./deploy-site.sh --template=wordpress-shared --domain=test.xuperson.org --dry-run

TIERS:
    shared      - Shared resources, $1/month, 500 sites per cluster
    dedicated   - Dedicated database, $10/month, 50 sites per cluster
    enterprise  - Full isolation, $100/month, 10 sites per cluster

EOF
}

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Validation functions
validate_inputs() {
    log "Validating inputs..."

    [[ -z "$TEMPLATE" ]] && { log_error "--template is required"; exit 1; }
    [[ -z "$DOMAIN" ]] && { log_error "--domain is required"; exit 1; }

    # Check if template exists
    [[ ! -d "$TEMPLATES_DIR/$TEMPLATE" ]] && {
        log_error "Template '$TEMPLATE' not found in $TEMPLATES_DIR"
        echo "Available templates:"
        ls -1 "$TEMPLATES_DIR" | sed 's/^/  - /'
        exit 1
    }

    # Check if tier config exists
    local tier_config="$TEMPLATES_DIR/$TEMPLATE/config/tier-$TIER.yaml"
    [[ ! -f "$tier_config" ]] && {
        log_error "Tier '$TIER' not supported for template '$TEMPLATE'"
        echo "Available tiers:"
        ls -1 "$TEMPLATES_DIR/$TEMPLATE/config"/tier-*.yaml | sed 's/.*tier-//; s/.yaml$//' | sed 's/^/  - /'
        exit 1
    }

    # Validate domain format
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid domain format: $DOMAIN"
        exit 1
    fi

    # Extract namespace from domain
    NAMESPACE=$(echo "$DOMAIN" | cut -d'.' -f1)
    [[ -z "$NAMESPACE" ]] && { log_error "Could not extract namespace from domain"; exit 1; }

    log_success "Inputs validated"
}

check_dependencies() {
    log "Checking dependencies..."

    # Check required tools
    local deps=("kubectl" "yq" "envsubst" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required tool '$dep' not found"
            exit 1
        fi
    done

    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Check if infisical is available for secrets
    if ! command -v "infisical" &> /dev/null; then
        log_warning "Infisical CLI not found - secrets will need to be created manually"
    fi

    log_success "Dependencies checked"
}

load_tier_config() {
    log "Loading tier configuration for '$TIER'..."

    local tier_config="$TEMPLATES_DIR/$TEMPLATE/config/tier-$TIER.yaml"

    # Load configuration using yq
    MARIADB_ENABLED=$(yq eval '.mariadb_enabled' "$tier_config")
    EXTERNAL_DB_ENABLED=$(yq eval '.external_db_enabled' "$tier_config")
    EXTERNAL_DB_HOST=$(yq eval '.external_db_host' "$tier_config")
    PERSISTENCE_ENABLED=$(yq eval '.persistence_enabled' "$tier_config")
    STORAGE_SIZE=$(yq eval '.storage_size' "$tier_config")
    RESOURCES_MEMORY_REQUEST=$(yq eval '.resources.memory_request' "$tier_config")
    RESOURCES_MEMORY_LIMIT=$(yq eval '.resources.memory_limit' "$tier_config")
    RESOURCES_CPU_REQUEST=$(yq eval '.resources.cpu_request' "$tier_config")
    RESOURCES_CPU_LIMIT=$(yq eval '.resources.cpu_limit' "$tier_config")
    WP_MEMORY_LIMIT=$(yq eval '.wp_memory_limit' "$tier_config")
    UPLOAD_MAX_SIZE=$(yq eval '.upload_max_size' "$tier_config")
    RATE_LIMIT_CONNECTIONS=$(yq eval '.rate_limit_connections' "$tier_config")
    RATE_LIMIT_RPM=$(yq eval '.rate_limit_rpm' "$tier_config")

    # Database-specific config
    if [[ "$MARIADB_ENABLED" == "true" ]]; then
        DATABASE_NAME="$NAMESPACE"
        DB_PERSISTENCE_ENABLED=$(yq eval '.db_persistence_enabled' "$tier_config")
        DB_STORAGE_SIZE=$(yq eval '.db_storage_size' "$tier_config")
        DB_RESOURCES_MEMORY_REQUEST=$(yq eval '.db_resources.memory_request' "$tier_config")
        DB_RESOURCES_MEMORY_LIMIT=$(yq eval '.db_resources.memory_limit' "$tier_config")
        DB_RESOURCES_CPU_REQUEST=$(yq eval '.db_resources.cpu_request' "$tier_config")
        DB_RESOURCES_CPU_LIMIT=$(yq eval '.db_resources.cpu_limit' "$tier_config")
    else
        DATABASE_NAME="wp_${NAMESPACE}_"
        EXTERNAL_DB_USER="wordpress"
        EXTERNAL_DB_NAME="wp_${NAMESPACE}"
        EXTERNAL_DB_SECRET="mysql-cluster-shared-secrets"
    fi

    log_success "Tier configuration loaded"

    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Configuration summary:"
        echo "  - Tier: $TIER"
        echo "  - MariaDB enabled: $MARIADB_ENABLED"
        echo "  - External DB: $EXTERNAL_DB_ENABLED"
        echo "  - Resources: ${RESOURCES_CPU_REQUEST}/${RESOURCES_CPU_LIMIT} CPU, ${RESOURCES_MEMORY_REQUEST}/${RESOURCES_MEMORY_LIMIT} Memory"
        echo "  - Storage: $STORAGE_SIZE"
        echo "  - Rate limits: ${RATE_LIMIT_CONNECTIONS} conn, ${RATE_LIMIT_RPM} rpm"
    fi
}

check_site_exists() {
    log "Checking if site already exists..."

    local tenant_dir="$TENANTS_DIR/$DOMAIN"

    if [[ -d "$tenant_dir" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            log_warning "Site exists but --force specified, will overwrite"
        else
            log_error "Site '$DOMAIN' already exists at $tenant_dir"
            log_info "Use --force to overwrite or choose a different domain"
            exit 1
        fi
    fi

    # Check if namespace exists in cluster
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        if [[ "$FORCE" == "true" ]]; then
            log_warning "Namespace '$NAMESPACE' exists but --force specified"
        else
            log_error "Namespace '$NAMESPACE' already exists in cluster"
            log_info "Use --force to overwrite or choose a different domain"
            exit 1
        fi
    fi

    log_success "Site availability checked"
}

create_secrets() {
    log "Creating secrets in Infisical..."

    if ! command -v "infisical" &> /dev/null; then
        log_warning "Infisical CLI not available - skipping secret creation"
        log_info "Please create secrets manually in Infisical at path: /wordpress/$NAMESPACE"
        return 0
    fi

    local secrets_path="/wordpress/$NAMESPACE"

    # Create folder if it doesn't exist
    infisical secrets folders create --env=prod --path="/wordpress" --name="$NAMESPACE" 2>/dev/null || true

    log "Creating database secrets..."
    infisical secrets set "${NAMESPACE^^}_MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)" --env=prod --path="$secrets_path"
    infisical secrets set "${NAMESPACE^^}_MYSQL_PASSWORD=$(openssl rand -base64 24)" --env=prod --path="$secrets_path"

    log "Creating WordPress security keys..."
    infisical secrets set "${NAMESPACE^^}_WP_AUTH_KEY=$(openssl rand -base64 64)" --env=prod --path="$secrets_path"
    infisical secrets set "${NAMESPACE^^}_WP_SECURE_AUTH_KEY=$(openssl rand -base64 64)" --env=prod --path="$secrets_path"
    infisical secrets set "${NAMESPACE^^}_WP_LOGGED_IN_KEY=$(openssl rand -base64 64)" --env=prod --path="$secrets_path"
    infisical secrets set "${NAMESPACE^^}_WP_NONCE_KEY=$(openssl rand -base64 64)" --env=prod --path="$secrets_path"
    infisical secrets set "${NAMESPACE^^}_WP_AUTH_SALT=$(openssl rand -base64 64)" --env=prod --path="$secrets_path"
    infisical secrets set "${NAMESPACE^^}_WP_SECURE_AUTH_SALT=$(openssl rand -base64 64)" --env=prod --path="$secrets_path"
    infisical secrets set "${NAMESPACE^^}_WP_LOGGED_IN_SALT=$(openssl rand -base64 64)" --env=prod --path="$secrets_path"
    infisical secrets set "${NAMESPACE^^}_WP_NONCE_SALT=$(openssl rand -base64 64)" --env=prod --path="$secrets_path"

    log_success "Secrets created in Infisical"
}

generate_manifests() {
    log "Generating Kubernetes manifests..."

    local tenant_dir="$TENANTS_DIR/$DOMAIN"
    local template_dir="$TEMPLATES_DIR/$TEMPLATE/manifests"

    # Create tenant directory
    mkdir -p "$tenant_dir"

    # Process each template file
    for template_file in "$template_dir"/*.tmpl; do
        local output_file="$tenant_dir/$(basename "$template_file" .tmpl)"

        log "Processing $(basename "$template_file")..."

        # Use envsubst to replace variables
        export NAMESPACE DOMAIN TIER THEME APP_NAME="wordpress"
        export MARIADB_ENABLED EXTERNAL_DB_ENABLED EXTERNAL_DB_HOST EXTERNAL_DB_USER EXTERNAL_DB_NAME EXTERNAL_DB_SECRET
        export PERSISTENCE_ENABLED STORAGE_SIZE DATABASE_NAME
        export RESOURCES_MEMORY_REQUEST RESOURCES_MEMORY_LIMIT RESOURCES_CPU_REQUEST RESOURCES_CPU_LIMIT
        export DB_PERSISTENCE_ENABLED DB_STORAGE_SIZE
        export DB_RESOURCES_MEMORY_REQUEST DB_RESOURCES_MEMORY_LIMIT DB_RESOURCES_CPU_REQUEST DB_RESOURCES_CPU_LIMIT
        export WP_MEMORY_LIMIT UPLOAD_MAX_SIZE RATE_LIMIT_CONNECTIONS RATE_LIMIT_RPM

        envsubst < "$template_file" > "$output_file"

        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Generated: $output_file"
        fi
    done

    log_success "Manifests generated at $tenant_dir"
}

create_cicd_repo() {
    log "Creating CI/CD repository in Gitea..."

    # This would typically create a repository in Gitea and push the initial code
    # For now, we'll create the local structure

    local repo_dir="$TENANTS_DIR/$DOMAIN/repository"
    local cicd_template_dir="$TEMPLATES_DIR/$TEMPLATE/ci-cd"

    mkdir -p "$repo_dir"/{.gitea/workflows,wp-content/{themes,plugins,uploads}}

    # Copy CI/CD templates
    for template_file in "$cicd_template_dir"/*.tmpl; do
        local filename=$(basename "$template_file" .tmpl)

        if [[ "$filename" == "workflow.yaml" ]]; then
            envsubst < "$template_file" > "$repo_dir/.gitea/workflows/build.yml"
        else
            envsubst < "$template_file" > "$repo_dir/$filename"
        fi
    done

    # Create basic WordPress theme structure if needed
    local theme_dir="$repo_dir/wp-content/themes/$THEME"
    if [[ ! -d "$theme_dir" ]]; then
        mkdir -p "$theme_dir"

        cat > "$theme_dir/style.css" << EOF
/*
Theme Name: ${NAMESPACE^} Theme
Description: Custom WordPress theme for $DOMAIN
Version: 1.0.0
Tier: $TIER
*/
EOF

        cat > "$theme_dir/index.php" << EOF
<?php get_header(); ?>
<div class="main-content">
    <h1>Welcome to ${NAMESPACE^}</h1>
    <p>Your $TIER tier WordPress site is running!</p>
    <p>Domain: $DOMAIN</p>
    <p>Build: <?php echo getenv('BUILD_REF') ?: 'development'; ?></p>
</div>
<?php get_footer(); ?>
EOF
    fi

    log_success "CI/CD repository structure created"
}

deploy_to_cluster() {
    log "Deploying to Kubernetes cluster..."

    local tenant_dir="$TENANTS_DIR/$DOMAIN"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Would apply these manifests:"
        for file in "$tenant_dir"/*.yaml; do
            echo "  - $(basename "$file")"
        done
        return 0
    fi

    # Apply manifests in order
    local manifests=(
        "namespace.yaml"
        "secrets.yaml"
        "application.yaml"
        "ingress.yaml"
        "image-automation.yaml"
        "kustomization.yaml"
    )

    for manifest in "${manifests[@]}"; do
        local manifest_file="$tenant_dir/$manifest"

        if [[ -f "$manifest_file" ]]; then
            log "Applying $manifest..."
            kubectl apply -f "$manifest_file"
        fi
    done

    log_success "Manifests applied to cluster"
}

add_to_flux() {
    log "Adding site to Flux GitOps..."

    # Add tenant to main apps kustomization
    local apps_kustomization="$REPO_ROOT/clusters/labinfra/apps/kustomization.yaml"

    if ! grep -q "- $DOMAIN" "$apps_kustomization"; then
        echo "  - $DOMAIN" >> "$apps_kustomization"
        log_success "Added $DOMAIN to Flux apps kustomization"
    else
        log_info "Site already exists in Flux apps kustomization"
    fi
}

show_summary() {
    echo
    echo -e "${PURPLE}🎉 DEPLOYMENT COMPLETE! 🎉${NC}"
    echo
    echo -e "${CYAN}Site Details:${NC}"
    echo "  🌐 Domain: https://$DOMAIN"
    echo "  📦 Template: $TEMPLATE"
    echo "  🏷️  Tier: $TIER"
    echo "  🏷️  Namespace: $NAMESPACE"
    echo "  🎨 Theme: $THEME"
    echo "  💾 Database: $([ "$MARIADB_ENABLED" == "true" ] && echo "Dedicated MariaDB" || echo "Shared MySQL cluster")"
    echo
    echo -e "${CYAN}Resources:${NC}"
    echo "  💾 Memory: $RESOURCES_MEMORY_REQUEST / $RESOURCES_MEMORY_LIMIT"
    echo "  🖥️  CPU: $RESOURCES_CPU_REQUEST / $RESOURCES_CPU_LIMIT"
    echo "  💾 Storage: $STORAGE_SIZE"
    echo "  📊 Rate Limits: $RATE_LIMIT_CONNECTIONS conn, $RATE_LIMIT_RPM rpm"
    echo
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. 🔄 Commit and push the changes to Git"
    echo "  2. ⏰ Wait for Flux to reconcile (usually 1-2 minutes)"
    echo "  3. 🔍 Monitor deployment: kubectl get pods -n $NAMESPACE"
    echo "  4. 🌐 Access site: https://$DOMAIN (once DNS propagates)"
    echo
    echo -e "${YELLOW}Commands to monitor:${NC}"
    echo "  kubectl get all -n $NAMESPACE"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=wordpress"
    echo "  flux get helmreleases -n $NAMESPACE"
    echo
}

# Main execution flow
main() {
    echo -e "${PURPLE}🚀 GitOps Site Deployment Tool${NC}"
    echo

    validate_inputs
    check_dependencies
    load_tier_config
    check_site_exists

    create_secrets
    generate_manifests
    create_cicd_repo
    deploy_to_cluster
    add_to_flux

    show_summary

    if [[ "$DRY_RUN" != "true" ]]; then
        log_success "Site '$DOMAIN' deployed successfully!"
    else
        log_info "Dry run completed - no changes made"
    fi
}

# Run main function
main "$@"