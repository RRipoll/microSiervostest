#!/bin/bash

# Health check script for TestJava Price Service deployment
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
Health Check Script for TestJava Price Service

Usage: $0 [OPTIONS]

OPTIONS:
    -e, --env ENV       Environment to check (local, staging, production) [default: local]
    -t, --timeout SEC   Timeout for health checks in seconds [default: 30]
    -r, --retry COUNT   Number of retries for failed checks [default: 3]
    -v, --verbose       Verbose output
    -q, --quiet         Quiet mode (only errors)
    --deep              Perform deep health checks
    --report            Generate health report
    -h, --help          Show this help

EXAMPLES:
    $0                          # Basic health check for local environment
    $0 --env production --deep  # Deep health check for production
    $0 --report                 # Generate health report
    $0 --timeout 60 --retry 5   # Custom timeout and retry settings
EOF
}

# Default values
ENVIRONMENT="local"
TIMEOUT=30
RETRY_COUNT=3
VERBOSE=false
QUIET=false
DEEP_CHECK=false
GENERATE_REPORT=false

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -r|--retry)
                RETRY_COUNT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --deep)
                DEEP_CHECK=true
                shift
                ;;
            --report)
                GENERATE_REPORT=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Configuration based on environment
configure_environment() {
    case $ENVIRONMENT in
        local)
            APP_URL="http://localhost:8080"
            DB_HOST="localhost"
            DB_PORT="5432"
            REDIS_HOST="localhost"
            REDIS_PORT="6379"
            ;;
        staging)
            APP_URL="${STAGING_URL:-http://staging.testjava.com}"
            DB_HOST="${STAGING_DB_HOST:-staging-db}"
            DB_PORT="${STAGING_DB_PORT:-5432}"
            REDIS_HOST="${STAGING_REDIS_HOST:-staging-redis}"
            REDIS_PORT="${STAGING_REDIS_PORT:-6379}"
            ;;
        production)
            APP_URL="${PROD_URL:-http://priceservice.testjava.com}"
            DB_HOST="${PROD_DB_HOST:-prod-db}"
            DB_PORT="${PROD_DB_PORT:-5432}"
            REDIS_HOST="${PROD_REDIS_HOST:-prod-redis}"
            REDIS_PORT="${PROD_REDIS_PORT:-6379}"
            ;;
        *)
            log_error "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
    
    [[ "$VERBOSE" == "true" ]] && log_info "Configured for $ENVIRONMENT environment"
}

# Health check results
HEALTH_RESULTS=()
FAILED_CHECKS=()

# Record health check result
record_result() {
    local service="$1"
    local status="$2"
    local message="$3"
    local response_time="${4:-N/A}"
    
    HEALTH_RESULTS+=("$service|$status|$message|$response_time")
    
    if [[ "$status" != "HEALTHY" ]]; then
        FAILED_CHECKS+=("$service: $message")
    fi
}

# HTTP health check with retry
http_health_check() {
    local url="$1"
    local service_name="$2"
    local expected_status="${3:-200}"
    local retry_count="$RETRY_COUNT"
    
    [[ "$VERBOSE" == "true" ]] && log_info "Checking $service_name at $url"
    
    for ((i=1; i<=retry_count; i++)); do
        local start_time=$(date +%s.%N)
        local response=$(curl -s -w "HTTPSTATUS:%{http_code};TIME:%{time_total}" \
                            --max-time "$TIMEOUT" \
                            --connect-timeout 10 \
                            "$url" 2>/dev/null || echo "HTTPSTATUS:000;TIME:0")
        
        local http_status=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
        local response_time=$(echo "$response" | grep -o "TIME:[0-9.]*" | cut -d: -f2)
        local body=$(echo "$response" | sed -E 's/HTTPSTATUS:[0-9]*;TIME:[0-9.]*$//')
        
        if [[ "$http_status" == "$expected_status" ]]; then
            record_result "$service_name" "HEALTHY" "Responded with status $http_status" "${response_time}s"
            [[ "$QUIET" != "true" ]] && log_success "$service_name is healthy (${response_time}s)"
            return 0
        elif [[ "$http_status" == "000" ]]; then
            [[ "$VERBOSE" == "true" ]] && log_warning "$service_name check failed (attempt $i/$retry_count): Connection failed"
        else
            [[ "$VERBOSE" == "true" ]] && log_warning "$service_name check failed (attempt $i/$retry_count): HTTP $http_status"
        fi
        
        if [[ $i -lt $retry_count ]]; then
            sleep 2
        fi
    done
    
    record_result "$service_name" "UNHEALTHY" "Failed after $retry_count attempts (HTTP: $http_status)" "${response_time}s"
    log_error "$service_name is unhealthy after $retry_count attempts"
    return 1
}

# TCP port health check
tcp_health_check() {
    local host="$1"
    local port="$2"
    local service_name="$3"
    local retry_count="$RETRY_COUNT"
    
    [[ "$VERBOSE" == "true" ]] && log_info "Checking TCP connectivity to $service_name at $host:$port"
    
    for ((i=1; i<=retry_count; i++)); do
        if timeout "$TIMEOUT" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            record_result "$service_name" "HEALTHY" "TCP connection successful" "N/A"
            [[ "$QUIET" != "true" ]] && log_success "$service_name TCP connection is healthy"
            return 0
        fi
        
        [[ "$VERBOSE" == "true" ]] && log_warning "$service_name TCP check failed (attempt $i/$retry_count)"
        
        if [[ $i -lt $retry_count ]]; then
            sleep 2
        fi
    done
    
    record_result "$service_name" "UNHEALTHY" "TCP connection failed after $retry_count attempts" "N/A"
    log_error "$service_name TCP connection is unhealthy"
    return 1
}

# Application health checks
check_application_health() {
    log_info "Checking application health..."
    
    # Basic health endpoint
    http_health_check "$APP_URL/actuator/health" "Application Health"
    
    # Readiness probe
    http_health_check "$APP_URL/actuator/health/readiness" "Application Readiness"
    
    # Liveness probe
    http_health_check "$APP_URL/actuator/health/liveness" "Application Liveness"
    
    if [[ "$DEEP_CHECK" == "true" ]]; then
        # Info endpoint
        http_health_check "$APP_URL/actuator/info" "Application Info"
        
        # Metrics endpoint
        http_health_check "$APP_URL/actuator/metrics" "Application Metrics"
        
        # API endpoint test
        http_health_check "$APP_URL/api/v1/prices/search?brandId=1&productId=35455&date=2020-06-14T10:00:00" "Price API"
    fi
}

# Database health checks
check_database_health() {
    log_info "Checking database health..."
    
    # TCP connectivity check
    tcp_health_check "$DB_HOST" "$DB_PORT" "Database"
    
    if [[ "$DEEP_CHECK" == "true" ]] && command -v psql >/dev/null 2>&1; then
        # Database query check
        local db_check_query="SELECT 1"
        if PGPASSWORD="$DB_PASSWORD" timeout "$TIMEOUT" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$db_check_query" >/dev/null 2>&1; then
            record_result "Database Query" "HEALTHY" "Query execution successful" "N/A"
            [[ "$QUIET" != "true" ]] && log_success "Database query check passed"
        else
            record_result "Database Query" "UNHEALTHY" "Query execution failed" "N/A"
            log_error "Database query check failed"
        fi
        
        # Table existence check
        local table_check_query="SELECT COUNT(*) FROM prices"
        if PGPASSWORD="$DB_PASSWORD" timeout "$TIMEOUT" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$table_check_query" >/dev/null 2>&1; then
            record_result "Database Schema" "HEALTHY" "Tables are accessible" "N/A"
            [[ "$QUIET" != "true" ]] && log_success "Database schema check passed"
        else
            record_result "Database Schema" "UNHEALTHY" "Tables are not accessible" "N/A"
            log_error "Database schema check failed"
        fi
    fi
}

# Redis health checks
check_redis_health() {
    log_info "Checking Redis health..."
    
    # TCP connectivity check
    tcp_health_check "$REDIS_HOST" "$REDIS_PORT" "Redis"
    
    if [[ "$DEEP_CHECK" == "true" ]] && command -v redis-cli >/dev/null 2>&1; then
        # Redis ping check
        if timeout "$TIMEOUT" redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1; then
            record_result "Redis Ping" "HEALTHY" "Redis responding to ping" "N/A"
            [[ "$QUIET" != "true" ]] && log_success "Redis ping check passed"
        else
            record_result "Redis Ping" "UNHEALTHY" "Redis not responding to ping" "N/A"
            log_error "Redis ping check failed"
        fi
    fi
}

# Docker containers health check
check_docker_health() {
    if ! command -v docker >/dev/null 2>&1; then
        [[ "$VERBOSE" == "true" ]] && log_info "Docker not available, skipping container health checks"
        return 0
    fi
    
    log_info "Checking Docker containers health..."
    
    local containers=("testjava-priceservice" "postgres" "redis" "nginx")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            
            case $status in
                "healthy")
                    record_result "Container $container" "HEALTHY" "Container is healthy" "N/A"
                    [[ "$QUIET" != "true" ]] && log_success "Container $container is healthy"
                    ;;
                "unhealthy")
                    record_result "Container $container" "UNHEALTHY" "Container is unhealthy" "N/A"
                    log_error "Container $container is unhealthy"
                    ;;
                "starting")
                    record_result "Container $container" "STARTING" "Container is starting" "N/A"
                    [[ "$QUIET" != "true" ]] && log_warning "Container $container is still starting"
                    ;;
                "no-healthcheck")
                    # Check if container is running
                    if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
                        record_result "Container $container" "RUNNING" "Container is running (no health check)" "N/A"
                        [[ "$QUIET" != "true" ]] && log_info "Container $container is running"
                    else
                        record_result "Container $container" "STOPPED" "Container is not running" "N/A"
                        log_error "Container $container is not running"
                    fi
                    ;;
            esac
        else
            record_result "Container $container" "NOT_FOUND" "Container is not running" "N/A"
            log_error "Container $container is not found or not running"
        fi
    done
}

# Performance health checks
check_performance() {
    if [[ "$DEEP_CHECK" != "true" ]]; then
        return 0
    fi
    
    log_info "Checking application performance..."
    
    # Memory usage check
    local memory_endpoint="$APP_URL/actuator/metrics/jvm.memory.used"
    if response=$(curl -s --max-time "$TIMEOUT" "$memory_endpoint" 2>/dev/null); then
        local memory_used=$(echo "$response" | grep -o '"value":[0-9]*' | head -1 | cut -d: -f2)
        if [[ -n "$memory_used" ]] && [[ "$memory_used" -gt 0 ]]; then
            # Convert to MB
            local memory_mb=$((memory_used / 1024 / 1024))
            if [[ "$memory_mb" -lt 400 ]]; then
                record_result "Memory Usage" "HEALTHY" "Memory usage: ${memory_mb}MB" "N/A"
                [[ "$QUIET" != "true" ]] && log_success "Memory usage is healthy: ${memory_mb}MB"
            else
                record_result "Memory Usage" "WARNING" "Memory usage high: ${memory_mb}MB" "N/A"
                log_warning "Memory usage is high: ${memory_mb}MB"
            fi
        fi
    fi
    
    # CPU usage check
    local cpu_endpoint="$APP_URL/actuator/metrics/process.cpu.usage"
    if response=$(curl -s --max-time "$TIMEOUT" "$cpu_endpoint" 2>/dev/null); then
        local cpu_usage=$(echo "$response" | grep -o '"value":[0-9.]*' | head -1 | cut -d: -f2)
        if [[ -n "$cpu_usage" ]]; then
            local cpu_percent=$(echo "$cpu_usage * 100" | bc -l 2>/dev/null | cut -d. -f1)
            if [[ "$cpu_percent" -lt 80 ]]; then
                record_result "CPU Usage" "HEALTHY" "CPU usage: ${cpu_percent}%" "N/A"
                [[ "$QUIET" != "true" ]] && log_success "CPU usage is healthy: ${cpu_percent}%"
            else
                record_result "CPU Usage" "WARNING" "CPU usage high: ${cpu_percent}%" "N/A"
                log_warning "CPU usage is high: ${cpu_percent}%"
            fi
        fi
    fi
}

# Generate health report
generate_health_report() {
    local report_file="health-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
TestJava Price Service Health Report
=====================================
Generated: $(date)
Environment: $ENVIRONMENT
Timeout: ${TIMEOUT}s
Retry Count: $RETRY_COUNT

Health Check Results:
EOF
    
    printf "%-25s %-12s %-40s %-15s\n" "Service" "Status" "Message" "Response Time" >> "$report_file"
    printf "%-25s %-12s %-40s %-15s\n" "-------" "------" "-------" "-------------" >> "$report_file"
    
    for result in "${HEALTH_RESULTS[@]}"; do
        IFS='|' read -r service status message response_time <<< "$result"
        printf "%-25s %-12s %-40s %-15s\n" "$service" "$status" "$message" "$response_time" >> "$report_file"
    done
    
    if [[ ${#FAILED_CHECKS[@]} -gt 0 ]]; then
        cat >> "$report_file" << EOF

Failed Checks:
--------------
EOF
        for failure in "${FAILED_CHECKS[@]}"; do
            echo "- $failure" >> "$report_file"
        done
    fi
    
    cat >> "$report_file" << EOF

Summary:
--------
Total Checks: ${#HEALTH_RESULTS[@]}
Failed Checks: ${#FAILED_CHECKS[@]}
Success Rate: $(echo "scale=1; (${#HEALTH_RESULTS[@]} - ${#FAILED_CHECKS[@]}) * 100 / ${#HEALTH_RESULTS[@]}" | bc -l 2>/dev/null || echo "N/A")%

EOF
    
    log_info "Health report generated: $report_file"
}

# Print summary
print_summary() {
    if [[ "$QUIET" == "true" ]]; then
        return 0
    fi
    
    echo
    log_info "Health Check Summary"
    log_info "==================="
    log_info "Total checks: ${#HEALTH_RESULTS[@]}"
    log_info "Failed checks: ${#FAILED_CHECKS[@]}"
    
    if [[ ${#FAILED_CHECKS[@]} -eq 0 ]]; then
        log_success "All health checks passed!"
        return 0
    else
        log_error "Some health checks failed:"
        for failure in "${FAILED_CHECKS[@]}"; do
            log_error "  - $failure"
        done
        return 1
    fi
}

# Main execution
main() {
    log_info "🏥 TestJava Price Service Health Check"
    
    parse_arguments "$@"
    configure_environment
    
    # Perform health checks
    check_application_health
    check_database_health
    check_redis_health
    
    if command -v docker >/dev/null 2>&1; then
        check_docker_health
    fi
    
    check_performance
    
    # Generate report if requested
    if [[ "$GENERATE_REPORT" == "true" ]]; then
        generate_health_report
    fi
    
    # Print summary and exit with appropriate code
    if print_summary; then
        log_success "🎉 All systems are healthy!"
        exit 0
    else
        log_error "💥 Some systems are unhealthy!"
        exit 1
    fi
}

# Execute main function
main "$@"