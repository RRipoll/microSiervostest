#!/bin/bash

# Database migration and management script for TestJava Price Service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Database Migration Script for TestJava Price Service

Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
    init            Initialize database with schema and test data
    migrate         Run database migrations
    rollback        Rollback last migration
    reset           Reset database (drop and recreate)
    backup          Create database backup
    restore         Restore database from backup
    status          Show migration status
    seed            Populate database with seed data

OPTIONS:
    -e, --env ENV           Environment (local, staging, production) [default: local]
    -f, --file FILE         SQL file to execute
    -b, --backup-file FILE  Backup file for restore
    -y, --yes              Assume yes for all prompts
    -v, --verbose          Verbose output
    -h, --help             Show this help

EXAMPLES:
    $0 init                         # Initialize local database
    $0 migrate --env staging        # Run migrations on staging
    $0 backup --env production      # Backup production database
    $0 restore -b backup.sql       # Restore from backup file
    $0 seed --file test-data.sql   # Load specific seed data

DATABASE ENVIRONMENTS:
    local       H2 in-memory database
    staging     PostgreSQL staging database
    production  PostgreSQL production database
EOF
}

# Default values
ENVIRONMENT="local"
SQL_FILE=""
BACKUP_FILE=""
ASSUME_YES=false
VERBOSE=false
COMMAND=""

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -f|--file)
                SQL_FILE="$2"
                shift 2
                ;;
            -b|--backup-file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            -y|--yes)
                ASSUME_YES=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            init|migrate|rollback|reset|backup|restore|status|seed)
                COMMAND="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$COMMAND" ]]; then
        log_error "No command specified"
        show_help
        exit 1
    fi
}

# Get database configuration based on environment
get_db_config() {
    case $ENVIRONMENT in
        local)
            DB_TYPE="h2"
            DB_URL="jdbc:h2:mem:pricedb;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE"
            DB_USER="sa"
            DB_PASSWORD=""
            DB_DRIVER="org.h2.Driver"
            ;;
        staging)
            DB_TYPE="postgresql"
            DB_URL="jdbc:postgresql://staging-db:5432/priceservice"
            DB_USER="${DB_USER:-priceuser}"
            DB_PASSWORD="${DB_PASSWORD:-pricepass}"
            DB_DRIVER="org.postgresql.Driver"
            ;;
        production)
            DB_TYPE="postgresql"
            DB_URL="${PROD_DB_URL:-jdbc:postgresql://prod-db:5432/priceservice}"
            DB_USER="${PROD_DB_USER:-priceuser}"
            DB_PASSWORD="${PROD_DB_PASSWORD}"
            DB_DRIVER="org.postgresql.Driver"
            
            if [[ -z "$DB_PASSWORD" ]]; then
                log_error "Production database password not set. Set PROD_DB_PASSWORD environment variable."
                exit 1
            fi
            ;;
        *)
            log_error "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
}

# Check if required tools are available
check_prerequisites() {
    cd "$PROJECT_ROOT"
    
    # Check Gradle wrapper
    if [[ ! -x "./gradlew" ]]; then
        log_error "Gradle wrapper not found. Run setup-environment.sh first."
        exit 1
    fi
    
    # Check database-specific tools
    case $DB_TYPE in
        postgresql)
            if ! command -v psql >/dev/null 2>&1; then
                log_warning "psql not found. Some operations may not work."
            fi
            ;;
        h2)
            # H2 is embedded, no external tool needed
            ;;
    esac
}

# Create migrations directory structure
create_migration_structure() {
    log_info "Creating migration directory structure..."
    
    mkdir -p src/main/resources/db/migration
    mkdir -p src/main/resources/db/data
    mkdir -p scripts/migrations
    mkdir -p backups
    
    # Create migration tracking table script
    cat > src/main/resources/db/migration/V1__Create_schema.sql << 'EOF'
-- Initial schema creation for TestJava Price Service
-- Migration: V1__Create_schema.sql

CREATE TABLE IF NOT EXISTS prices (
    id BIGINT PRIMARY KEY,
    brand_id INTEGER NOT NULL,
    product_id BIGINT NOT NULL,
    price_list INTEGER NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'EUR'
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_prices_brand_product ON prices(brand_id, product_id);
CREATE INDEX IF NOT EXISTS idx_prices_dates ON prices(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_prices_price_list ON prices(price_list);

-- Migration metadata table
CREATE TABLE IF NOT EXISTS migration_history (
    id SERIAL PRIMARY KEY,
    version VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_time_ms INTEGER,
    success BOOLEAN DEFAULT true
);
EOF
    
    log_success "Migration structure created"
}

# Initialize database
init_database() {
    log_info "Initializing database for environment: $ENVIRONMENT"
    
    get_db_config
    check_prerequisites
    create_migration_structure
    
    cd "$PROJECT_ROOT"
    
    case $DB_TYPE in
        h2)
            # H2 database initialization
            log_info "Initializing H2 database..."
            ./gradlew flywayMigrate -Dflyway.url="$DB_URL" \
                                  -Dflyway.user="$DB_USER" \
                                  -Dflyway.password="$DB_PASSWORD"
            ;;
        postgresql)
            # PostgreSQL database initialization
            log_info "Initializing PostgreSQL database..."
            
            if [[ "$ENVIRONMENT" == "production" ]] && [[ "$ASSUME_YES" != "true" ]]; then
                log_warning "You are about to initialize the PRODUCTION database!"
                read -p "Are you sure? (yes/no): " confirm
                if [[ "$confirm" != "yes" ]]; then
                    log_info "Operation cancelled"
                    exit 0
                fi
            fi
            
            # Create database if it doesn't exist
            create_database_if_not_exists
            
            # Run migrations
            ./gradlew flywayMigrate -Dflyway.url="$DB_URL" \
                                  -Dflyway.user="$DB_USER" \
                                  -Dflyway.password="$DB_PASSWORD"
            ;;
    esac
    
    # Load initial data
    seed_database
    
    log_success "Database initialization completed"
}

# Create database if it doesn't exist (PostgreSQL)
create_database_if_not_exists() {
    if [[ "$DB_TYPE" == "postgresql" ]]; then
        log_info "Checking if database exists..."
        
        # Extract database name from URL
        DB_NAME=$(echo "$DB_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
        DB_HOST=$(echo "$DB_URL" | sed -n 's/.*:\/\/\([^:]*\).*/\1/p')
        DB_PORT=$(echo "$DB_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
        
        # Check if database exists
        if command -v psql >/dev/null 2>&1; then
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"
            if [[ $? -ne 0 ]]; then
                log_info "Creating database: $DB_NAME"
                PGPASSWORD="$DB_PASSWORD" createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
            fi
        else
            log_warning "psql not available. Assuming database exists."
        fi
    fi
}

# Run database migrations
migrate_database() {
    log_info "Running database migrations for environment: $ENVIRONMENT"
    
    get_db_config
    check_prerequisites
    
    cd "$PROJECT_ROOT"
    
    if [[ "$ENVIRONMENT" == "production" ]] && [[ "$ASSUME_YES" != "true" ]]; then
        log_warning "You are about to run migrations on PRODUCTION database!"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Migration cancelled"
            exit 0
        fi
    fi
    
    ./gradlew flywayMigrate -Dflyway.url="$DB_URL" \
                          -Dflyway.user="$DB_USER" \
                          -Dflyway.password="$DB_PASSWORD"
    
    log_success "Database migrations completed"
}

# Rollback last migration
rollback_database() {
    log_info "Rolling back last migration for environment: $ENVIRONMENT"
    
    get_db_config
    check_prerequisites
    
    cd "$PROJECT_ROOT"
    
    if [[ "$ENVIRONMENT" == "production" ]] && [[ "$ASSUME_YES" != "true" ]]; then
        log_warning "You are about to rollback PRODUCTION database!"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Rollback cancelled"
            exit 0
        fi
    fi
    
    # Show current migration status first
    ./gradlew flywayInfo -Dflyway.url="$DB_URL" \
                        -Dflyway.user="$DB_USER" \
                        -Dflyway.password="$DB_PASSWORD"
    
    # Undo last migration
    ./gradlew flywayUndo -Dflyway.url="$DB_URL" \
                        -Dflyway.user="$DB_USER" \
                        -Dflyway.password="$DB_PASSWORD"
    
    log_success "Database rollback completed"
}

# Reset database
reset_database() {
    log_info "Resetting database for environment: $ENVIRONMENT"
    
    get_db_config
    
    if [[ "$ENVIRONMENT" == "production" ]]; then
        log_error "Database reset is not allowed in production environment!"
        exit 1
    fi
    
    if [[ "$ASSUME_YES" != "true" ]]; then
        log_warning "This will completely reset the database!"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Reset cancelled"
            exit 0
        fi
    fi
    
    cd "$PROJECT_ROOT"
    
    # Clean database
    ./gradlew flywayClean -Dflyway.url="$DB_URL" \
                         -Dflyway.user="$DB_USER" \
                         -Dflyway.password="$DB_PASSWORD"
    
    # Reinitialize
    init_database
    
    log_success "Database reset completed"
}

# Backup database
backup_database() {
    log_info "Creating backup for environment: $ENVIRONMENT"
    
    get_db_config
    
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_filename="backups/backup_${ENVIRONMENT}_${backup_timestamp}.sql"
    
    mkdir -p backups
    
    case $DB_TYPE in
        h2)
            log_warning "H2 backup not implemented (in-memory database)"
            ;;
        postgresql)
            if command -v pg_dump >/dev/null 2>&1; then
                local db_name=$(echo "$DB_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
                local db_host=$(echo "$DB_URL" | sed -n 's/.*:\/\/\([^:]*\).*/\1/p')
                local db_port=$(echo "$DB_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
                
                log_info "Creating PostgreSQL backup: $backup_filename"
                PGPASSWORD="$DB_PASSWORD" pg_dump -h "$db_host" -p "$db_port" -U "$DB_USER" \
                                                 -f "$backup_filename" "$db_name"
                
                # Compress backup
                gzip "$backup_filename"
                backup_filename="${backup_filename}.gz"
                
                log_success "Backup created: $backup_filename"
            else
                log_error "pg_dump not available. Cannot create backup."
                exit 1
            fi
            ;;
    esac
}

# Restore database
restore_database() {
    if [[ -z "$BACKUP_FILE" ]]; then
        log_error "Backup file not specified. Use -b option."
        exit 1
    fi
    
    if [[ ! -f "$BACKUP_FILE" ]]; then
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    log_info "Restoring database from backup: $BACKUP_FILE"
    
    get_db_config
    
    if [[ "$ENVIRONMENT" == "production" ]] && [[ "$ASSUME_YES" != "true" ]]; then
        log_warning "You are about to restore PRODUCTION database!"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Restore cancelled"
            exit 0
        fi
    fi
    
    case $DB_TYPE in
        h2)
            log_warning "H2 restore not implemented (in-memory database)"
            ;;
        postgresql)
            if command -v psql >/dev/null 2>&1; then
                local db_name=$(echo "$DB_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
                local db_host=$(echo "$DB_URL" | sed -n 's/.*:\/\/\([^:]*\).*/\1/p')
                local db_port=$(echo "$DB_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
                
                # Check if backup is compressed
                if [[ "$BACKUP_FILE" == *.gz ]]; then
                    log_info "Decompressing backup file..."
                    gunzip -c "$BACKUP_FILE" | PGPASSWORD="$DB_PASSWORD" psql -h "$db_host" -p "$db_port" -U "$DB_USER" "$db_name"
                else
                    PGPASSWORD="$DB_PASSWORD" psql -h "$db_host" -p "$db_port" -U "$DB_USER" "$db_name" < "$BACKUP_FILE"
                fi
                
                log_success "Database restore completed"
            else
                log_error "psql not available. Cannot restore backup."
                exit 1
            fi
            ;;
    esac
}

# Show migration status
show_migration_status() {
    log_info "Migration status for environment: $ENVIRONMENT"
    
    get_db_config
    check_prerequisites
    
    cd "$PROJECT_ROOT"
    
    ./gradlew flywayInfo -Dflyway.url="$DB_URL" \
                        -Dflyway.user="$DB_USER" \
                        -Dflyway.password="$DB_PASSWORD"
}

# Seed database with test data
seed_database() {
    log_info "Seeding database with test data..."
    
    local seed_file="${SQL_FILE:-src/main/resources/data.sql}"
    
    if [[ -f "$seed_file" ]]; then
        log_info "Loading seed data from: $seed_file"
        
        case $DB_TYPE in
            h2)
                # H2 will automatically load data.sql
                log_info "H2 will automatically load seed data on startup"
                ;;
            postgresql)
                if command -v psql >/dev/null 2>&1; then
                    local db_name=$(echo "$DB_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
                    local db_host=$(echo "$DB_URL" | sed -n 's/.*:\/\/\([^:]*\).*/\1/p')
                    local db_port=$(echo "$DB_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
                    
                    PGPASSWORD="$DB_PASSWORD" psql -h "$db_host" -p "$db_port" -U "$DB_USER" "$db_name" < "$seed_file"
                else
                    log_warning "psql not available. Cannot load seed data."
                fi
                ;;
        esac
        
        log_success "Seed data loaded successfully"
    else
        log_info "No seed data file found: $seed_file"
    fi
}

# Main execution
main() {
    log_info "🗄️ TestJava Price Service Database Management"
    
    parse_arguments "$@"
    
    case $COMMAND in
        init)
            init_database
            ;;
        migrate)
            migrate_database
            ;;
        rollback)
            rollback_database
            ;;
        reset)
            reset_database
            ;;
        backup)
            backup_database
            ;;
        restore)
            restore_database
            ;;
        status)
            show_migration_status
            ;;
        seed)
            seed_database
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
    
    log_success "🎉 Database operation completed successfully!"
}

# Execute main function
main "$@"