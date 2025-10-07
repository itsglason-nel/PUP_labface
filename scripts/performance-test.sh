#!/bin/bash

# LabFace Performance Test Script
# This script performs performance testing on the LabFace system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PERF_LOG="logs/performance_test.log"
REPORT_FILE="logs/performance_report_$(date +%Y%m%d_%H%M%S).txt"
TEST_DURATION=${1:-60}
CONCURRENT_USERS=${2:-10}

echo -e "${BLUE}LabFace Performance Test${NC}"
echo "============================"
echo "Test Duration: $TEST_DURATION seconds"
echo "Concurrent Users: $CONCURRENT_USERS"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PERF_LOG"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if services are running
    local services=("frontend:3000" "backend:4000" "ml-service:8000")
    local failed_services=0
    
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        
        if curl -f -s "http://localhost:$port" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $name is running${NC}"
        else
            echo -e "${RED}✗ $name is not running${NC}"
            ((failed_services++))
        fi
    done
    
    if [ $failed_services -gt 0 ]; then
        echo -e "${RED}✗ $failed_services services are not running${NC}"
        echo "Please start the services first: docker compose up -d"
        exit 1
    fi
    
    # Check if required tools are installed
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}✗ curl is not installed${NC}"
        exit 1
    fi
    
    if ! command -v ab >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Apache Bench (ab) is not installed${NC}"
        echo "Installing Apache Bench..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y apache2-utils
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y httpd-tools
        elif command -v brew >/dev/null 2>&1; then
            brew install httpd
        else
            echo -e "${RED}✗ Cannot install Apache Bench automatically${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
    log "PREREQUISITES: Check passed"
}

# Function to test API performance
test_api_performance() {
    echo -e "${YELLOW}Testing API performance...${NC}"
    
    local api_endpoints=(
        "/api/health"
        "/api/auth/professor/login"
        "/api/auth/student/login"
        "/api/classes"
        "/api/presence_events"
    )
    
    for endpoint in "${api_endpoints[@]}"; do
        echo "Testing endpoint: $endpoint"
        
        # Test with Apache Bench
        local results=$(ab -n 100 -c $CONCURRENT_USERS "http://localhost:4000$endpoint" 2>/dev/null | grep -E "(Requests per second|Time per request|Failed requests)" || echo "0 0 0")
        
        local rps=$(echo "$results" | grep "Requests per second" | awk '{print $4}' || echo "0")
        local tpr=$(echo "$results" | grep "Time per request" | head -n1 | awk '{print $4}' || echo "0")
        local failed=$(echo "$results" | grep "Failed requests" | awk '{print $3}' || echo "0")
        
        echo "  Requests per second: $rps"
        echo "  Time per request: ${tpr}ms"
        echo "  Failed requests: $failed"
        
        if [ "$failed" -gt 0 ]; then
            echo -e "${RED}✗ $failed failed requests${NC}"
        else
            echo -e "${GREEN}✓ No failed requests${NC}"
        fi
        
        log "API: $endpoint - RPS: $rps, TPR: ${tpr}ms, Failed: $failed"
    done
}

# Function to test database performance
test_database_performance() {
    echo -e "${YELLOW}Testing database performance...${NC}"
    
    # Test database connection time
    local start_time=$(date +%s%N)
    docker-compose exec -T mariadb mysqladmin ping -h localhost --silent
    local end_time=$(date +%s%N)
    local connection_time=$(( (end_time - start_time) / 1000000 ))
    
    echo "Database connection time: ${connection_time}ms"
    
    # Test query performance
    local query_start=$(date +%s%N)
    docker-compose exec -T backend node -e "
        const knex = require('knex')({
            client: 'mysql2',
            connection: {
                host: 'mariadb',
                user: process.env.DB_USER || 'root',
                password: process.env.DB_PASSWORD || '',
                database: process.env.DB_NAME || 'labface'
            }
        });
        knex('students').count('* as count')
            .then(result => {
                console.log('Student count:', result[0].count);
                process.exit(0);
            })
            .catch(() => {
                console.log('Query failed');
                process.exit(0);
            });
    " 2>/dev/null || echo "Query failed"
    local query_end=$(date +%s%N)
    local query_time=$(( (query_end - query_start) / 1000000 ))
    
    echo "Query execution time: ${query_time}ms"
    
    if [ "$query_time" -lt 100 ]; then
        echo -e "${GREEN}✓ Database performance is good${NC}"
    elif [ "$query_time" -lt 500 ]; then
        echo -e "${YELLOW}⚠ Database performance is acceptable${NC}"
    else
        echo -e "${RED}✗ Database performance is poor${NC}"
    fi
    
    log "DATABASE: Connection: ${connection_time}ms, Query: ${query_time}ms"
}

# Function to test ML service performance
test_ml_performance() {
    echo -e "${YELLOW}Testing ML service performance...${NC}"
    
    # Test ML service response time
    local start_time=$(date +%s%N)
    curl -f -s "http://localhost:8000/health" > /dev/null
    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 ))
    
    echo "ML service response time: ${response_time}ms"
    
    # Test face matching performance (if possible)
    local test_image="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/8A8A"
    
    local match_start=$(date +%s%N)
    curl -f -s -X POST "http://localhost:8000/match" \
        -H "Content-Type: application/json" \
        -d "{\"image_data\":\"$test_image\"}" > /dev/null 2>&1 || true
    local match_end=$(date +%s%N)
    local match_time=$(( (match_end - match_start) / 1000000 ))
    
    echo "Face matching time: ${match_time}ms"
    
    if [ "$response_time" -lt 100 ]; then
        echo -e "${GREEN}✓ ML service performance is good${NC}"
    elif [ "$response_time" -lt 500 ]; then
        echo -e "${YELLOW}⚠ ML service performance is acceptable${NC}"
    else
        echo -e "${RED}✗ ML service performance is poor${NC}"
    fi
    
    log "ML_SERVICE: Response: ${response_time}ms, Match: ${match_time}ms"
}

# Function to test frontend performance
test_frontend_performance() {
    echo -e "${YELLOW}Testing frontend performance...${NC}"
    
    # Test frontend response time
    local start_time=$(date +%s%N)
    curl -f -s "http://localhost:3000" > /dev/null
    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 ))
    
    echo "Frontend response time: ${response_time}ms"
    
    # Test with Apache Bench
    local results=$(ab -n 50 -c 5 "http://localhost:3000" 2>/dev/null | grep -E "(Requests per second|Time per request)" || echo "0 0")
    
    local rps=$(echo "$results" | grep "Requests per second" | awk '{print $4}' || echo "0")
    local tpr=$(echo "$results" | grep "Time per request" | head -n1 | awk '{print $4}' || echo "0")
    
    echo "  Requests per second: $rps"
    echo "  Time per request: ${tpr}ms"
    
    if [ "$response_time" -lt 200 ]; then
        echo -e "${GREEN}✓ Frontend performance is good${NC}"
    elif [ "$response_time" -lt 1000 ]; then
        echo -e "${YELLOW}⚠ Frontend performance is acceptable${NC}"
    else
        echo -e "${RED}✗ Frontend performance is poor${NC}"
    fi
    
    log "FRONTEND: Response: ${response_time}ms, RPS: $rps, TPR: ${tpr}ms"
}

# Function to test WebSocket performance
test_websocket_performance() {
    echo -e "${YELLOW}Testing WebSocket performance...${NC}"
    
    # Test WebSocket connection time
    local start_time=$(date +%s%N)
    curl -f -s "http://localhost:4000/socket.io/" > /dev/null
    local end_time=$(date +%s%N)
    local connection_time=$(( (end_time - start_time) / 1000000 ))
    
    echo "WebSocket connection time: ${connection_time}ms"
    
    if [ "$connection_time" -lt 100 ]; then
        echo -e "${GREEN}✓ WebSocket performance is good${NC}"
    elif [ "$connection_time" -lt 500 ]; then
        echo -e "${YELLOW}⚠ WebSocket performance is acceptable${NC}"
    else
        echo -e "${RED}✗ WebSocket performance is poor${NC}"
    fi
    
    log "WEBSOCKET: Connection: ${connection_time}ms"
}

# Function to test system resources
test_system_resources() {
    echo -e "${YELLOW}Testing system resources...${NC}"
    
    # Test CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    echo "CPU usage: ${cpu_usage}%"
    
    # Test memory usage
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    echo "Memory usage: ${memory_usage}%"
    
    # Test disk usage
    local disk_usage=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "Disk usage: ${disk_usage}%"
    
    # Test Docker resource usage
    echo "Docker resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    
    if [ "$cpu_usage" -lt 80 ] && [ "$memory_usage" -lt 80 ] && [ "$disk_usage" -lt 80 ]; then
        echo -e "${GREEN}✓ System resources are healthy${NC}"
    else
        echo -e "${YELLOW}⚠ System resources need attention${NC}"
    fi
    
    log "SYSTEM: CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%"
}

# Function to test load handling
test_load_handling() {
    echo -e "${YELLOW}Testing load handling...${NC}"
    
    # Test concurrent requests
    local concurrent_requests=50
    local duration=10
    
    echo "Testing $concurrent_requests concurrent requests for $duration seconds..."
    
    # Start background processes
    for i in $(seq 1 $concurrent_requests); do
        (
            while [ $(date +%s) -lt $(( $(date +%s) + duration )) ]; do
                curl -f -s "http://localhost:4000/api/health" > /dev/null 2>&1
                sleep 0.1
            done
        ) &
    done
    
    # Wait for test to complete
    sleep $duration
    
    # Check if services are still responsive
    local health_check=$(curl -f -s "http://localhost:4000/api/health" 2>/dev/null | grep -o "healthy" || echo "unhealthy")
    
    if [ "$health_check" = "healthy" ]; then
        echo -e "${GREEN}✓ System handled load successfully${NC}"
    else
        echo -e "${RED}✗ System failed under load${NC}"
    fi
    
    log "LOAD: $concurrent_requests concurrent requests for $duration seconds - $health_check"
}

# Function to generate performance report
generate_report() {
    echo -e "${YELLOW}Generating performance report...${NC}"
    
    {
        echo "LabFace Performance Test Report"
        echo "=============================="
        echo "Date: $(date)"
        echo "Test Duration: $TEST_DURATION seconds"
        echo "Concurrent Users: $CONCURRENT_USERS"
        echo ""
        echo "System Information:"
        echo "=================="
        echo "OS: $(uname -a)"
        echo "CPU: $(nproc) cores"
        echo "Memory: $(free -h | awk 'NR==2{print $2}')"
        echo "Disk: $(df -h . | awk 'NR==2{print $2}')"
        echo ""
        echo "Docker Information:"
        echo "=================="
        docker version
        echo ""
        echo "Service Status:"
        echo "=============="
        docker-compose ps
        echo ""
        echo "Resource Usage:"
        echo "=============="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        echo ""
        echo "Network Status:"
        echo "=============="
        netstat -tlnp | grep LISTEN
        echo ""
        echo "Performance Metrics:"
        echo "==================="
        echo "See performance_test.log for detailed metrics"
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}✓ Performance report generated: $REPORT_FILE${NC}"
    log "REPORT: Generated $REPORT_FILE"
}

# Function to perform full performance test
full_test() {
    echo "Starting comprehensive performance test..."
    echo ""
    
    check_prerequisites
    test_api_performance
    test_database_performance
    test_ml_performance
    test_frontend_performance
    test_websocket_performance
    test_system_resources
    test_load_handling
    generate_report
    
    echo ""
    echo -e "${GREEN}✓ Performance test completed!${NC}"
    log "PERFORMANCE: Test completed successfully"
}

# Function to perform quick test
quick_test() {
    echo "Starting quick performance test..."
    echo ""
    
    check_prerequisites
    test_api_performance
    test_system_resources
    generate_report
    
    echo ""
    echo -e "${GREEN}✓ Quick performance test completed!${NC}"
    log "PERFORMANCE: Quick test completed"
}

# Main execution
main() {
    case "${3:-full}" in
        "full")
            full_test
            ;;
        "quick")
            quick_test
            ;;
        "api")
            test_api_performance
            ;;
        "database")
            test_database_performance
            ;;
        "ml")
            test_ml_performance
            ;;
        "frontend")
            test_frontend_performance
            ;;
        "websocket")
            test_websocket_performance
            ;;
        "system")
            test_system_resources
            ;;
        "load")
            test_load_handling
            ;;
        *)
            echo "Usage: $0 <test_duration> <concurrent_users> [full|quick|api|database|ml|frontend|websocket|system|load]"
            echo ""
            echo "Arguments:"
            echo "  test_duration     - Test duration in seconds (default: 60)"
            echo "  concurrent_users  - Number of concurrent users (default: 10)"
            echo ""
            echo "Commands:"
            echo "  full      - Perform full performance test (default)"
            echo "  quick     - Perform quick performance test"
            echo "  api       - Test API performance only"
            echo "  database  - Test database performance only"
            echo "  ml        - Test ML service performance only"
            echo "  frontend  - Test frontend performance only"
            echo "  websocket - Test WebSocket performance only"
            echo "  system    - Test system resources only"
            echo "  load      - Test load handling only"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
