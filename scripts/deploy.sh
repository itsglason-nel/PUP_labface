#!/bin/bash

# LabFace Production Deployment Script
# This script handles production deployment of the LabFace system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-production}
BACKUP_DIR="./backups"
LOG_FILE="logs/deploy.log"

echo -e "${BLUE}LabFace Production Deployment${NC}"
echo "==============================="
echo "Environment: $ENVIRONMENT"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        echo -e "${RED}✗ Docker Compose is not installed${NC}"
        exit 1
    fi
    
    # Check environment file
    if [ ! -f .env ]; then
        echo -e "${RED}✗ .env file not found${NC}"
        echo "Please create .env file from env.example"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
    log "PREREQUISITES: Check passed"
}

# Function to create backup
create_backup() {
    echo -e "${YELLOW}Creating backup before deployment...${NC}"
    
    if [ -f "scripts/backup.sh" ]; then
        ./scripts/backup.sh backup
        echo -e "${GREEN}✓ Backup created successfully${NC}"
        log "BACKUP: Created successfully"
    else
        echo -e "${YELLOW}⚠ Backup script not found, skipping backup${NC}"
        log "BACKUP: Script not found, skipped"
    fi
}

# Function to pull latest images
pull_images() {
    echo -e "${YELLOW}Pulling latest images...${NC}"
    
    docker-compose pull
    echo -e "${GREEN}✓ Images pulled successfully${NC}"
    log "IMAGES: Pulled successfully"
}

# Function to build images
build_images() {
    echo -e "${YELLOW}Building images...${NC}"
    
    docker-compose build --no-cache
    echo -e "${GREEN}✓ Images built successfully${NC}"
    log "BUILD: Images built successfully"
}

# Function to run database migrations
run_migrations() {
    echo -e "${YELLOW}Running database migrations...${NC}"
    
    # Wait for database to be ready
    echo "Waiting for database to be ready..."
    timeout 60 bash -c 'until docker-compose exec mariadb mysqladmin ping -h localhost --silent; do sleep 2; done'
    
    # Run migrations
    docker-compose exec backend npm run migrate
    
    echo -e "${GREEN}✓ Database migrations completed${NC}"
    log "MIGRATIONS: Completed successfully"
}

# Function to deploy services
deploy_services() {
    echo -e "${YELLOW}Deploying services...${NC}"
    
    if [ "$ENVIRONMENT" = "production" ]; then
        # Production deployment
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
    else
        # Development deployment
        docker-compose up -d
    fi
    
    echo -e "${GREEN}✓ Services deployed successfully${NC}"
    log "DEPLOY: Services deployed successfully"
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

# Function to setup SSL (if configured)
setup_ssl() {
    if [ -n "$SSL_CERT_PATH" ] && [ -n "$SSL_KEY_PATH" ]; then
        echo -e "${YELLOW}Setting up SSL certificates...${NC}"
        
        # Create SSL directory
        mkdir -p ssl
        
        # Copy certificates
        cp "$SSL_CERT_PATH" ssl/cert.pem
        cp "$SSL_KEY_PATH" ssl/key.pem
        
        # Set proper permissions
        chmod 600 ssl/key.pem
        chmod 644 ssl/cert.pem
        
        echo -e "${GREEN}✓ SSL certificates configured${NC}"
        log "SSL: Certificates configured"
    else
        echo -e "${YELLOW}⚠ SSL certificates not configured${NC}"
        log "SSL: Not configured"
    fi
}

# Function to configure firewall
configure_firewall() {
    echo -e "${YELLOW}Configuring firewall...${NC}"
    
    if command -v ufw >/dev/null 2>&1; then
        # Allow necessary ports
        ufw allow 22/tcp    # SSH
        ufw allow 80/tcp   # HTTP
        ufw allow 443/tcp  # HTTPS
        
        # Deny unnecessary ports
        ufw deny 3000/tcp  # Frontend (use reverse proxy)
        ufw deny 4000/tcp  # Backend (use reverse proxy)
        ufw deny 8000/tcp  # ML Service (use reverse proxy)
        ufw deny 3306/tcp  # Database (internal only)
        ufw deny 9000/tcp  # MinIO (internal only)
        
        echo -e "${GREEN}✓ Firewall configured${NC}"
        log "FIREWALL: Configured successfully"
    else
        echo -e "${YELLOW}⚠ UFW not found, skipping firewall configuration${NC}"
        log "FIREWALL: UFW not found, skipped"
    fi
}

# Function to setup monitoring
setup_monitoring() {
    echo -e "${YELLOW}Setting up monitoring...${NC}"
    
    # Create monitoring script
    if [ -f "scripts/monitor.sh" ]; then
        chmod +x scripts/monitor.sh
        
        # Setup cron job for monitoring
        (crontab -l 2>/dev/null; echo "*/5 * * * * $(pwd)/scripts/monitor.sh check >> $(pwd)/logs/monitor.log 2>&1") | crontab -
        
        echo -e "${GREEN}✓ Monitoring configured${NC}"
        log "MONITORING: Configured successfully"
    else
        echo -e "${YELLOW}⚠ Monitoring script not found${NC}"
        log "MONITORING: Script not found"
    fi
}

# Function to show deployment status
show_status() {
    echo ""
    echo -e "${BLUE}Deployment Status:${NC}"
    echo "=================="
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
    
    if [ -n "$DOMAIN_NAME" ]; then
        echo -e "${BLUE}Production URLs:${NC}"
        echo "==============="
        echo "Website: https://$DOMAIN_NAME"
        echo "API: https://$DOMAIN_NAME/api"
        echo ""
    fi
}

# Function to rollback deployment
rollback() {
    echo -e "${YELLOW}Rolling back deployment...${NC}"
    
    # Stop current services
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
    case "${2:-deploy}" in
        "deploy")
            echo "Starting deployment process..."
            check_prerequisites
            create_backup
            pull_images
            build_images
            setup_ssl
            deploy_services
            wait_for_services
            run_migrations
            run_health_checks
            configure_firewall
            setup_monitoring
            show_status
            echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
            log "DEPLOYMENT: Completed successfully"
            ;;
        "rollback")
            rollback
            ;;
        *)
            echo "Usage: $0 <environment> [deploy|rollback]"
            echo ""
            echo "Environments:"
            echo "  production  - Production deployment with optimizations"
            echo "  development - Development deployment"
            echo ""
            echo "Commands:"
            echo "  deploy   - Deploy the application"
            echo "  rollback - Rollback to previous version"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
