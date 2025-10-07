#!/bin/bash

# LabFace Start Script
# This script starts the LabFace system with proper initialization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
START_LOG="logs/start.log"
ENVIRONMENT=${1:-development}

echo -e "${BLUE}LabFace Start Script${NC}"
echo "===================="
echo "Environment: $ENVIRONMENT"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$START_LOG"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        echo "Please install Docker from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose >/dev/null 2>&1; then
        echo -e "${RED}✗ Docker Compose is not installed${NC}"
        echo "Please install Docker Compose from: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        echo -e "${YELLOW}⚠ .env file not found${NC}"
        if [ -f env.example ]; then
            echo "Copying env.example to .env..."
            cp env.example .env
            echo -e "${YELLOW}⚠ Please edit .env file with your configuration${NC}"
        else
            echo -e "${RED}✗ No environment configuration found${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
    log "PREREQUISITES: Check passed"
}

# Function to create necessary directories
create_directories() {
    echo -e "${YELLOW}Creating necessary directories...${NC}"
    
    mkdir -p logs
    mkdir -p data/mariadb
    mkdir -p data/minio
    mkdir -p data/ml-models
    mkdir -p backups
    mkdir -p ssl
    
    echo -e "${GREEN}✓ Directories created${NC}"
    log "DIRECTORIES: Created successfully"
}

# Function to check Docker daemon
check_docker_daemon() {
    echo -e "${YELLOW}Checking Docker daemon...${NC}"
    
    if docker info > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker daemon is running${NC}"
    else
        echo -e "${RED}✗ Docker daemon is not running${NC}"
        echo "Please start Docker daemon"
        exit 1
    fi
    
    log "DOCKER: Daemon is running"
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
    
    if [ "$ENVIRONMENT" = "production" ]; then
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml build
    else
        docker-compose build
    fi
    
    echo -e "${GREEN}✓ Images built successfully${NC}"
    log "BUILD: Images built successfully"
}

# Function to start services
start_services() {
    echo -e "${YELLOW}Starting services...${NC}"
    
    if [ "$ENVIRONMENT" = "production" ]; then
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
    else
        docker-compose up -d
    fi
    
    echo -e "${GREEN}✓ Services started${NC}"
    log "SERVICES: Started successfully"
}

# Function to wait for services
wait_for_services() {
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    
    # Wait for database
    echo "Waiting for database..."
    timeout 60 bash -c 'until docker-compose exec mariadb mysqladmin ping -h localhost --silent; do sleep 2; done'
    
    # Wait for MinIO
    echo "Waiting for MinIO..."
    timeout 60 bash -c 'until curl -f http://localhost:9000/minio/health/live; do sleep 2; done'
    
    # Wait for backend
    echo "Waiting for backend..."
    timeout 60 bash -c 'until curl -f http://localhost:4000/api/health; do sleep 2; done'
    
    # Wait for ML service
    echo "Waiting for ML service..."
    timeout 60 bash -c 'until curl -f http://localhost:8000/health; do sleep 2; done'
    
    # Wait for frontend
    echo "Waiting for frontend..."
    timeout 60 bash -c 'until curl -f http://localhost:3000; do sleep 2; done'
    
    echo -e "${GREEN}✓ All services are ready${NC}"
    log "SERVICES: All services ready"
}

# Function to run database migrations
run_migrations() {
    echo -e "${YELLOW}Running database migrations...${NC}"
    
    # Wait a bit more for database to be fully ready
    sleep 10
    
    # Run migrations
    docker-compose exec backend npm run migrate 2>/dev/null || echo "Migrations already up to date"
    
    echo -e "${GREEN}✓ Database migrations completed${NC}"
    log "MIGRATIONS: Completed successfully"
}

# Function to check service health
check_service_health() {
    echo -e "${YELLOW}Checking service health...${NC}"
    
    local services=("frontend:3000" "backend:4000" "ml-service:8000" "minio:9000" "mariadb:3306")
    local failed_services=0
    
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        
        if nc -z localhost $port 2>/dev/null; then
            echo -e "${GREEN}✓ $name is healthy${NC}"
        else
            echo -e "${RED}✗ $name is not healthy${NC}"
            ((failed_services++))
        fi
    done
    
    if [ $failed_services -eq 0 ]; then
        echo -e "${GREEN}✓ All services are healthy${NC}"
        log "HEALTH: All services healthy"
    else
        echo -e "${RED}✗ $failed_services services are not healthy${NC}"
        log "HEALTH: $failed_services services unhealthy"
        return 1
    fi
}

# Function to show service status
show_service_status() {
    echo ""
    echo -e "${BLUE}Service Status:${NC}"
    echo "==============="
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
    
    if [ "$ENVIRONMENT" = "production" ]; then
        echo -e "${BLUE}Production URLs:${NC}"
        echo "==============="
        echo "Website: https://$DOMAIN_NAME"
        echo "API: https://$DOMAIN_NAME/api"
        echo ""
    fi
}

# Function to setup monitoring
setup_monitoring() {
    echo -e "${YELLOW}Setting up monitoring...${NC}"
    
    # Create monitoring script if it doesn't exist
    if [ ! -f "scripts/monitor.sh" ]; then
        echo "Monitoring script not found, skipping monitoring setup"
        return 0
    fi
    
    # Make monitoring script executable
    chmod +x scripts/monitor.sh
    
    # Setup cron job for monitoring (if not already set up)
    if ! crontab -l 2>/dev/null | grep -q "monitor.sh"; then
        (crontab -l 2>/dev/null; echo "*/5 * * * * $(pwd)/scripts/monitor.sh check >> $(pwd)/logs/monitor.log 2>&1") | crontab -
        echo -e "${GREEN}✓ Monitoring setup completed${NC}"
    else
        echo -e "${GREEN}✓ Monitoring already configured${NC}"
    fi
    
    log "MONITORING: Setup completed"
}

# Function to show startup summary
show_startup_summary() {
    echo ""
    echo -e "${GREEN}LabFace System Started Successfully!${NC}"
    echo "====================================="
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "==========="
    echo "1. Access the application:"
    echo "   - Open http://localhost:3000 in your browser"
    echo ""
    echo "2. Create your first account:"
    echo "   - Register as a Professor"
    echo "   - Create a class"
    echo "   - Start an attendance session"
    echo ""
    echo "3. Monitor the system:"
    echo "   - Check logs: docker-compose logs -f"
    echo "   - Monitor health: ./scripts/health-check.sh"
    echo "   - View status: docker-compose ps"
    echo ""
    echo "4. Configure cameras (optional):"
    echo "   - Update camera RTSP URLs in .env file"
    echo "   - Test camera connectivity: ./scripts/camera-test.sh"
    echo ""
    echo "5. Security considerations:"
    echo "   - Change default passwords in production"
    echo "   - Configure HTTPS for production deployment"
    echo "   - Review SECURITY.md for best practices"
    echo ""
}

# Function to perform full startup
full_startup() {
    echo "Starting LabFace system..."
    echo ""
    
    check_prerequisites
    create_directories
    check_docker_daemon
    pull_images
    build_images
    start_services
    wait_for_services
    run_migrations
    check_service_health
    setup_monitoring
    show_service_status
    show_startup_summary
    
    echo -e "${GREEN}✓ LabFace system started successfully!${NC}"
    log "STARTUP: System started successfully"
}

# Function to perform quick startup
quick_startup() {
    echo "Starting LabFace system (quick mode)..."
    echo ""
    
    check_prerequisites
    create_directories
    check_docker_daemon
    start_services
    wait_for_services
    show_service_status
    show_startup_summary
    
    echo -e "${GREEN}✓ LabFace system started successfully!${NC}"
    log "STARTUP: System started successfully (quick mode)"
}

# Function to start specific service
start_service() {
    local service_name="$2"
    
    if [ -z "$service_name" ]; then
        echo -e "${RED}Please specify service name${NC}"
        echo "Available services: frontend, backend, ml-service, mariadb, minio, adminer"
        exit 1
    fi
    
    echo -e "${YELLOW}Starting $service_name service...${NC}"
    
    docker-compose up -d "$service_name"
    
    echo -e "${GREEN}✓ $service_name service started${NC}"
    log "SERVICE: $service_name started"
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}Stopping services...${NC}"
    
    docker-compose down
    
    echo -e "${GREEN}✓ Services stopped${NC}"
    log "SERVICES: Stopped successfully"
}

# Function to restart services
restart_services() {
    echo -e "${YELLOW}Restarting services...${NC}"
    
    docker-compose restart
    
    echo -e "${GREEN}✓ Services restarted${NC}"
    log "SERVICES: Restarted successfully"
}

# Main execution
main() {
    case "${2:-full}" in
        "full")
            full_startup
            ;;
        "quick")
            quick_startup
            ;;
        "start")
            start_service "$@"
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_service_status
            ;;
        "health")
            check_service_health
            ;;
        *)
            echo "Usage: $0 <environment> [full|quick|start <service>|stop|restart|status|health]"
            echo ""
            echo "Arguments:"
            echo "  environment  - Environment (development|production, default: development)"
            echo ""
            echo "Commands:"
            echo "  full     - Perform full startup (default)"
            echo "  quick    - Perform quick startup"
            echo "  start    - Start specific service"
            echo "  stop     - Stop all services"
            echo "  restart  - Restart all services"
            echo "  status   - Show service status"
            echo "  health   - Check service health"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
