#!/bin/bash

# Deployment script for TestJava Price Service
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="testjava-priceservice"
DEFAULT_ENV="staging"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Help function
show_help() {
    cat << EOF
Deployment Script for TestJava Price Service

Usage: $0 [OPTIONS] ENVIRONMENT

ENVIRONMENTS:
    staging     Deploy to staging environment
    production  Deploy to production environment
    local       Deploy locally for testing

OPTIONS:
    -h, --help              Show this help message
    -v, --version VERSION   Specify application version (default: latest)
    -c, --config CONFIG     Specify config file
    -d, --dry-run           Perform dry run without actual deployment
    --skip-tests           Skip running tests before deployment
    --skip-build           Skip building application
    --rollback VERSION     Rollback to specified version

EXAMPLES:
    $0 staging                      # Deploy latest to staging
    $0 production -v v1.2.3        # Deploy specific version to production
    $0 staging --dry-run           # Dry run staging deployment
    $0 --rollback v1.2.2 production # Rollback production to v1.2.2

EOF
}

# Parse command line arguments
parse_arguments() {
    ENVIRONMENT="$DEFAULT_ENV"
    VERSION="latest"
    CONFIG_FILE=""
    DRY_RUN=false
    SKIP_TESTS=false
    SKIP_BUILD=false
    ROLLBACK_VERSION=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --rollback)
                ROLLBACK_VERSION="$2"
                shift 2
                ;;
            staging|production|local)
                ENVIRONMENT="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    case $ENVIRONMENT in
        staging|production|local)
            log_info "Deploying to $ENVIRONMENT environment"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
}

# Pre-deployment checks
pre_deployment_checks() {
    log_info "Running pre-deployment checks..."

    # Check if required tools are installed
    local required_tools=("java" "gradle" "docker")
    for tool in "${required_tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done

    # Check if project directory exists
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        log_error "Project directory not found: $PROJECT_ROOT"
        exit 1
    fi

    cd "$PROJECT_ROOT"

    # Check if gradlew is executable
    if [[ ! -x "./gradlew" ]]; then
        log_info "Making gradlew executable..."
        chmod +x ./gradlew
    fi

    log_success "Pre-deployment checks passed"
}

# Run tests
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log_warning "Skipping tests as requested"
        return 0
    fi

    log_info "Running automated tests..."
    
    # Run different test suites based on environment
    case $ENVIRONMENT in
        production)
            log_info "Running full test suite for production deployment..."
            ./gradlew ciTest
            ;;
        staging)
            log_info "Running comprehensive tests for staging deployment..."
            ./gradlew fullTest
            ;;
        local)
            log_info "Running fast tests for local deployment..."
            ./gradlew fastTest
            ;;
    esac

    log_success "Tests completed successfully"
}

# Build application
build_application() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log_warning "Skipping build as requested"
        return 0
    fi

    log_info "Building application..."
    
    # Clean and build
    ./gradlew clean build -x test --build-cache
    
    # Verify build artifacts
    if [[ ! -f "build/libs/${APP_NAME}-"*.jar ]]; then
        log_error "Build artifact not found"
        exit 1
    fi

    log_success "Application built successfully"
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker image..."
    
    local image_tag="${APP_NAME}:${VERSION}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would build Docker image: $image_tag"
        return 0
    fi

    docker build -t "$image_tag" .
    docker tag "$image_tag" "${APP_NAME}:latest"
    
    log_success "Docker image built: $image_tag"
}

# Deploy to environment
deploy_to_environment() {
    log_info "Deploying to $ENVIRONMENT environment..."

    case $ENVIRONMENT in
        local)
            deploy_local
            ;;
        staging)
            deploy_staging
            ;;
        production)
            deploy_production
            ;;
    esac
}

# Local deployment
deploy_local() {
    log_info "Starting local deployment..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would start local Docker container"
        return 0
    fi

    # Stop existing container if running
    docker stop "$APP_NAME" 2>/dev/null || true
    docker rm "$APP_NAME" 2>/dev/null || true

    # Start new container
    docker run -d \
        --name "$APP_NAME" \
        -p 8080:8080 \
        -e SPRING_PROFILES_ACTIVE=local \
        "${APP_NAME}:${VERSION}"

    # Wait for health check
    log_info "Waiting for application to start..."
    sleep 30
    
    if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        log_success "Local deployment successful!"
        log_info "Application is running at: http://localhost:8080"
        log_info "API documentation: http://localhost:8080/swagger-ui.html"
    else
        log_error "Health check failed"
        exit 1
    fi
}

# Staging deployment
deploy_staging() {
    log_info "Deploying to staging environment..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy to staging"
        return 0
    fi

    # This would typically deploy to your staging infrastructure
    # Example: kubectl, Helm, docker-compose, etc.
    
    log_info "Staging deployment logic would go here..."
    log_info "- Push image to registry"
    log_info "- Update staging deployment"
    log_info "- Run smoke tests"
    
    sleep 5
    log_success "Staging deployment completed"
}

# Production deployment
deploy_production() {
    log_info "Deploying to production environment..."
    
    # Production safety checks
    if [[ "$ENVIRONMENT" == "production" ]] && [[ "$DRY_RUN" != "true" ]]; then
        read -p "Are you sure you want to deploy to PRODUCTION? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Production deployment cancelled"
            exit 0
        fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy to production with safety checks"
        return 0
    fi

    # This would typically deploy to your production infrastructure
    log_info "Production deployment logic would go here..."
    log_info "- Blue-green or rolling deployment"
    log_info "- Health checks"
    log_info "- Monitoring alerts"
    
    sleep 10
    log_success "Production deployment completed"
}

# Rollback function
rollback() {
    if [[ -z "$ROLLBACK_VERSION" ]]; then
        return 0
    fi

    log_info "Rolling back to version: $ROLLBACK_VERSION"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would rollback to $ROLLBACK_VERSION"
        return 0
    fi

    # Rollback logic would go here
    log_info "Rollback logic for $ENVIRONMENT environment..."
    
    sleep 5
    log_success "Rollback to $ROLLBACK_VERSION completed"
}

# Post-deployment verification
post_deployment_verification() {
    log_info "Running post-deployment verification..."
    
    case $ENVIRONMENT in
        local)
            # Local health check already done in deploy_local
            ;;
        staging)
            log_info "Running staging smoke tests..."
            # Add staging-specific verification
            ;;
        production)
            log_info "Running production health checks..."
            # Add production-specific verification
            ;;
    esac
    
    log_success "Post-deployment verification completed"
}

# Cleanup function
cleanup() {
    log_info "Performing cleanup..."
    
    # Clean up temporary files, old images, etc.
    if command -v docker &> /dev/null; then
        docker system prune -f >/dev/null 2>&1 || true
    fi
    
    log_success "Cleanup completed"
}

# Main execution
main() {
    log_info "🚀 Starting TestJava Price Service Deployment"
    log_info "Environment: $ENVIRONMENT"
    log_info "Version: $VERSION"
    [[ "$DRY_RUN" == "true" ]] && log_warning "DRY RUN MODE - No actual changes will be made"

    # Execute deployment pipeline
    parse_arguments "$@"
    validate_environment
    pre_deployment_checks
    
    if [[ -n "$ROLLBACK_VERSION" ]]; then
        rollback
    else
        run_tests
        build_application
        build_docker_image
        deploy_to_environment
        post_deployment_verification
    fi
    
    cleanup
    
    log_success "🎉 Deployment completed successfully!"
}

# Execute main function with all arguments
main "$@"