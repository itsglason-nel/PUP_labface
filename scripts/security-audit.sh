#!/bin/bash

# LabFace Security Audit Script
# This script performs security checks on the LabFace system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AUDIT_LOG="logs/security_audit.log"
REPORT_FILE="logs/security_report_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${BLUE}LabFace Security Audit${NC}"
echo "======================"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$AUDIT_LOG"
}

# Function to check environment security
check_environment() {
    echo -e "${YELLOW}Checking environment security...${NC}"
    
    local issues=0
    
    # Check for default passwords
    if grep -q "change_me" .env 2>/dev/null; then
        echo -e "${RED}✗ Default JWT secret found${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ JWT secret is customized${NC}"
    fi
    
    # Check for empty passwords
    if grep -q "DB_PASSWORD=$" .env 2>/dev/null; then
        echo -e "${RED}✗ Empty database password${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ Database password is set${NC}"
    fi
    
    # Check for MinIO default credentials
    if grep -q "minioadmin" .env 2>/dev/null; then
        echo -e "${RED}✗ Default MinIO credentials${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ MinIO credentials are customized${NC}"
    fi
    
    # Check file permissions
    if [ -f .env ]; then
        local perms=$(stat -c %a .env 2>/dev/null || stat -f %A .env 2>/dev/null)
        if [ "$perms" -gt 600 ]; then
            echo -e "${RED}✗ .env file has insecure permissions ($perms)${NC}"
            ((issues++))
        else
            echo -e "${GREEN}✓ .env file has secure permissions${NC}"
        fi
    fi
    
    log "ENVIRONMENT: $issues issues found"
    return $issues
}

# Function to check Docker security
check_docker_security() {
    echo -e "${YELLOW}Checking Docker security...${NC}"
    
    local issues=0
    
    # Check for running containers as root
    local root_containers=$(docker ps --format "table {{.Names}}\t{{.User}}" | grep -v "root" | wc -l)
    if [ "$root_containers" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Some containers running as root${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ No containers running as root${NC}"
    fi
    
    # Check for exposed ports
    local exposed_ports=$(docker-compose ps --format "table {{.Ports}}" | grep -o "[0-9]*:[0-9]*" | wc -l)
    if [ "$exposed_ports" -gt 5 ]; then
        echo -e "${YELLOW}⚠ Many ports exposed ($exposed_ports)${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ Reasonable number of ports exposed${NC}"
    fi
    
    # Check for privileged containers
    local privileged=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -i privileged | wc -l)
    if [ "$privileged" -gt 0 ]; then
        echo -e "${RED}✗ Privileged containers found${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ No privileged containers${NC}"
    fi
    
    log "DOCKER: $issues issues found"
    return $issues
}

# Function to check network security
check_network_security() {
    echo -e "${YELLOW}Checking network security...${NC}"
    
    local issues=0
    
    # Check for open ports
    local open_ports=$(netstat -tlnp 2>/dev/null | grep LISTEN | wc -l)
    if [ "$open_ports" -gt 10 ]; then
        echo -e "${YELLOW}⚠ Many open ports ($open_ports)${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ Reasonable number of open ports${NC}"
    fi
    
    # Check for database exposure
    if netstat -tlnp 2>/dev/null | grep -q ":3306"; then
        echo -e "${RED}✗ Database port 3306 is exposed${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ Database port not exposed${NC}"
    fi
    
    # Check for MinIO exposure
    if netstat -tlnp 2>/dev/null | grep -q ":9000"; then
        echo -e "${RED}✗ MinIO port 9000 is exposed${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ MinIO port not exposed${NC}"
    fi
    
    log "NETWORK: $issues issues found"
    return $issues
}

# Function to check application security
check_application_security() {
    echo -e "${YELLOW}Checking application security...${NC}"
    
    local issues=0
    
    # Check for HTTPS
    if curl -k -s https://localhost:443 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ HTTPS is enabled${NC}"
    else
        echo -e "${YELLOW}⚠ HTTPS not detected${NC}"
        ((issues++))
    fi
    
    # Check for security headers
    local headers=$(curl -s -I http://localhost:3000 2>/dev/null | grep -i "x-frame-options\|x-content-type-options\|x-xss-protection" | wc -l)
    if [ "$headers" -gt 0 ]; then
        echo -e "${GREEN}✓ Security headers present${NC}"
    else
        echo -e "${YELLOW}⚠ Security headers missing${NC}"
        ((issues++))
    fi
    
    # Check for rate limiting
    local rate_limit=$(curl -s http://localhost:4000/api/health 2>/dev/null | grep -i "rate" | wc -l)
    if [ "$rate_limit" -gt 0 ]; then
        echo -e "${GREEN}✓ Rate limiting detected${NC}"
    else
        echo -e "${YELLOW}⚠ Rate limiting not detected${NC}"
        ((issues++))
    fi
    
    log "APPLICATION: $issues issues found"
    return $issues
}

# Function to check data security
check_data_security() {
    echo -e "${YELLOW}Checking data security...${NC}"
    
    local issues=0
    
    # Check for encrypted volumes
    local encrypted_volumes=$(docker volume ls --format "{{.Name}}" | xargs -I {} docker volume inspect {} --format "{{.Mountpoint}}" | xargs -I {} lsattr {} 2>/dev/null | grep -c "e" || echo "0")
    if [ "$encrypted_volumes" -gt 0 ]; then
        echo -e "${GREEN}✓ Some volumes are encrypted${NC}"
    else
        echo -e "${YELLOW}⚠ No encrypted volumes detected${NC}"
        ((issues++))
    fi
    
    # Check for backup encryption
    if [ -d "$BACKUP_DIR" ]; then
        local backup_files=$(find "$BACKUP_DIR" -name "*.tar.gz" | wc -l)
        if [ "$backup_files" -gt 0 ]; then
            echo -e "${GREEN}✓ Backup files found${NC}"
        else
            echo -e "${YELLOW}⚠ No backup files found${NC}"
            ((issues++))
        fi
    fi
    
    # Check for log files
    if [ -d "logs" ]; then
        local log_files=$(find logs -name "*.log" | wc -l)
        if [ "$log_files" -gt 0 ]; then
            echo -e "${GREEN}✓ Log files found${NC}"
        else
            echo -e "${YELLOW}⚠ No log files found${NC}"
            ((issues++))
        fi
    fi
    
    log "DATA: $issues issues found"
    return $issues
}

# Function to check access control
check_access_control() {
    echo -e "${YELLOW}Checking access control...${NC}"
    
    local issues=0
    
    # Check for file permissions
    local insecure_files=$(find . -type f -perm /o+w 2>/dev/null | wc -l)
    if [ "$insecure_files" -gt 0 ]; then
        echo -e "${RED}✗ $insecure_files files with world-write permissions${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ No files with world-write permissions${NC}"
    fi
    
    # Check for directory permissions
    local insecure_dirs=$(find . -type d -perm /o+w 2>/dev/null | wc -l)
    if [ "$insecure_dirs" -gt 0 ]; then
        echo -e "${RED}✗ $insecure_dirs directories with world-write permissions${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ No directories with world-write permissions${NC}"
    fi
    
    # Check for sensitive files
    local sensitive_files=$(find . -name "*.key" -o -name "*.pem" -o -name "*.p12" 2>/dev/null | wc -l)
    if [ "$sensitive_files" -gt 0 ]; then
        echo -e "${YELLOW}⚠ $sensitive_files sensitive files found${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✓ No sensitive files found${NC}"
    fi
    
    log "ACCESS: $issues issues found"
    return $issues
}

# Function to generate security report
generate_report() {
    echo -e "${YELLOW}Generating security report...${NC}"
    
    {
        echo "LabFace Security Audit Report"
        echo "============================"
        echo "Date: $(date)"
        echo ""
        echo "Environment Security:"
        check_environment
        echo ""
        echo "Docker Security:"
        check_docker_security
        echo ""
        echo "Network Security:"
        check_network_security
        echo ""
        echo "Application Security:"
        check_application_security
        echo ""
        echo "Data Security:"
        check_data_security
        echo ""
        echo "Access Control:"
        check_access_control
        echo ""
        echo "Recommendations:"
        echo "==============="
        echo "1. Change all default passwords"
        echo "2. Enable HTTPS in production"
        echo "3. Implement proper firewall rules"
        echo "4. Encrypt sensitive data at rest"
        echo "5. Regular security updates"
        echo "6. Monitor access logs"
        echo "7. Implement intrusion detection"
        echo "8. Regular security audits"
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}✓ Security report generated: $REPORT_FILE${NC}"
    log "REPORT: Generated $REPORT_FILE"
}

# Function to fix common issues
fix_issues() {
    echo -e "${YELLOW}Fixing common security issues...${NC}"
    
    # Fix file permissions
    echo "Fixing file permissions..."
    find . -type f -name "*.env" -exec chmod 600 {} \;
    find . -type f -name "*.key" -exec chmod 600 {} \;
    find . -type f -name "*.pem" -exec chmod 600 {} \;
    
    # Remove world-write permissions
    find . -type f -perm /o+w -exec chmod o-w {} \;
    find . -type d -perm /o+w -exec chmod o-w {} \;
    
    echo -e "${GREEN}✓ Common issues fixed${NC}"
    log "FIXES: Applied successfully"
}

# Main execution
main() {
    case "${1:-audit}" in
        "audit")
            echo "Starting security audit..."
            echo ""
            
            local total_issues=0
            
            check_environment || total_issues=$((total_issues + $?))
            check_docker_security || total_issues=$((total_issues + $?))
            check_network_security || total_issues=$((total_issues + $?))
            check_application_security || total_issues=$((total_issues + $?))
            check_data_security || total_issues=$((total_issues + $?))
            check_access_control || total_issues=$((total_issues + $?))
            
            echo ""
            if [ $total_issues -eq 0 ]; then
                echo -e "${GREEN}✓ Security audit passed - no issues found${NC}"
            else
                echo -e "${YELLOW}⚠ Security audit found $total_issues issues${NC}"
            fi
            
            generate_report
            ;;
        "fix")
            fix_issues
            ;;
        "report")
            generate_report
            ;;
        *)
            echo "Usage: $0 [audit|fix|report]"
            echo ""
            echo "Commands:"
            echo "  audit  - Perform security audit"
            echo "  fix    - Fix common security issues"
            echo "  report - Generate security report"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
