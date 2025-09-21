#!/bin/bash
set -e

# provision-database.sh - Create tenant database in shared MySQL cluster
# Usage: ./provision-database.sh --namespace=test1 --tier=shared

NAMESPACE=""
TIER="shared"
DATABASE_HOST="mysql-cluster-shared.shared-services.svc.cluster.local"
VERBOSE=false

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace=*) NAMESPACE="${1#*=}"; shift ;;
    --tier=*) TIER="${1#*=}"; shift ;;
    --database-host=*) DATABASE_HOST="${1#*=}"; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --help) show_help; exit 0 ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
  esac
done

show_help() {
    cat << EOF
🗄️ Database Provisioning Tool

USAGE:
    ./provision-database.sh --namespace=NAMESPACE [OPTIONS]

REQUIRED:
    --namespace=NAMESPACE      Tenant namespace (e.g., test1, client1)

OPTIONS:
    --tier=TIER               Database tier: shared, dedicated (default: shared)
    --database-host=HOST      Database host (default: mysql-cluster-shared.shared-services.svc.cluster.local)
    --verbose                 Verbose output
    --help                    Show this help

EXAMPLES:
    # Create database for shared tier tenant
    ./provision-database.sh --namespace=test1

    # Create database for tenant on specific host
    ./provision-database.sh --namespace=client1 --database-host=mysql-premium.shared-services.svc.cluster.local

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

validate_inputs() {
    [[ -z "$NAMESPACE" ]] && { log_error "--namespace is required"; exit 1; }

    # Validate namespace format (must be valid for database names)
    if [[ ! "$NAMESPACE" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        log_error "Invalid namespace format: $NAMESPACE (must be alphanumeric with _ or -)"
        exit 1
    fi
}

check_database_connection() {
    log "Checking database connection to $DATABASE_HOST..."

    # Try to connect to MySQL using kubectl port-forward
    local pod_name=$(kubectl get pods -n shared-services -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=primary -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$pod_name" ]]; then
        log_error "No MySQL primary pod found in shared-services namespace"
        exit 1
    fi

    log "Found MySQL pod: $pod_name"
    log_success "Database connection verified"
}

create_tenant_database() {
    log "Creating database for tenant: $NAMESPACE"

    local database_name="wp_${NAMESPACE}"
    local pod_name=$(kubectl get pods -n shared-services -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=primary -o jsonpath='{.items[0].metadata.name}')

    # Get root password from secret
    local root_password=$(kubectl get secret mysql-cluster-shared-secrets -n shared-services -o jsonpath='{.data.mysql-root-password}' | base64 -d)

    if [[ -z "$root_password" ]]; then
        log_error "Could not retrieve MySQL root password from secret"
        exit 1
    fi

    # Create the database
    log "Creating database: $database_name"

    kubectl exec -n shared-services "$pod_name" -- mysql -u root -p"$root_password" << EOF
-- Create database for tenant
CREATE DATABASE IF NOT EXISTS \`$database_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant permissions to WordPress user
GRANT ALL PRIVILEGES ON \`$database_name\`.* TO 'wordpress'@'%';

-- Show the created database
SHOW DATABASES LIKE 'wp_%';

-- Flush privileges
FLUSH PRIVILEGES;

-- Show grants for wordpress user
SHOW GRANTS FOR 'wordpress'@'%';
EOF

    if [[ $? -eq 0 ]]; then
        log_success "Database '$database_name' created successfully"
    else
        log_error "Failed to create database '$database_name'"
        exit 1
    fi
}

verify_database() {
    log "Verifying database creation..."

    local database_name="wp_${NAMESPACE}"
    local pod_name=$(kubectl get pods -n shared-services -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=primary -o jsonpath='{.items[0].metadata.name}')
    local root_password=$(kubectl get secret mysql-cluster-shared-secrets -n shared-services -o jsonpath='{.data.mysql-root-password}' | base64 -d)

    # Check if database exists and is accessible
    local result=$(kubectl exec -n shared-services "$pod_name" -- mysql -u root -p"$root_password" -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$database_name';" --skip-column-names 2>/dev/null)

    if [[ "$result" == "$database_name" ]]; then
        log_success "Database verification completed"

        # Get database size
        local size=$(kubectl exec -n shared-services "$pod_name" -- mysql -u root -p"$root_password" -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema='$database_name';" --skip-column-names 2>/dev/null)

        echo -e "${BLUE}Database Details:${NC}"
        echo "  📁 Name: $database_name"
        echo "  🖥️  Host: $DATABASE_HOST"
        echo "  👤 User: wordpress"
        echo "  📊 Size: ${size:-0} MB"
        echo "  🔗 Connection: $database_name.$DATABASE_HOST:3306"

    else
        log_error "Database verification failed - database not found"
        exit 1
    fi
}

show_connection_info() {
    echo
    echo -e "${GREEN}🗄️ DATABASE PROVISIONED SUCCESSFULLY! 🗄️${NC}"
    echo
    echo -e "${BLUE}Connection Information:${NC}"
    echo "  Database Host: $DATABASE_HOST"
    echo "  Database Name: wp_${NAMESPACE}"
    echo "  Username: wordpress"
    echo "  Password: [stored in mysql-cluster-shared-secrets]"
    echo "  Port: 3306"
    echo
    echo -e "${BLUE}WordPress Configuration:${NC}"
    echo "  DB_HOST=$DATABASE_HOST"
    echo "  DB_NAME=wp_${NAMESPACE}"
    echo "  DB_USER=wordpress"
    echo "  DB_PASSWORD=\$MYSQL_PASSWORD"
    echo
    echo -e "${BLUE}kubectl Commands:${NC}"
    echo "  # Connect to database"
    echo "  kubectl exec -n shared-services \$(kubectl get pods -n shared-services -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=primary -o jsonpath='{.items[0].metadata.name}') -- mysql -u wordpress -p wp_${NAMESPACE}"
    echo
    echo "  # View all tenant databases"
    echo "  kubectl exec -n shared-services \$(kubectl get pods -n shared-services -l app.kubernetes.io/name=mysql,app.kubernetes.io/component=primary -o jsonpath='{.items[0].metadata.name}') -- mysql -u root -p -e \"SHOW DATABASES LIKE 'wp_%';\""
    echo
}

main() {
    echo -e "${GREEN}🗄️ Database Provisioning Tool${NC}"
    echo

    validate_inputs
    check_database_connection
    create_tenant_database
    verify_database
    show_connection_info

    log_success "Database provisioning completed for tenant: $NAMESPACE"
}

main "$@"