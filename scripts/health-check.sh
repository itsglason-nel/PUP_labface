#!/bin/bash

# LabFace Health Check Script
# This script performs comprehensive health checks on the LabFace system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HEALTH_LOG="logs/health_check.log"
REPORT_FILE="logs/health_report_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${BLUE}LabFace Health Check${NC}"
echo "===================="
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$HEALTH_LOG"
}

# Function to check service health
check_service() {
    local service=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -e "${YELLOW}Checking $service...${NC}"
    
    if curl -f -s "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $service is healthy${NC}"
        log "HEALTHY: $service"
        return 0
    else
        echo -e "${RED}✗ $service is unhealthy${NC}"
        log "UNHEALTHY: $service"
        return 1
    fi
}

# Function to check database connectivity
check_database() {
    echo -e "${YELLOW}Checking database connectivity...${NC}"
    
    if docker-compose exec -T mariadb mysqladmin ping -h localhost --silent; then
        echo -e "${GREEN}✓ Database is accessible${NC}"
        log "DATABASE: Accessible"
        return 0
    else
        echo -e "${RED}✗ Database is not accessible${NC}"
        log "DATABASE: Not accessible"
        return 1
    fi
}

# Function to check database tables
check_database_tables() {
    echo -e "${YELLOW}Checking database tables...${NC}"
    
    local tables=("students" "professors" "classes" "sessions" "attendance" "presence_events")
    local missing_tables=0
    
    for table in "${tables[@]}"; do
        if docker-compose exec -T mariadb mysql -u root -p"$DB_PASSWORD" labface -e "DESCRIBE $table;" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Table $table exists${NC}"
        else
            echo -e "${RED}✗ Table $table missing${NC}"
            ((missing_tables++))
        fi
    done
    
    if [ $missing_tables -eq 0 ]; then
        log "DATABASE: All tables present"
        return 0
    else
        log "DATABASE: $missing_tables tables missing"
        return 1
    fi
}

# Function to check MinIO connectivity
check_minio() {
    echo -e "${YELLOW}Checking MinIO connectivity...${NC}"
    
    if curl -f -s http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        echo -e "${GREEN}✓ MinIO is accessible${NC}"
        log "MINIO: Accessible"
        return 0
    else
        echo -e "${RED}✗ MinIO is not accessible${NC}"
        log "MINIO: Not accessible"
        return 1
    fi
}

# Function to check MinIO bucket
check_minio_bucket() {
    echo -e "${YELLOW}Checking MinIO bucket...${NC}"
    
    if docker-compose exec -T minio mc ls minio/labface > /dev/null 2>&1; then
        echo -e "${GREEN}✓ MinIO bucket 'labface' exists${NC}"
        log "MINIO: Bucket exists"
        return 0
    else
        echo -e "${RED}✗ MinIO bucket 'labface' missing${NC}"
        log "MINIO: Bucket missing"
        return 1
    fi
}

# Function to check container status
check_containers() {
    echo -e "${YELLOW}Checking container status...${NC}"
    
    local unhealthy_containers=$(docker-compose ps --filter "health=unhealthy" --format "table {{.Name}}" | tail -n +2)
    local stopped_containers=$(docker-compose ps --filter "status=exited" --format "table {{.Name}}" | tail -n +2)
    
    if [ -n "$unhealthy_containers" ]; then
        echo -e "${RED}✗ Unhealthy containers: $unhealthy_containers${NC}"
        log "CONTAINERS: Unhealthy - $unhealthy_containers"
        return 1
    fi
    
    if [ -n "$stopped_containers" ]; then
        echo -e "${RED}✗ Stopped containers: $stopped_containers${NC}"
        log "CONTAINERS: Stopped - $stopped_containers"
        return 1
    fi
    
    echo -e "${GREEN}✓ All containers are healthy${NC}"
    log "CONTAINERS: All healthy"
    return 0
}

# Function to check resource usage
check_resources() {
    echo -e "${YELLOW}Checking resource usage...${NC}"
    
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    local disk_usage=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    
    # Check memory
    if [ "$memory_usage" -lt 80 ]; then
        echo -e "${GREEN}✓ Memory usage: ${memory_usage}%${NC}"
    elif [ "$memory_usage" -lt 90 ]; then
        echo -e "${YELLOW}⚠ Memory usage: ${memory_usage}% (Warning)${NC}"
    else
        echo -e "${RED}✗ Memory usage: ${memory_usage}% (Critical)${NC}"
        return 1
    fi
    
    # Check disk
    if [ "$disk_usage" -lt 80 ]; then
        echo -e "${GREEN}✓ Disk usage: ${disk_usage}%${NC}"
    elif [ "$disk_usage" -lt 90 ]; then
        echo -e "${YELLOW}⚠ Disk usage: ${disk_usage}% (Warning)${NC}"
    else
        echo -e "${RED}✗ Disk usage: ${disk_usage}% (Critical)${NC}"
        return 1
    fi
    
    log "RESOURCES: Memory ${memory_usage}%, Disk ${disk_usage}%"
    return 0
}

# Function to check network connectivity
check_network() {
    echo -e "${YELLOW}Checking network connectivity...${NC}"
    
    local services=("frontend:3000" "backend:4000" "ml-service:8000" "minio:9000" "mariadb:3306")
    local failed_services=0
    
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        
        if nc -z localhost $port 2>/dev/null; then
            echo -e "${GREEN}✓ $name port $port is open${NC}"
        else
            echo -e "${RED}✗ $name port $port is closed${NC}"
            ((failed_services++))
        fi
    done
    
    if [ $failed_services -eq 0 ]; then
        log "NETWORK: All services accessible"
        return 0
    else
        log "NETWORK: $failed_services services not accessible"
        return 1
    fi
}

# Function to check application functionality
check_application() {
    echo -e "${YELLOW}Checking application functionality...${NC}"
    
    # Test API endpoints
    local api_endpoints=("/api/health" "/api/auth/professor/login" "/api/auth/student/login")
    local failed_endpoints=0
    
    for endpoint in "${api_endpoints[@]}"; do
        if curl -f -s "http://localhost:4000$endpoint" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ API endpoint $endpoint is working${NC}"
        else
            echo -e "${RED}✗ API endpoint $endpoint is not working${NC}"
            ((failed_endpoints++))
        fi
    done
    
    # Test ML service
    if curl -f -s "http://localhost:8000/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ ML service is working${NC}"
    else
        echo -e "${RED}✗ ML service is not working${NC}"
        ((failed_endpoints++))
    fi
    
    if [ $failed_endpoints -eq 0 ]; then
        log "APPLICATION: All endpoints working"
        return 0
    else
        log "APPLICATION: $failed_endpoints endpoints failed"
        return 1
    fi
}

# Function to check logs for errors
check_logs() {
    echo -e "${YELLOW}Checking logs for errors...${NC}"
    
    local error_count=$(docker-compose logs --since="1h" 2>&1 | grep -i "error\|exception\|failed" | wc -l)
    local warning_count=$(docker-compose logs --since="1h" 2>&1 | grep -i "warning" | wc -l)
    
    if [ "$error_count" -eq 0 ]; then
        echo -e "${GREEN}✓ No errors in logs${NC}"
    elif [ "$error_count" -lt 10 ]; then
        echo -e "${YELLOW}⚠ Found $error_count errors in logs${NC}"
    else
        echo -e "${RED}✗ Found $error_count errors in logs (High)${NC}"
        return 1
    fi
    
    if [ "$warning_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Found $warning_count warnings in logs${NC}"
    fi
    
    log "LOGS: $error_count errors, $warning_count warnings"
    return 0
}

# Function to check attendance activity
check_attendance() {
    echo -e "${YELLOW}Checking attendance activity...${NC}"
    
    # Check for active sessions
    local active_sessions=$(docker-compose exec -T backend node -e "
        const knex = require('knex')({
            client: 'mysql2',
            connection: {
                host: 'mariadb',
                user: process.env.DB_USER || 'root',
                password: process.env.DB_PASSWORD || '',
                database: process.env.DB_NAME || 'labface'
            }
        });
        knex('sessions').where('status', 'open').count('* as count')
            .then(result => {
                console.log(result[0].count);
                process.exit(0);
            })
            .catch(() => {
                console.log('0');
                process.exit(0);
            });
    " 2>/dev/null || echo "0")
    
    # Check for recent attendance records
    local recent_attendance=$(docker-compose exec -T backend node -e "
        const knex = require('knex')({
            client: 'mysql2',
            connection: {
                host: 'mariadb',
                user: process.env.DB_USER || 'root',
                password: process.env.DB_PASSWORD || '',
                database: process.env.DB_NAME || 'labface'
            }
        });
        knex('attendance').where('checkin_ts', '>=', new Date(Date.now() - 24*60*60*1000)).count('* as count')
            .then(result => {
                console.log(result[0].count);
                process.exit(0);
            })
            .catch(() => {
                console.log('0');
                process.exit(0);
            });
    " 2>/dev/null || echo "0")
    
    echo -e "${GREEN}✓ Active sessions: $active_sessions${NC}"
    echo -e "${GREEN}✓ Recent attendance records: $recent_attendance${NC}"
    
    log "ATTENDANCE: $active_sessions active sessions, $recent_attendance recent records"
    return 0
}

# Function to generate health report
generate_report() {
    echo -e "${YELLOW}Generating health report...${NC}"
    
    {
        echo "LabFace Health Check Report"
        echo "=========================="
        echo "Date: $(date)"
        echo ""
        echo "Service Status:"
        docker-compose ps
        echo ""
        echo "Resource Usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        echo ""
        echo "Disk Usage:"
        df -h
        echo ""
        echo "Memory Usage:"
        free -h
        echo ""
        echo "Network Status:"
        netstat -tlnp | grep LISTEN
        echo ""
        echo "Recent Logs:"
        docker-compose logs --tail=50
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}✓ Health report generated: $REPORT_FILE${NC}"
    log "REPORT: Generated $REPORT_FILE"
}

# Function to perform full health check
full_check() {
    echo "Performing comprehensive health check..."
    echo ""
    
    local failed_checks=0
    
    # Check services
    check_service "Frontend" "http://localhost:3000" || ((failed_checks++))
    check_service "Backend" "http://localhost:4000/api/health" || ((failed_checks++))
    check_service "ML Service" "http://localhost:8000/health" || ((failed_checks++))
    
    # Check database
    check_database || ((failed_checks++))
    check_database_tables || ((failed_checks++))
    
    # Check MinIO
    check_minio || ((failed_checks++))
    check_minio_bucket || ((failed_checks++))
    
    # Check containers
    check_containers || ((failed_checks++))
    
    # Check resources
    check_resources || ((failed_checks++))
    
    # Check network
    check_network || ((failed_checks++))
    
    # Check application
    check_application || ((failed_checks++))
    
    # Check logs
    check_logs || ((failed_checks++))
    
    # Check attendance
    check_attendance
    
    echo ""
    if [ $failed_checks -eq 0 ]; then
        echo -e "${GREEN}✓ All health checks passed${NC}"
        log "HEALTH: All checks passed"
    else
        echo -e "${RED}✗ $failed_checks health check(s) failed${NC}"
        log "HEALTH: $failed_checks checks failed"
    fi
    
    generate_report
    return $failed_checks
}

# Function to start continuous monitoring
continuous_monitor() {
    echo "Starting continuous health monitoring (Ctrl+C to stop)..."
    echo ""
    
    while true; do
        echo "=== $(date) ==="
        full_check
        echo ""
        echo "Waiting 5 minutes before next check..."
        sleep 300
    done
}

# Main execution
main() {
    case "${1:-check}" in
        "check")
            full_check
            ;;
        "monitor")
            continuous_monitor
            ;;
        "report")
            generate_report
            ;;
        *)
            echo "Usage: $0 [check|monitor|report]"
            echo ""
            echo "Commands:"
            echo "  check   - Perform a single health check"
            echo "  monitor - Start continuous monitoring"
            echo "  report  - Generate a health report"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
