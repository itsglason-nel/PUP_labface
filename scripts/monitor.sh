#!/bin/bash

# LabFace System Monitor
# This script monitors the health and performance of the LabFace system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="logs/monitor.log"
ALERT_EMAIL="admin@labface.edu"

echo -e "${BLUE}LabFace System Monitor${NC}"
echo "======================"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check service health
check_service_health() {
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
    echo -e "${YELLOW}Checking database...${NC}"
    
    if docker-compose exec -T mariadb mysqladmin ping -h localhost --silent; then
        echo -e "${GREEN}✓ Database is accessible${NC}"
        log "HEALTHY: Database"
        return 0
    else
        echo -e "${RED}✗ Database is not accessible${NC}"
        log "UNHEALTHY: Database"
        return 1
    fi
}

# Function to check disk space
check_disk_space() {
    echo -e "${YELLOW}Checking disk space...${NC}"
    
    local usage=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -lt 80 ]; then
        echo -e "${GREEN}✓ Disk usage: ${usage}%${NC}"
        log "DISK: ${usage}% usage"
    elif [ "$usage" -lt 90 ]; then
        echo -e "${YELLOW}⚠ Disk usage: ${usage}% (Warning)${NC}"
        log "DISK WARNING: ${usage}% usage"
    else
        echo -e "${RED}✗ Disk usage: ${usage}% (Critical)${NC}"
        log "DISK CRITICAL: ${usage}% usage"
        return 1
    fi
}

# Function to check memory usage
check_memory() {
    echo -e "${YELLOW}Checking memory usage...${NC}"
    
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$memory_usage" -lt 80 ]; then
        echo -e "${GREEN}✓ Memory usage: ${memory_usage}%${NC}"
        log "MEMORY: ${memory_usage}% usage"
    elif [ "$memory_usage" -lt 90 ]; then
        echo -e "${YELLOW}⚠ Memory usage: ${memory_usage}% (Warning)${NC}"
        log "MEMORY WARNING: ${memory_usage}% usage"
    else
        echo -e "${RED}✗ Memory usage: ${memory_usage}% (Critical)${NC}"
        log "MEMORY CRITICAL: ${memory_usage}% usage"
        return 1
    fi
}

# Function to check container status
check_containers() {
    echo -e "${YELLOW}Checking container status...${NC}"
    
    local unhealthy_containers=$(docker-compose ps --filter "health=unhealthy" --format "table {{.Name}}" | tail -n +2)
    
    if [ -z "$unhealthy_containers" ]; then
        echo -e "${GREEN}✓ All containers are healthy${NC}"
        log "CONTAINERS: All healthy"
    else
        echo -e "${RED}✗ Unhealthy containers: $unhealthy_containers${NC}"
        log "CONTAINERS UNHEALTHY: $unhealthy_containers"
        return 1
    fi
}

# Function to check recent errors
check_recent_errors() {
    echo -e "${YELLOW}Checking for recent errors...${NC}"
    
    local error_count=$(docker-compose logs --since="1h" 2>&1 | grep -i "error\|exception\|failed" | wc -l)
    
    if [ "$error_count" -eq 0 ]; then
        echo -e "${GREEN}✓ No recent errors found${NC}"
        log "ERRORS: None in last hour"
    elif [ "$error_count" -lt 10 ]; then
        echo -e "${YELLOW}⚠ Found $error_count recent errors${NC}"
        log "ERRORS: $error_count in last hour"
    else
        echo -e "${RED}✗ Found $error_count recent errors (High)${NC}"
        log "ERRORS HIGH: $error_count in last hour"
        return 1
    fi
}

# Function to check attendance activity
check_attendance_activity() {
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
    
    if [ "$active_sessions" -gt 0 ]; then
        echo -e "${GREEN}✓ $active_sessions active session(s)${NC}"
        log "ACTIVITY: $active_sessions active sessions"
    else
        echo -e "${YELLOW}⚠ No active sessions${NC}"
        log "ACTIVITY: No active sessions"
    fi
}

# Function to generate system report
generate_report() {
    echo -e "${YELLOW}Generating system report...${NC}"
    
    local report_file="logs/system_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "LabFace System Report - $(date)"
        echo "================================="
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
        echo "Recent Logs:"
        docker-compose logs --tail=50
    } > "$report_file"
    
    echo -e "${GREEN}✓ System report generated: $report_file${NC}"
    log "REPORT: Generated $report_file"
}

# Function to send alert
send_alert() {
    local message=$1
    
    echo -e "${RED}ALERT: $message${NC}"
    log "ALERT: $message"
    
    # Send email alert (if configured)
    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "LabFace System Alert" "$ALERT_EMAIL" 2>/dev/null || true
    fi
    
    # Send webhook alert (if configured)
    if [ -n "$WEBHOOK_URL" ]; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"LabFace Alert: $message\"}" \
             "$WEBHOOK_URL" 2>/dev/null || true
    fi
}

# Function to perform full system check
full_check() {
    local failed_checks=0
    
    echo "Performing full system check..."
    echo ""
    
    # Check services
    check_service_health "Frontend" "http://localhost:3000" || ((failed_checks++))
    check_service_health "Backend" "http://localhost:4000/api/health" || ((failed_checks++))
    check_service_health "ML Service" "http://localhost:8000/health" || ((failed_checks++))
    
    # Check database
    check_database || ((failed_checks++))
    
    # Check containers
    check_containers || ((failed_checks++))
    
    # Check resources
    check_disk_space || ((failed_checks++))
    check_memory || ((failed_checks++))
    
    # Check for errors
    check_recent_errors || ((failed_checks++))
    
    # Check activity
    check_attendance_activity
    
    echo ""
    if [ $failed_checks -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed${NC}"
        log "MONITOR: All checks passed"
    else
        echo -e "${RED}✗ $failed_checks check(s) failed${NC}"
        log "MONITOR: $failed_checks checks failed"
        send_alert "$failed_checks system check(s) failed"
    fi
    
    return $failed_checks
}

# Function to start continuous monitoring
continuous_monitor() {
    echo "Starting continuous monitoring (Ctrl+C to stop)..."
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
            echo "  check   - Perform a single system check"
            echo "  monitor - Start continuous monitoring"
            echo "  report  - Generate a system report"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
