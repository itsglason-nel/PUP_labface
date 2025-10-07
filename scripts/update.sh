#!/bin/bash

# LabFace System Update Script
# This script updates the LabFace system to the latest version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UPDATE_LOG="logs/update.log"
BACKUP_DIR="./backups"

echo -e "${BLUE}LabFace System Update${NC}"
echo "====================="
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$UPDATE_LOG"
}

# Function to check for updates
check_updates() {
    echo -e "${YELLOW}Checking for updates...${NC}"
    
    # Check if git repository
    if [ -d ".git" ]; then
        git fetch origin
        local behind=$(git rev-list --count HEAD..origin/main)
        
        if [ "$behind" -gt 0 ]; then
            echo -e "${YELLOW}⚠ $behind commits behind origin/main${NC}"
            log "UPDATE: $behind commits available"
            return 0
        else
            echo -e "${GREEN}✓ System is up to date${NC}"
            log "UPDATE: System up to date"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Not a git repository, cannot check for updates${NC}"
        log "UPDATE: Not a git repository"
        return 1
    fi
}

# Function to create update backup
create_backup() {
    echo -e "${YELLOW}Creating backup before update...${NC}"
    
    if [ -f "scripts/backup.sh" ]; then
        ./scripts/backup.sh backup
        echo -e "${GREEN}✓ Backup created successfully${NC}"
        log "BACKUP: Created successfully"
    else
        echo -e "${YELLOW}⚠ Backup script not found, skipping backup${NC}"
        log "BACKUP: Script not found, skipped"
    fi
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}Stopping services...${NC}"
    
    docker-compose down
    echo -e "${GREEN}✓ Services stopped${NC}"
    log "SERVICES: Stopped successfully"
}

# Function to pull updates
pull_updates() {
    echo -e "${YELLOW}Pulling updates...${NC}"
    
    if [ -d ".git" ]; then
        git pull origin main
        echo -e "${GREEN}✓ Updates pulled successfully${NC}"
        log "UPDATE: Pulled successfully"
    else
        echo -e "${RED}✗ Not a git repository${NC}"
        log "UPDATE: Not a git repository"
        exit 1
    fi
}

# Function to update dependencies
update_dependencies() {
    echo -e "${YELLOW}Updating dependencies...${NC}"
    
    # Update backend dependencies
    if [ -f "backend/package.json" ]; then
        echo "Updating backend dependencies..."
        cd backend
        npm update
        cd ..
    fi
    
    # Update frontend dependencies
    if [ -f "frontend/package.json" ]; then
        echo "Updating frontend dependencies..."
        cd frontend
        npm update
        cd ..
    fi
    
    # Update ML service dependencies
    if [ -f "ml-service/requirements.txt" ]; then
        echo "Updating ML service dependencies..."
        cd ml-service
        pip install --upgrade -r requirements.txt
        cd ..
    fi
    
    echo -e "${GREEN}✓ Dependencies updated${NC}"
    log "DEPENDENCIES: Updated successfully"
}

# Function to rebuild images
rebuild_images() {
    echo -e "${YELLOW}Rebuilding Docker images...${NC}"
    
    docker-compose build --no-cache
    echo -e "${GREEN}✓ Images rebuilt${NC}"
    log "IMAGES: Rebuilt successfully"
}

# Function to run migrations
run_migrations() {
    echo -e "${YELLOW}Running database migrations...${NC}"
    
    # Start services
    docker-compose up -d mariadb minio
    
    # Wait for database
    echo "Waiting for database to be ready..."
    timeout 60 bash -c 'until docker-compose exec mariadb mysqladmin ping -h localhost --silent; do sleep 2; done'
    
    # Run migrations
    docker-compose exec backend npm run migrate
    
    echo -e "${GREEN}✓ Migrations completed${NC}"
    log "MIGRATIONS: Completed successfully"
}

# Function to start services
start_services() {
    echo -e "${YELLOW}Starting services...${NC}"
    
    docker-compose up -d
    echo -e "${GREEN}✓ Services started${NC}"
    log "SERVICES: Started successfully"
}

# Function to wait for services
wait_for_services() {
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    
    local services=("frontend:3000" "backend:4000" "ml-service:8000")
    
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        
        echo "Waiting for $name..."
        timeout 60 bash -c "until curl -f http://localhost:$port >/dev/null 2>&1; do sleep 2; done"
        echo -e "${GREEN}✓ $name is ready${NC}"
    done
    
    log "SERVICES: All services ready"
}

# Function to run health checks
run_health_checks() {
    echo -e "${YELLOW}Running health checks...${NC}"
    
    # Check frontend
    if curl -f http://localhost:3000 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend is healthy${NC}"
    else
        echo -e "${RED}✗ Frontend health check failed${NC}"
        return 1
    fi
    
    # Check backend
    if curl -f http://localhost:4000/api/health >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Backend is healthy${NC}"
    else
        echo -e "${RED}✗ Backend health check failed${NC}"
        return 1
    fi
    
    # Check ML service
    if curl -f http://localhost:8000/health >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ML Service is healthy${NC}"
    else
        echo -e "${RED}✗ ML Service health check failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ All health checks passed${NC}"
    log "HEALTH: All checks passed"
}

# Function to cleanup old images
cleanup_images() {
    echo -e "${YELLOW}Cleaning up old Docker images...${NC}"
    
    # Remove unused images
    docker image prune -f
    
    # Remove unused volumes
    docker volume prune -f
    
    echo -e "${GREEN}✓ Cleanup completed${NC}"
    log "CLEANUP: Completed successfully"
}

# Function to show update status
show_status() {
    echo ""
    echo -e "${BLUE}Update Status:${NC}"
    echo "=============="
    docker-compose ps
    echo ""
    
    echo -e "${BLUE}Service URLs:${NC}"
    echo "============="
    echo "Frontend: http://localhost:3000"
    echo "Backend API: http://localhost:4000"
    echo "ML Service: http://localhost:8000"
    echo "MinIO Console: http://localhost:9001"
    echo "Database Admin: http://localhost:8080"
    echo ""
}

# Function to rollback update
rollback_update() {
    echo -e "${YELLOW}Rolling back update...${NC}"
    
    # Stop services
    docker-compose down
    
    # Restore from backup
    if [ -f "scripts/backup.sh" ]; then
        local latest_backup=$(ls -t $BACKUP_DIR/labface_backup_*.tar.gz | head -n1)
        if [ -n "$latest_backup" ]; then
            ./scripts/backup.sh restore "$latest_backup"
            echo -e "${GREEN}✓ Rollback completed${NC}"
            log "ROLLBACK: Completed successfully"
        else
            echo -e "${RED}✗ No backup found for rollback${NC}"
            log "ROLLBACK: No backup found"
            exit 1
        fi
    else
        echo -e "${RED}✗ Backup script not found${NC}"
        log "ROLLBACK: Backup script not found"
        exit 1
    fi
}

# Main execution
main() {
    case "${1:-update}" in
        "check")
            check_updates
            ;;
        "update")
            echo "Starting update process..."
            check_updates || exit 0
            create_backup
            stop_services
            pull_updates
            update_dependencies
            rebuild_images
            run_migrations
            start_services
            wait_for_services
            run_health_checks
            cleanup_images
            show_status
            echo -e "${GREEN}✓ Update completed successfully!${NC}"
            log "UPDATE: Completed successfully"
            ;;
        "rollback")
            rollback_update
            ;;
        *)
            echo "Usage: $0 [check|update|rollback]"
            echo ""
            echo "Commands:"
            echo "  check    - Check for available updates"
            echo "  update   - Update the system"
            echo "  rollback - Rollback to previous version"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
