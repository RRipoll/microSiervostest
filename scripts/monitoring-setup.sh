#!/bin/bash

# Monitoring and observability setup script for TestJava Price Service
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
Monitoring Setup Script for TestJava Price Service

Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
    setup-prometheus    Set up Prometheus monitoring
    setup-grafana       Set up Grafana dashboards
    setup-alerting      Set up alerting rules
    setup-logging       Set up centralized logging
    setup-tracing       Set up distributed tracing
    setup-all           Set up complete monitoring stack
    health-check        Check monitoring services health

OPTIONS:
    -e, --env ENV       Environment (local, staging, production) [default: local]
    -p, --port PORT     Custom port for services
    -f, --force         Force reinstallation
    -h, --help          Show this help

EXAMPLES:
    $0 setup-all                   # Set up complete monitoring stack
    $0 setup-prometheus            # Set up only Prometheus
    $0 setup-grafana --env staging # Set up Grafana for staging
    $0 health-check               # Check all services
EOF
}

# Default values
ENVIRONMENT="local"
FORCE_INSTALL=false
CUSTOM_PORT=""
COMMAND=""

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -p|--port)
                CUSTOM_PORT="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            setup-prometheus|setup-grafana|setup-alerting|setup-logging|setup-tracing|setup-all|health-check)
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

# Create monitoring directory structure
create_monitoring_structure() {
    log_info "Creating monitoring directory structure..."
    
    mkdir -p config/monitoring/{prometheus,grafana,alertmanager,jaeger}
    mkdir -p config/monitoring/grafana/{dashboards,datasources,provisioning}
    mkdir -p docker/monitoring
    mkdir -p logs
    
    log_success "Monitoring directory structure created"
}

# Setup Prometheus
setup_prometheus() {
    log_info "Setting up Prometheus monitoring..."
    
    create_monitoring_structure
    
    # Create Prometheus configuration
    cat > config/monitoring/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'testjava-priceservice'
    static_configs:
      - targets: ['priceservice:8080']
    metrics_path: '/actuator/prometheus'
    scrape_interval: 10s
    scrape_timeout: 5s
    
  - job_name: 'spring-boot-actuator'
    static_configs:
      - targets: ['priceservice:8080']
    metrics_path: '/actuator/metrics'
    scrape_interval: 15s
    
  - job_name: 'jvm-metrics'
    static_configs:
      - targets: ['priceservice:8080']
    metrics_path: '/actuator/prometheus'
    scrape_interval: 10s
    params:
      'match[]':
        - '{__name__=~"jvm_.*"}'
        
  - job_name: 'http-metrics'
    static_configs:
      - targets: ['priceservice:8080']
    metrics_path: '/actuator/prometheus'
    scrape_interval: 5s
    params:
      'match[]':
        - '{__name__=~"http_.*"}'

  - job_name: 'database-metrics'
    static_configs:
      - targets: ['priceservice:8080']
    metrics_path: '/actuator/prometheus'
    scrape_interval: 15s
    params:
      'match[]':
        - '{__name__=~".*hikari.*"}'
        - '{__name__=~".*jdbc.*"}'
EOF
    
    # Create alert rules
    cat > config/monitoring/prometheus/alert_rules.yml << EOF
groups:
  - name: testjava-priceservice
    rules:
      - alert: ServiceDown
        expr: up{job="testjava-priceservice"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "TestJava PriceService is down"
          description: "TestJava PriceService has been down for more than 1 minute."

      - alert: HighErrorRate
        expr: rate(http_server_requests_seconds_count{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ \$value }} errors per second"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le)) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time"
          description: "95th percentile response time is {{ \$value }} seconds"

      - alert: HighMemoryUsage
        expr: jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ \$value | humanizePercentage }}"

      - alert: HighCPUUsage
        expr: process_cpu_usage > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is {{ \$value | humanizePercentage }}"

      - alert: DatabaseConnectionPoolExhausted
        expr: hikaricp_connections_active >= hikaricp_connections_max
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Database connection pool exhausted"
          description: "All database connections are in use"
EOF
    
    log_success "Prometheus configuration created"
}

# Setup Grafana
setup_grafana() {
    log_info "Setting up Grafana dashboards..."
    
    create_monitoring_structure
    
    # Create Grafana datasource configuration
    cat > config/monitoring/grafana/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://prometheus:9090
    basicAuth: false
    isDefault: true
    version: 1
    editable: true
    jsonData:
      httpMethod: POST
      queryTimeout: 60s
      timeInterval: 5s
EOF
    
    # Create application dashboard
    cat > config/monitoring/grafana/dashboards/priceservice-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "TestJava PriceService - Overview",
    "tags": ["priceservice", "spring-boot"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_server_requests_seconds_count[5m])",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "label": "requests/sec"
          }
        ],
        "xAxes": [
          {
            "type": "time"
          }
        ]
      },
      {
        "id": 2,
        "title": "Response Time (95th percentile)",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le))",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "label": "seconds"
          }
        ]
      },
      {
        "id": 3,
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_server_requests_seconds_count{status=~\"5..\"}[5m])",
            "refId": "A"
          }
        ],
        "yAxes": [
          {
            "label": "errors/sec"
          }
        ]
      },
      {
        "id": 4,
        "title": "JVM Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "jvm_memory_used_bytes{area=\"heap\"}",
            "refId": "A",
            "legendFormat": "Heap Used"
          },
          {
            "expr": "jvm_memory_max_bytes{area=\"heap\"}",
            "refId": "B",
            "legendFormat": "Heap Max"
          }
        ],
        "yAxes": [
          {
            "label": "bytes"
          }
        ]
      },
      {
        "id": 5,
        "title": "Database Connection Pool",
        "type": "graph",
        "targets": [
          {
            "expr": "hikaricp_connections_active",
            "refId": "A",
            "legendFormat": "Active Connections"
          },
          {
            "expr": "hikaricp_connections_idle",
            "refId": "B",
            "legendFormat": "Idle Connections"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
EOF
    
    # Create JVM dashboard
    cat > config/monitoring/grafana/dashboards/jvm-metrics.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "TestJava PriceService - JVM Metrics",
    "tags": ["priceservice", "jvm"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Heap Memory",
        "type": "graph",
        "targets": [
          {
            "expr": "jvm_memory_used_bytes{area=\"heap\"}",
            "refId": "A",
            "legendFormat": "Used"
          },
          {
            "expr": "jvm_memory_committed_bytes{area=\"heap\"}",
            "refId": "B",
            "legendFormat": "Committed"
          },
          {
            "expr": "jvm_memory_max_bytes{area=\"heap\"}",
            "refId": "C",
            "legendFormat": "Max"
          }
        ]
      },
      {
        "id": 2,
        "title": "Garbage Collection",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(jvm_gc_collection_seconds_count[5m])",
            "refId": "A",
            "legendFormat": "{{ gc }}"
          }
        ]
      },
      {
        "id": 3,
        "title": "Thread Count",
        "type": "graph",
        "targets": [
          {
            "expr": "jvm_threads_live_threads",
            "refId": "A",
            "legendFormat": "Live Threads"
          },
          {
            "expr": "jvm_threads_daemon_threads",
            "refId": "B",
            "legendFormat": "Daemon Threads"
          }
        ]
      },
      {
        "id": 4,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "process_cpu_usage",
            "refId": "A",
            "legendFormat": "Process CPU"
          },
          {
            "expr": "system_cpu_usage",
            "refId": "B",
            "legendFormat": "System CPU"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "10s"
  }
}
EOF
    
    # Create dashboard provisioning configuration
    cat > config/monitoring/grafana/provisioning/dashboards.yml << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
    
    log_success "Grafana configuration created"
}

# Setup alerting with AlertManager
setup_alerting() {
    log_info "Setting up AlertManager..."
    
    create_monitoring_structure
    
    # Create AlertManager configuration
    cat > config/monitoring/alertmanager/alertmanager.yml << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@testjava.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
    - match:
        severity: warning
      receiver: 'warning-alerts'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://localhost:5001/'
        
  - name: 'critical-alerts'
    email_configs:
      - to: 'ops-team@testjava.com'
        subject: '[CRITICAL] TestJava PriceService Alert'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#alerts'
        title: 'Critical Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        
  - name: 'warning-alerts'
    email_configs:
      - to: 'dev-team@testjava.com'
        subject: '[WARNING] TestJava PriceService Alert'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF
    
    log_success "AlertManager configuration created"
}

# Setup centralized logging
setup_logging() {
    log_info "Setting up centralized logging..."
    
    create_monitoring_structure
    
    # Create Logback configuration for structured logging
    cat > src/main/resources/logback-spring.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>
    
    <!-- Console appender with colored output -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%clr(%d{yyyy-MM-dd HH:mm:ss.SSS}){faint} %clr(${LOG_LEVEL_PATTERN:-%5p}) %clr(${PID:- }){magenta} %clr(---){faint} %clr([%15.15t]){faint} %clr(%-40.40logger{39}){cyan} %clr(:){faint} %m%n${LOG_EXCEPTION_CONVERSION_WORD:-%wEx}</pattern>
        </encoder>
    </appender>
    
    <!-- File appender for application logs -->
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>logs/priceservice.log</file>
        <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
            <providers>
                <timestamp/>
                <logLevel/>
                <loggerName/>
                <message/>
                <mdc/>
                <arguments/>
                <stackTrace/>
            </providers>
        </encoder>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>logs/priceservice.%d{yyyy-MM-dd}.%i.log</fileNamePattern>
            <maxFileSize>100MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>3GB</totalSizeCap>
        </rollingPolicy>
    </appender>
    
    <!-- Error file appender -->
    <appender name="ERROR_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>logs/priceservice-error.log</file>
        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>ERROR</level>
        </filter>
        <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
            <providers>
                <timestamp/>
                <logLevel/>
                <loggerName/>
                <message/>
                <mdc/>
                <arguments/>
                <stackTrace/>
            </providers>
        </encoder>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>logs/priceservice-error.%d{yyyy-MM-dd}.%i.log</fileNamePattern>
            <maxFileSize>100MB</maxFileSize>
            <maxHistory>30</maxHistory>
        </rollingPolicy>
    </appender>
    
    <!-- Audit log appender -->
    <appender name="AUDIT_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>logs/priceservice-audit.log</file>
        <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
            <providers>
                <timestamp/>
                <message/>
                <mdc/>
                <arguments/>
            </providers>
        </encoder>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>logs/priceservice-audit.%d{yyyy-MM-dd}.%i.log</fileNamePattern>
            <maxFileSize>100MB</maxFileSize>
            <maxHistory>90</maxHistory>
        </rollingPolicy>
    </appender>
    
    <!-- Async appender for performance -->
    <appender name="ASYNC_FILE" class="ch.qos.logback.classic.AsyncAppender">
        <appender-ref ref="FILE"/>
        <queueSize>512</queueSize>
        <discardingThreshold>0</discardingThreshold>
        <includeCallerData>false</includeCallerData>
    </appender>
    
    <!-- Logger configurations -->
    <logger name="com.testjava.priceservice" level="INFO" additivity="false">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="ASYNC_FILE"/>
        <appender-ref ref="ERROR_FILE"/>
    </logger>
    
    <logger name="audit" level="INFO" additivity="false">
        <appender-ref ref="AUDIT_FILE"/>
    </logger>
    
    <logger name="org.springframework" level="WARN"/>
    <logger name="org.hibernate" level="WARN"/>
    <logger name="org.apache" level="WARN"/>
    
    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
    </root>
    
    <springProfile name="local">
        <logger name="com.testjava.priceservice" level="DEBUG"/>
    </springProfile>
    
    <springProfile name="staging,production">
        <logger name="com.testjava.priceservice" level="INFO"/>
    </springProfile>
</configuration>
EOF
    
    log_success "Logging configuration created"
}

# Setup distributed tracing with Jaeger
setup_tracing() {
    log_info "Setting up distributed tracing with Jaeger..."
    
    create_monitoring_structure
    
    # Create Jaeger configuration
    cat > config/monitoring/jaeger/jaeger.yml << EOF
# Jaeger configuration
sampling:
  default_strategy:
    type: probabilistic
    param: 1.0  # Sample 100% in development, reduce in production
    
collector:
  zipkin:
    http-port: 9411

query:
  base-path: /jaeger

storage:
  type: memory  # Use elasticsearch for production
EOF
    
    # Add tracing configuration to application.yml
    cat >> src/main/resources/application.yml << EOF

# Distributed Tracing Configuration
management:
  tracing:
    sampling:
      probability: 1.0  # Sample all traces in development
  zipkin:
    tracing:
      endpoint: http://jaeger:9411/api/v2/spans

spring:
  application:
    name: testjava-priceservice
  sleuth:
    zipkin:
      base-url: http://jaeger:9411
    sampler:
      probability: 1.0
EOF
    
    log_success "Distributed tracing configuration created"
}

# Create Docker Compose for monitoring stack
create_monitoring_docker_compose() {
    log_info "Creating monitoring Docker Compose..."
    
    cat > docker-compose.monitoring.yml << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./config/monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./config/monitoring/alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
      - ./config/monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./config/monitoring/grafana/provisioning:/etc/grafana/provisioning
    restart: unless-stopped
    networks:
      - monitoring

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    ports:
      - "16686:16686"  # Jaeger UI
      - "14268:14268"  # Jaeger collector HTTP
      - "14250:14250"  # Jaeger collector gRPC
      - "9411:9411"    # Zipkin compatible endpoint
    environment:
      - COLLECTOR_ZIPKIN_HTTP_PORT=9411
    restart: unless-stopped
    networks:
      - monitoring

  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - loki_data:/loki
    restart: unless-stopped
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    volumes:
      - ./logs:/var/log/priceservice
      - ./config/monitoring/promtail:/etc/promtail
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  loki_data:

networks:
  monitoring:
    driver: bridge
EOF
    
    log_success "Monitoring Docker Compose created"
}

# Health check for monitoring services
health_check() {
    log_info "Performing health check on monitoring services..."
    
    local services=("prometheus:9090" "grafana:3000" "jaeger:16686" "alertmanager:9093")
    local failed_services=()
    
    for service in "${services[@]}"; do
        local name=$(echo "$service" | cut -d: -f1)
        local port=$(echo "$service" | cut -d: -f2)
        
        log_info "Checking $name service..."
        
        if curl -f "http://localhost:$port" >/dev/null 2>&1; then
            log_success "$name is healthy"
        else
            log_error "$name is not responding"
            failed_services+=("$name")
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_success "All monitoring services are healthy"
    else
        log_error "Failed services: ${failed_services[*]}"
        exit 1
    fi
}

# Setup complete monitoring stack
setup_all() {
    log_info "Setting up complete monitoring stack..."
    
    setup_prometheus
    setup_grafana
    setup_alerting
    setup_logging
    setup_tracing
    create_monitoring_docker_compose
    
    log_success "Complete monitoring stack setup completed"
    log_info "To start the monitoring stack:"
    log_info "  docker-compose -f docker-compose.monitoring.yml up -d"
    log_info ""
    log_info "Access points:"
    log_info "  - Prometheus: http://localhost:9090"
    log_info "  - Grafana: http://localhost:3000 (admin/admin)"
    log_info "  - Jaeger: http://localhost:16686"
    log_info "  - AlertManager: http://localhost:9093"
}

# Main execution
main() {
    log_info "🔍 TestJava Price Service Monitoring Setup"
    
    parse_arguments "$@"
    
    case $COMMAND in
        setup-prometheus)
            setup_prometheus
            ;;
        setup-grafana)
            setup_grafana
            ;;
        setup-alerting)
            setup_alerting
            ;;
        setup-logging)
            setup_logging
            ;;
        setup-tracing)
            setup_tracing
            ;;
        setup-all)
            setup_all
            ;;
        health-check)
            health_check
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
    
    log_success "🎉 Monitoring setup completed successfully!"
}

# Execute main function
main "$@"