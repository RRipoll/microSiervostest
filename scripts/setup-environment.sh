#!/bin/bash

# Environment setup script for TestJava Price Service
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
Environment Setup Script for TestJava Price Service

Usage: $0 [ENVIRONMENT] [OPTIONS]

ENVIRONMENTS:
    local       Set up local development environment
    docker      Set up Docker development environment
    k8s         Set up Kubernetes development environment

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Force reinstallation of existing tools
    --skip-docker       Skip Docker setup
    --skip-k8s          Skip Kubernetes setup
    --skip-gradle       Skip Gradle wrapper setup

EXAMPLES:
    $0 local                    # Set up local development
    $0 docker                   # Set up Docker environment
    $0 k8s --skip-docker       # Set up K8s without Docker
EOF
}

# Parse arguments
ENVIRONMENT="local"
FORCE_INSTALL=false
SKIP_DOCKER=false
SKIP_K8S=false
SKIP_GRADLE=false

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --skip-k8s)
                SKIP_K8S=true
                shift
                ;;
            --skip-gradle)
                SKIP_GRADLE=true
                shift
                ;;
            local|docker|k8s)
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Java if needed
setup_java() {
    log_info "Setting up Java environment..."
    
    if command_exists java && [[ "$FORCE_INSTALL" != "true" ]]; then
        local java_version=$(java -version 2>&1 | grep "version" | cut -d'"' -f2)
        log_info "Java is already installed: $java_version"
        
        # Check if it's Java 17+
        if [[ ! "$java_version" =~ ^(17|1[8-9]|[2-9][0-9]) ]]; then
            log_warning "Java 17+ is recommended. Current version: $java_version"
        fi
        return 0
    fi
    
    log_info "Installing Java 17..."
    
    if command_exists apt-get; then
        sudo apt-get update -qq
        sudo apt-get install -y openjdk-17-jdk
    elif command_exists yum; then
        sudo yum install -y java-17-openjdk-devel
    elif command_exists brew; then
        brew install openjdk@17
        echo 'export PATH="/usr/local/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
    else
        log_error "Package manager not found. Please install Java 17 manually."
        exit 1
    fi
    
    log_success "Java installed successfully"
}

# Setup Gradle wrapper
setup_gradle() {
    if [[ "$SKIP_GRADLE" == "true" ]]; then
        log_info "Skipping Gradle setup as requested"
        return 0
    fi
    
    log_info "Setting up Gradle wrapper..."
    cd "$PROJECT_ROOT"
    
    # Download Gradle wrapper if missing
    if [[ ! -f "gradle/wrapper/gradle-wrapper.jar" ]] || [[ "$FORCE_INSTALL" == "true" ]]; then
        log_info "Downloading Gradle wrapper..."
        gradle wrapper --gradle-version 8.4
        chmod +x gradlew
    fi
    
    # Verify Gradle wrapper
    if [[ -x "./gradlew" ]]; then
        ./gradlew --version
        log_success "Gradle wrapper is ready"
    else
        log_error "Gradle wrapper setup failed"
        exit 1
    fi
}

# Setup Docker
setup_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        log_info "Skipping Docker setup as requested"
        return 0
    fi
    
    log_info "Setting up Docker..."
    
    if command_exists docker && [[ "$FORCE_INSTALL" != "true" ]]; then
        log_info "Docker is already installed"
        docker --version
        return 0
    fi
    
    # Install Docker based on OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Install Docker on Linux
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        
        # Install Docker Compose
        if ! command_exists docker-compose; then
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Install Docker on macOS
        if command_exists brew; then
            brew install --cask docker
        else
            log_error "Please install Docker Desktop for Mac manually"
            exit 1
        fi
    else
        log_error "Unsupported OS for automatic Docker installation"
        exit 1
    fi
    
    log_success "Docker setup completed"
    log_warning "You may need to restart your shell or reboot for Docker to work properly"
}

# Setup Kubernetes tools
setup_kubernetes() {
    if [[ "$SKIP_K8S" == "true" ]] || [[ "$ENVIRONMENT" != "k8s" ]]; then
        log_info "Skipping Kubernetes setup"
        return 0
    fi
    
    log_info "Setting up Kubernetes tools..."
    
    # Install kubectl
    if ! command_exists kubectl || [[ "$FORCE_INSTALL" == "true" ]]; then
        log_info "Installing kubectl..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                brew install kubectl
            else
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                sudo install kubectl /usr/local/bin/kubectl
                rm kubectl
            fi
        fi
    fi
    
    # Install Helm
    if ! command_exists helm || [[ "$FORCE_INSTALL" == "true" ]]; then
        log_info "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Install kind for local K8s clusters
    if ! command_exists kind || [[ "$FORCE_INSTALL" == "true" ]]; then
        log_info "Installing kind..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                brew install kind
            else
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            fi
        fi
    fi
    
    log_success "Kubernetes tools installed"
}

# Setup local development environment
setup_local_env() {
    log_info "Setting up local development environment..."
    
    cd "$PROJECT_ROOT"
    
    # Create local config directory
    mkdir -p config/local
    
    # Create local environment file
    cat > config/local/application-local.yml << EOF
spring:
  profiles:
    active: local
  datasource:
    url: jdbc:h2:mem:pricedb;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE
    driver-class-name: org.h2.Driver
    username: sa
    password: ""
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true
    properties:
      hibernate:
        format_sql: true
  h2:
    console:
      enabled: true
      path: /h2-console

management:
  endpoints:
    web:
      exposure:
        include: "*"
  endpoint:
    health:
      show-details: always

logging:
  level:
    com.testjava.priceservice: DEBUG
    org.springframework.web: DEBUG
    org.hibernate.SQL: DEBUG
EOF
    
    log_success "Local development environment configured"
}

# Setup Docker development environment
setup_docker_env() {
    log_info "Setting up Docker development environment..."
    
    cd "$PROJECT_ROOT"
    
    # Create docker-compose for development
    cat > docker-compose.dev.yml << EOF
version: '3.8'

services:
  priceservice:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=docker
      - JAVA_OPTS=-Xmx512m -XX:+UseContainerSupport
    volumes:
      - ./logs:/app/logs
    depends_on:
      - postgres
      - redis
    networks:
      - priceservice-network

  postgres:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=priceservice
      - POSTGRES_USER=priceuser
      - POSTGRES_PASSWORD=pricepass
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - priceservice-network

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - priceservice-network

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - priceservice-network

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana:/etc/grafana/provisioning
    networks:
      - priceservice-network

volumes:
  postgres_data:
  redis_data:
  grafana_data:

networks:
  priceservice-network:
    driver: bridge
EOF
    
    # Create Docker environment config
    mkdir -p config/docker
    cat > config/docker/application-docker.yml << EOF
spring:
  profiles:
    active: docker
  datasource:
    url: jdbc:postgresql://postgres:5432/priceservice
    driver-class-name: org.postgresql.Driver
    username: priceuser
    password: pricepass
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    database-platform: org.hibernate.dialect.PostgreSQLDialect

management:
  endpoints:
    web:
      exposure:
        include: health,prometheus,info,metrics
  endpoint:
    health:
      show-details: always
  metrics:
    export:
      prometheus:
        enabled: true

logging:
  level:
    com.testjava.priceservice: INFO
    org.springframework: WARN
EOF
    
    log_success "Docker development environment configured"
}

# Setup Kubernetes environment
setup_k8s_env() {
    log_info "Setting up Kubernetes environment..."
    
    cd "$PROJECT_ROOT"
    
    # Create kind cluster config
    cat > kind-cluster.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: priceservice-local
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF
    
    # Create Helm chart structure
    mkdir -p helm/testjava-priceservice/{templates,charts}
    
    cat > helm/testjava-priceservice/Chart.yaml << EOF
apiVersion: v2
name: testjava-priceservice
description: A Helm chart for TestJava Price Service
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF
    
    cat > helm/testjava-priceservice/values.yaml << EOF
replicaCount: 2

image:
  repository: testjava-priceservice
  pullPolicy: Always
  tag: "latest"

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  className: "nginx"
  annotations: {}
  hosts:
    - host: priceservice.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}

env:
  SPRING_PROFILES_ACTIVE: "k8s"
  JAVA_OPTS: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
EOF
    
    log_success "Kubernetes environment configured"
}

# Create useful development scripts
create_dev_scripts() {
    log_info "Creating development utility scripts..."
    
    cd "$PROJECT_ROOT"
    mkdir -p scripts/dev
    
    # Create quick start script
    cat > scripts/dev/quick-start.sh << 'EOF'
#!/bin/bash
# Quick start script for local development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

echo "🚀 Starting TestJava Price Service in development mode..."

# Check if Gradle wrapper exists
if [[ ! -x "./gradlew" ]]; then
    echo "❌ Gradle wrapper not found. Run setup-environment.sh first."
    exit 1
fi

# Build and run
echo "🏗️ Building application..."
./gradlew build -x test --build-cache

echo "🔄 Starting application..."
./gradlew bootRun --args='--spring.profiles.active=local'
EOF
    
    # Create test runner script
    cat > scripts/dev/run-tests.sh << 'EOF'
#!/bin/bash
# Test runner script with different test suites

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

TEST_SUITE="${1:-all}"

case $TEST_SUITE in
    unit)
        echo "🧪 Running unit tests..."
        ./gradlew fastTest
        ;;
    integration)
        echo "🔗 Running integration tests..."
        ./gradlew integrationTest
        ;;
    api)
        echo "🌐 Running API tests..."
        ./gradlew validateApi
        ;;
    performance)
        echo "🚀 Running performance tests..."
        ./gradlew performanceTest
        ;;
    all)
        echo "🎯 Running all tests..."
        ./gradlew fullTest
        ;;
    *)
        echo "Usage: $0 [unit|integration|api|performance|all]"
        exit 1
        ;;
esac
EOF
    
    # Create Docker helper script
    cat > scripts/dev/docker-helper.sh << 'EOF'
#!/bin/bash
# Docker development helper script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_ROOT"

ACTION="${1:-help}"

case $ACTION in
    build)
        echo "🐳 Building Docker image..."
        docker build -t testjava-priceservice:dev .
        ;;
    run)
        echo "🚀 Running Docker container..."
        docker run -d --name priceservice-dev -p 8080:8080 testjava-priceservice:dev
        ;;
    stop)
        echo "🛑 Stopping Docker container..."
        docker stop priceservice-dev || true
        docker rm priceservice-dev || true
        ;;
    compose-up)
        echo "🐳 Starting Docker Compose environment..."
        docker-compose -f docker-compose.dev.yml up -d
        ;;
    compose-down)
        echo "🛑 Stopping Docker Compose environment..."
        docker-compose -f docker-compose.dev.yml down
        ;;
    logs)
        echo "📋 Showing container logs..."
        docker logs -f priceservice-dev
        ;;
    help)
        echo "Usage: $0 [build|run|stop|compose-up|compose-down|logs]"
        ;;
    *)
        echo "Unknown action: $ACTION"
        echo "Usage: $0 [build|run|stop|compose-up|compose-down|logs]"
        exit 1
        ;;
esac
EOF
    
    # Make scripts executable
    chmod +x scripts/dev/*.sh
    
    log_success "Development utility scripts created"
}

# Main setup function
main() {
    log_info "🛠️ Setting up TestJava Price Service development environment"
    log_info "Environment: $ENVIRONMENT"
    
    parse_arguments "$@"
    
    # Common setup for all environments
    setup_java
    setup_gradle
    
    # Environment-specific setup
    case $ENVIRONMENT in
        local)
            setup_local_env
            ;;
        docker)
            setup_docker
            setup_docker_env
            ;;
        k8s)
            setup_docker
            setup_kubernetes
            setup_k8s_env
            ;;
    esac
    
    # Create development utilities
    create_dev_scripts
    
    log_success "🎉 Environment setup completed!"
    log_info "Next steps:"
    log_info "  - Run './gradlew build' to build the application"
    log_info "  - Run './scripts/dev/quick-start.sh' to start development"
    log_info "  - Check README.md for more information"
}

# Execute main function
main "$@"