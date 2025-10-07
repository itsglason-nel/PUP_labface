#!/bin/bash

# LabFace Stop Script
# This script stops the LabFace system gracefully

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STOP_LOG="logs/stop.log"
GRACEFUL_TIMEOUT=${1:-30}

echo -e "${BLUE}LabFace Stop Script${NC}"
echo "==================="
echo "Graceful timeout: $GRACEFUL_TIMEOUT seconds"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$STOP_LOG"
}

# Function to check if services are running
check_services_running() {
    echo -e "${YELLOW}Checking if services are running...${NC}"
    
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✓ Services are running${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ No services are running${NC}"
        return 1
    fi
}

# Function to stop services gracefully
stop_services_gracefully() {
    echo -e "${YELLOW}Stopping services gracefully...${NC}"
    
    # Stop services with graceful timeout
    docker-compose stop -t $GRACEFUL_TIMEOUT
    
    echo -e "${GREEN}✓ Services stopped gracefully${NC}"
    log "SERVICES: Stopped gracefully with timeout $GRACEFUL_TIMEOUT"
}

# Function to stop services forcefully
stop_services_forcefully() {
    echo -e "${YELLOW}Stopping services forcefully...${NC}"
    
    # Stop services immediately
    docker-compose kill
    
    echo -e "${GREEN}✓ Services stopped forcefully${NC}"
    log "SERVICES: Stopped forcefully"
}

# Function to remove containers
remove_containers() {
    echo -e "${YELLOW}Removing containers...${NC}"
    
    # Remove containers
    docker-compose rm -f
    
    echo -e "${GREEN}✓ Containers removed${NC}"
    log "CONTAINERS: Removed successfully"
}

# Function to stop specific service
stop_specific_service() {
    local service_name="$2"
    
    if [ -z "$service_name" ]; then
        echo -e "${RED}Please specify service name${NC}"
        echo "Available services: frontend, backend, ml-service, mariadb, minio, adminer"
        exit 1
    fi
    
    echo -e "${YELLOW}Stopping $service_name service...${NC}"
    
    docker-compose stop "$service_name"
    
    echo -e "${GREEN}✓ $service_name service stopped${NC}"
    log "SERVICE: $service_name stopped"
}

# Function to backup before stop
backup_before_stop() {
    echo -e "${YELLOW}Creating backup before stop...${NC}"
    
    if [ -f "scripts/backup.sh" ]; then
        ./scripts/backup.sh quick
        echo -e "${GREEN}✓ Backup created successfully${NC}"
        log "BACKUP: Created before stop"
    else
        echo -e "${YELLOW}⚠ Backup script not found, skipping backup${NC}"
        log "BACKUP: Script not found, skipped"
    fi
}

# Function to cleanup resources
cleanup_resources() {
    echo -e "${YELLOW}Cleaning up resources...${NC}"
    
    # Remove unused containers
    local unused_containers=$(docker container ls -a --filter "status=exited" -q)
    if [ -n "$unused_containers" ]; then
        echo "Removing unused containers..."
        docker container rm $unused_containers
    fi
    
    # Remove unused images
    local unused_images=$(docker images --filter "dangling=true" -q)
    if [ -n "$unused_images" ]; then
        echo "Removing unused images..."
        docker rmi $unused_images
    fi
    
    # Remove unused volumes
    local unused_volumes=$(docker volume ls --filter "dangling=true" -q)
    if [ -n "$unused_volumes" ]; then
        echo "Removing unused volumes..."
        docker volume rm $unused_volumes
    fi
    
    echo -e "${GREEN}✓ Resources cleaned up${NC}"
    log "CLEANUP: Resources cleaned up"
}

# Function to show stop summary
show_stop_summary() {
    echo ""
    echo -e "${BLUE}Stop Summary:${NC}"
    echo "============="
    
    # Show remaining containers
    echo "Remaining containers:"
    docker-compose ps 2>/dev/null || echo "No containers found"
    
    # Show Docker resource usage
    echo ""
    echo "Docker resource usage:"
    docker system df 2>/dev/null || echo "Docker not available"
    
    # Show disk usage
    echo ""
    echo "Disk usage:"
    df -h . | tail -n 1
    
    echo ""
    echo -e "${GREEN}✓ LabFace system stopped successfully!${NC}"
    log "STOP: System stopped successfully"
}

# Function to perform full stop
full_stop() {
    echo "Stopping LabFace system..."
    echo ""
    
    if ! check_services_running; then
        echo -e "${YELLOW}⚠ No services are running${NC}"
        return 0
    fi
    
    backup_before_stop
    stop_services_gracefully
    remove_containers
    cleanup_resources
    show_stop_summary
    
    echo -e "${GREEN}✓ LabFace system stopped successfully!${NC}"
    log "STOP: Full stop completed successfully"
}

# Function to perform quick stop
quick_stop() {
    echo "Stopping LabFace system (quick mode)..."
    echo ""
    
    if ! check_services_running; then
        echo -e "${YELLOW}⚠ No services are running${NC}"
        return 0
    fi
    
    stop_services_gracefully
    show_stop_summary
    
    echo -e "${GREEN}✓ LabFace system stopped successfully!${NC}"
    log "STOP: Quick stop completed successfully"
}

# Function to perform force stop
force_stop() {
    echo "Force stopping LabFace system..."
    echo ""
    
    if ! check_services_running; then
        echo -e "${YELLOW}⚠ No services are running${NC}"
        return 0
    fi
    
    stop_services_forcefully
    remove_containers
    cleanup_resources
    show_stop_summary
    
    echo -e "${GREEN}✓ LabFace system force stopped!${NC}"
    log "STOP: Force stop completed successfully"
}

# Function to perform clean stop
clean_stop() {
    echo "Performing clean stop of LabFace system..."
    echo ""
    
    if ! check_services_running; then
        echo -e "${YELLOW}⚠ No services are running${NC}"
        return 0
    fi
    
    backup_before_stop
    stop_services_gracefully
    remove_containers
    cleanup_resources
    
    # Remove all LabFace-related containers
    docker-compose down --volumes --remove-orphans
    
    # Remove LabFace network
    docker network rm labface-network 2>/dev/null || true
    
    # Remove LabFace volumes
    docker volume rm labface_mariadb_data 2>/dev/null || true
    docker volume rm labface_minio_data 2>/dev/null || true
    docker volume rm labface_ml_models 2>/dev/null || true
    
    show_stop_summary
    
    echo -e "${GREEN}✓ LabFace system clean stopped!${NC}"
    log "STOP: Clean stop completed successfully"
}

# Main execution
main() {
    case "${2:-full}" in
        "full")
            full_stop
            ;;
        "quick")
            quick_stop
            ;;
        "force")
            force_stop
            ;;
        "clean")
            clean_stop
            ;;
        "stop")
            stop_specific_service "$@"
            ;;
        "status")
            check_services_running
            ;;
        "cleanup")
            cleanup_resources
            ;;
        *)
            echo "Usage: $0 <graceful_timeout> [full|quick|force|clean|stop <service>|status|cleanup]"
            echo ""
            echo "Arguments:"
            echo "  graceful_timeout  - Graceful stop timeout in seconds (default: 30)"
            echo ""
            echo "Commands:"
            echo "  full     - Perform full stop (default)"
            echo "  quick    - Perform quick stop"
            echo "  force    - Force stop all services"
            echo "  clean    - Clean stop (remove all data)"
            echo "  stop     - Stop specific service"
            echo "  status   - Check if services are running"
            echo "  cleanup  - Clean up resources only"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
