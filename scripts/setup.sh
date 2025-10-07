#!/bin/bash

# LabFace Setup Script
# This script helps set up the LabFace attendance system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}LabFace Attendance System Setup${NC}"
echo "=================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker
check_docker() {
    echo -e "${YELLOW}Checking Docker installation...${NC}"
    
    if command_exists docker; then
        echo -e "${GREEN}✓ Docker is installed${NC}"
        docker --version
    else
        echo -e "${RED}✗ Docker is not installed${NC}"
        echo "Please install Docker from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if command_exists docker-compose; then
        echo -e "${GREEN}✓ Docker Compose is installed${NC}"
        docker-compose --version
    else
        echo -e "${RED}✗ Docker Compose is not installed${NC}"
        echo "Please install Docker Compose from: https://docs.docker.com/compose/install/"
        exit 1
    fi
}

# Function to setup environment
setup_environment() {
    echo -e "${YELLOW}Setting up environment...${NC}"
    
    if [ ! -f .env ]; then
        if [ -f env.example ]; then
            cp env.example .env
            echo -e "${GREEN}✓ Created .env file from template${NC}"
            echo -e "${YELLOW}⚠️  Please edit .env file with your configuration${NC}"
        else
            echo -e "${RED}✗ env.example file not found${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ .env file already exists${NC}"
    fi
}

# Function to generate secure secrets
generate_secrets() {
    echo -e "${YELLOW}Generating secure secrets...${NC}"
    
    # Generate JWT secret
    JWT_SECRET=$(openssl rand -base64 32)
    echo "JWT_SECRET=$JWT_SECRET" >> .env
    
    # Generate database password
    DB_PASSWORD=$(openssl rand -base64 32)
    echo "DB_PASSWORD=$DB_PASSWORD" >> .env
    
    # Generate MinIO secrets
    MINIO_ACCESS_KEY=$(openssl rand -hex 16)
    MINIO_SECRET_KEY=$(openssl rand -hex 32)
    echo "MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY" >> .env
    echo "MINIO_SECRET_KEY=$MINIO_SECRET_KEY" >> .env
    
    echo -e "${GREEN}✓ Generated secure secrets${NC}"
}

# Function to create necessary directories
create_directories() {
    echo -e "${YELLOW}Creating necessary directories...${NC}"
    
    mkdir -p logs
    mkdir -p data/mariadb
    mkdir -p data/minio
    mkdir -p data/ml-models
    
    echo -e "${GREEN}✓ Created necessary directories${NC}"
}

# Function to build and start services
start_services() {
    echo -e "${YELLOW}Building and starting services...${NC}"
    
    # Build images
    echo "Building Docker images..."
    docker-compose build
    
    # Start services
    echo "Starting services..."
    docker-compose up -d
    
    echo -e "${GREEN}✓ Services started successfully${NC}"
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
    
    echo -e "${GREEN}✓ All services are ready${NC}"
}

# Function to run database migrations
run_migrations() {
    echo -e "${YELLOW}Running database migrations...${NC}"
    
    # Wait a bit more for database to be fully ready
    sleep 10
    
    # Run migrations
    docker-compose exec backend npm run migrate
    
    echo -e "${GREEN}✓ Database migrations completed${NC}"
}

# Function to show service status
show_status() {
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
}

# Function to show next steps
show_next_steps() {
    echo -e "${GREEN}Setup completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "==========="
    echo ""
    echo "1. Access the application:"
    echo "   - Open http://localhost:3000 in your browser"
    echo ""
    echo "2. Create your first account:"
    echo "   - Register as a Professor"
    echo "   - Create a class"
    echo "   - Start an attendance session"
    echo ""
    echo "3. Configure cameras (optional):"
    echo "   - Update camera RTSP URLs in .env file"
    echo "   - Test camera connectivity with: ./scripts/camera-test.sh"
    echo ""
    echo "4. Security considerations:"
    echo "   - Change default passwords in production"
    echo "   - Configure HTTPS for production deployment"
    echo "   - Review SECURITY.md for best practices"
    echo ""
    echo "5. Monitor the system:"
    echo "   - Check logs: docker-compose logs -f"
    echo "   - Monitor service health: docker-compose ps"
    echo ""
}

# Main execution
main() {
    echo "Starting LabFace setup..."
    echo ""
    
    # Check prerequisites
    check_docker
    
    # Setup environment
    setup_environment
    
    # Generate secrets
    generate_secrets
    
    # Create directories
    create_directories
    
    # Start services
    start_services
    
    # Wait for services
    wait_for_services
    
    # Run migrations
    run_migrations
    
    # Show status
    show_status
    
    # Show next steps
    show_next_steps
}

# Run main function
main "$@"
