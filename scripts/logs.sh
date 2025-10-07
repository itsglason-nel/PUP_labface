#!/bin/bash

# LabFace Logs Management Script
# This script manages logs for the LabFace system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOGS_DIR="./logs"
LOG_RETENTION_DAYS=${1:-30}
LOG_SIZE_LIMIT="10M"

echo -e "${BLUE}LabFace Logs Management${NC}"
echo "======================="
echo "Retention: $LOG_RETENTION_DAYS days"
echo "Size limit: $LOG_SIZE_LIMIT"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/logs_management.log"
}

# Function to create logs directory
create_logs_directory() {
    echo -e "${YELLOW}Creating logs directory...${NC}"
    
    mkdir -p "$LOGS_DIR"
    
    echo -e "${GREEN}✓ Logs directory created${NC}"
    log "LOGS_DIR: Created $LOGS_DIR"
}

# Function to collect application logs
collect_application_logs() {
    echo -e "${YELLOW}Collecting application logs...${NC}"
    
    # Collect Docker Compose logs
    if [ -f "docker-compose.yml" ]; then
        echo "Collecting Docker Compose logs..."
        docker-compose logs --timestamps > "$LOGS_DIR/application.log" 2>/dev/null || true
        
        # Collect individual service logs
        docker-compose logs --timestamps backend > "$LOGS_DIR/backend.log" 2>/dev/null || true
        docker-compose logs --timestamps frontend > "$LOGS_DIR/frontend.log" 2>/dev/null || true
        docker-compose logs --timestamps ml-service > "$LOGS_DIR/ml-service.log" 2>/dev/null || true
        docker-compose logs --timestamps mariadb > "$LOGS_DIR/mariadb.log" 2>/dev/null || true
        docker-compose logs --timestamps minio > "$LOGS_DIR/minio.log" 2>/dev/null || true
        docker-compose logs --timestamps adminer > "$LOGS_DIR/adminer.log" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Application logs collected${NC}"
    else
        echo -e "${YELLOW}⚠ Docker Compose not found, skipping application logs${NC}"
    fi
    
    log "APPLICATION: Logs collected"
}

# Function to collect system logs
collect_system_logs() {
    echo -e "${YELLOW}Collecting system logs...${NC}"
    
    # Collect system information
    {
        echo "=== System Information ==="
        uname -a
        echo ""
        echo "=== CPU Information ==="
        lscpu 2>/dev/null || cat /proc/cpuinfo
        echo ""
        echo "=== Memory Information ==="
        free -h
        echo ""
        echo "=== Disk Information ==="
        df -h
        echo ""
        echo "=== Network Information ==="
        ip addr show 2>/dev/null || ifconfig
        echo ""
        echo "=== Process Information ==="
        ps aux | head -20
        echo ""
        echo "=== Docker Information ==="
        docker version 2>/dev/null || echo "Docker not available"
        echo ""
        echo "=== Docker Compose Information ==="
        docker-compose version 2>/dev/null || echo "Docker Compose not available"
    } > "$LOGS_DIR/system.log"
    
    echo -e "${GREEN}✓ System logs collected${NC}"
    log "SYSTEM: Logs collected"
}

# Function to collect security logs
collect_security_logs() {
    echo -e "${YELLOW}Collecting security logs...${NC}"
    
    # Collect authentication logs
    if [ -f "/var/log/auth.log" ]; then
        sudo cp /var/log/auth.log "$LOGS_DIR/auth.log" 2>/dev/null || true
    fi
    
    # Collect system logs
    if [ -f "/var/log/syslog" ]; then
        sudo cp /var/log/syslog "$LOGS_DIR/syslog.log" 2>/dev/null || true
    fi
    
    # Collect failed login attempts
    if [ -f "/var/log/faillog" ]; then
        sudo cp /var/log/faillog "$LOGS_DIR/faillog.log" 2>/dev/null || true
    fi
    
    # Collect SSH logs
    if [ -f "/var/log/secure" ]; then
        sudo cp /var/log/secure "$LOGS_DIR/secure.log" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Security logs collected${NC}"
    log "SECURITY: Logs collected"
}

# Function to collect database logs
collect_database_logs() {
    echo -e "${YELLOW}Collecting database logs...${NC}"
    
    # Collect MariaDB logs
    if docker-compose exec -T mariadb mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "Collecting MariaDB logs..."
        docker-compose logs --timestamps mariadb > "$LOGS_DIR/mariadb_detailed.log" 2>/dev/null || true
        
        # Collect database status
        {
            echo "=== MariaDB Status ==="
            docker-compose exec -T mariadb mysqladmin status 2>/dev/null || echo "Status not available"
            echo ""
            echo "=== MariaDB Variables ==="
            docker-compose exec -T mariadb mysql -e "SHOW VARIABLES LIKE 'log%';" 2>/dev/null || echo "Variables not available"
            echo ""
            echo "=== MariaDB Process List ==="
            docker-compose exec -T mariadb mysql -e "SHOW PROCESSLIST;" 2>/dev/null || echo "Process list not available"
        } > "$LOGS_DIR/mariadb_status.log"
        
        echo -e "${GREEN}✓ Database logs collected${NC}"
    else
        echo -e "${YELLOW}⚠ MariaDB not accessible, skipping database logs${NC}"
    fi
    
    log "DATABASE: Logs collected"
}

# Function to collect network logs
collect_network_logs() {
    echo -e "${YELLOW}Collecting network logs...${NC}"
    
    # Collect network connections
    {
        echo "=== Network Connections ==="
        netstat -tlnp 2>/dev/null || ss -tlnp
        echo ""
        echo "=== Network Statistics ==="
        netstat -i 2>/dev/null || ip -s link
        echo ""
        echo "=== Routing Table ==="
        ip route show 2>/dev/null || route -n
        echo ""
        echo "=== DNS Configuration ==="
        cat /etc/resolv.conf 2>/dev/null || echo "DNS config not available"
    } > "$LOGS_DIR/network.log"
    
    echo -e "${GREEN}✓ Network logs collected${NC}"
    log "NETWORK: Logs collected"
}

# Function to collect performance logs
collect_performance_logs() {
    echo -e "${YELLOW}Collecting performance logs...${NC}"
    
    # Collect system performance
    {
        echo "=== System Load ==="
        uptime
        echo ""
        echo "=== Memory Usage ==="
        free -h
        echo ""
        echo "=== Disk Usage ==="
        df -h
        echo ""
        echo "=== Top Processes ==="
        top -bn1 | head -20
        echo ""
        echo "=== Docker Stats ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || echo "Docker stats not available"
    } > "$LOGS_DIR/performance.log"
    
    echo -e "${GREEN}✓ Performance logs collected${NC}"
    log "PERFORMANCE: Logs collected"
}

# Function to compress large logs
compress_large_logs() {
    echo -e "${YELLOW}Compressing large logs...${NC}"
    
    # Find large log files
    local large_logs=$(find "$LOGS_DIR" -name "*.log" -type f -size +$LOG_SIZE_LIMIT 2>/dev/null)
    
    if [ -n "$large_logs" ]; then
        echo "Compressing large log files..."
        echo "$large_logs" | while read -r log_file; do
            if [ -f "$log_file" ]; then
                gzip "$log_file"
                echo "  Compressed: $log_file"
            fi
        done
        echo -e "${GREEN}✓ Large logs compressed${NC}"
    else
        echo -e "${GREEN}✓ No large logs found${NC}"
    fi
    
    log "COMPRESSION: Large logs compressed"
}

# Function to clean up old logs
cleanup_old_logs() {
    echo -e "${YELLOW}Cleaning up old logs...${NC}"
    
    # Remove old log files
    local old_logs=$(find "$LOGS_DIR" -name "*.log" -type f -mtime +$LOG_RETENTION_DAYS 2>/dev/null | wc -l)
    if [ "$old_logs" -gt 0 ]; then
        echo "Removing $old_logs old log files..."
        find "$LOGS_DIR" -name "*.log" -type f -mtime +$LOG_RETENTION_DAYS -delete
        echo -e "${GREEN}✓ Removed $old_logs old log files${NC}"
    else
        echo -e "${GREEN}✓ No old log files found${NC}"
    fi
    
    # Remove old compressed logs
    local old_compressed=$(find "$LOGS_DIR" -name "*.log.gz" -type f -mtime +$LOG_RETENTION_DAYS 2>/dev/null | wc -l)
    if [ "$old_compressed" -gt 0 ]; then
        echo "Removing $old_compressed old compressed logs..."
        find "$LOGS_DIR" -name "*.log.gz" -type f -mtime +$LOG_RETENTION_DAYS -delete
        echo -e "${GREEN}✓ Removed $old_compressed old compressed logs${NC}"
    else
        echo -e "${GREEN}✓ No old compressed logs found${NC}"
    fi
    
    log "CLEANUP: Removed old logs (retention: $LOG_RETENTION_DAYS days)"
}

# Function to analyze logs
analyze_logs() {
    echo -e "${YELLOW}Analyzing logs...${NC}"
    
    # Analyze error patterns
    {
        echo "=== Error Analysis ==="
        echo "Errors in last 24 hours:"
        find "$LOGS_DIR" -name "*.log" -type f -mtime -1 -exec grep -l "error\|exception\|failed" {} \; 2>/dev/null | wc -l
        echo ""
        echo "Most common errors:"
        find "$LOGS_DIR" -name "*.log" -type f -mtime -1 -exec grep -i "error\|exception\|failed" {} \; 2>/dev/null | sort | uniq -c | sort -nr | head -10
        echo ""
        echo "=== Warning Analysis ==="
        echo "Warnings in last 24 hours:"
        find "$LOGS_DIR" -name "*.log" -type f -mtime -1 -exec grep -l "warning" {} \; 2>/dev/null | wc -l
        echo ""
        echo "Most common warnings:"
        find "$LOGS_DIR" -name "*.log" -type f -mtime -1 -exec grep -i "warning" {} \; 2>/dev/null | sort | uniq -c | sort -nr | head -10
    } > "$LOGS_DIR/analysis.log"
    
    echo -e "${GREEN}✓ Log analysis completed${NC}"
    log "ANALYSIS: Log analysis completed"
}

# Function to generate log report
generate_report() {
    echo -e "${YELLOW}Generating log report...${NC}"
    
    local report_file="$LOGS_DIR/log_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "LabFace Logs Report"
        echo "==================="
        echo "Date: $(date)"
        echo "Retention: $LOG_RETENTION_DAYS days"
        echo ""
        echo "Log Files:"
        echo "=========="
        ls -lh "$LOGS_DIR"/*.log 2>/dev/null || echo "No log files found"
        echo ""
        echo "Compressed Logs:"
        echo "==============="
        ls -lh "$LOGS_DIR"/*.log.gz 2>/dev/null || echo "No compressed logs found"
        echo ""
        echo "Log Sizes:"
        echo "=========="
        du -sh "$LOGS_DIR"/* 2>/dev/null || echo "No logs found"
        echo ""
        echo "Recent Activity:"
        echo "==============="
        find "$LOGS_DIR" -name "*.log" -type f -mtime -1 -exec ls -lh {} \; 2>/dev/null || echo "No recent activity"
    } > "$report_file"
    
    echo -e "${GREEN}✓ Log report generated: $report_file${NC}"
    log "REPORT: Generated $report_file"
}

# Function to show log summary
show_summary() {
    echo ""
    echo -e "${BLUE}Log Summary:${NC}"
    echo "============"
    
    # Show log files
    echo "Log files:"
    ls -lh "$LOGS_DIR"/*.log 2>/dev/null || echo "No log files found"
    
    # Show compressed logs
    echo ""
    echo "Compressed logs:"
    ls -lh "$LOGS_DIR"/*.log.gz 2>/dev/null || echo "No compressed logs found"
    
    # Show total size
    echo ""
    echo "Total log size:"
    du -sh "$LOGS_DIR" 2>/dev/null || echo "No logs found"
    
    # Show recent activity
    echo ""
    echo "Recent activity (last 24 hours):"
    find "$LOGS_DIR" -name "*.log" -type f -mtime -1 -exec ls -lh {} \; 2>/dev/null || echo "No recent activity"
    
    echo ""
    echo -e "${GREEN}✓ Log management completed!${NC}"
    log "SUMMARY: Log management completed"
}

# Function to perform full log collection
full_collection() {
    echo "Starting full log collection..."
    echo ""
    
    create_logs_directory
    collect_application_logs
    collect_system_logs
    collect_security_logs
    collect_database_logs
    collect_network_logs
    collect_performance_logs
    compress_large_logs
    cleanup_old_logs
    analyze_logs
    generate_report
    show_summary
}

# Function to perform quick collection
quick_collection() {
    echo "Starting quick log collection..."
    echo ""
    
    create_logs_directory
    collect_application_logs
    collect_system_logs
    compress_large_logs
    show_summary
}

# Main execution
main() {
    case "${2:-full}" in
        "full")
            full_collection
            ;;
        "quick")
            quick_collection
            ;;
        "collect")
            create_logs_directory
            collect_application_logs
            collect_system_logs
            collect_security_logs
            collect_database_logs
            collect_network_logs
            collect_performance_logs
            show_summary
            ;;
        "compress")
            compress_large_logs
            ;;
        "cleanup")
            cleanup_old_logs
            ;;
        "analyze")
            analyze_logs
            ;;
        "report")
            generate_report
            ;;
        "summary")
            show_summary
            ;;
        *)
            echo "Usage: $0 <retention_days> [full|quick|collect|compress|cleanup|analyze|report|summary]"
            echo ""
            echo "Arguments:"
            echo "  retention_days  - Number of days to keep logs (default: 30)"
            echo ""
            echo "Commands:"
            echo "  full     - Perform full log collection (default)"
            echo "  quick    - Perform quick log collection"
            echo "  collect  - Collect all logs"
            echo "  compress - Compress large logs only"
            echo "  cleanup  - Clean up old logs only"
            echo "  analyze  - Analyze logs only"
            echo "  report   - Generate log report only"
            echo "  summary  - Show log summary only"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
