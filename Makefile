# LabFace Attendance System Makefile
# This Makefile provides convenient commands for managing the LabFace system

.PHONY: help setup start stop restart status health clean build test deploy backup restore logs monitor security ssl

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Configuration
COMPOSE_FILE := docker-compose.yml
COMPOSE_PROD_FILE := docker-compose.prod.yml
ENV_FILE := .env

help: ## Show this help message
	@echo "$(BLUE)LabFace Attendance System - Available Commands$(NC)"
	@echo "=============================================="
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  make setup    # Initial setup"
	@echo "  make start    # Start services"
	@echo "  make status   # Check status"
	@echo ""

setup: ## Initial system setup
	@echo "$(BLUE)Setting up LabFace system...$(NC)"
	@chmod +x scripts/*.sh
	@./scripts/setup.sh
	@echo "$(GREEN)✓ Setup completed!$(NC)"

start: ## Start all services
	@echo "$(BLUE)Starting LabFace services...$(NC)"
	@./scripts/start.sh
	@echo "$(GREEN)✓ Services started!$(NC)"

stop: ## Stop all services
	@echo "$(BLUE)Stopping LabFace services...$(NC)"
	@./scripts/stop.sh
	@echo "$(GREEN)✓ Services stopped!$(NC)"

restart: ## Restart all services
	@echo "$(BLUE)Restarting LabFace services...$(NC)"
	@./scripts/stop.sh quick
	@./scripts/start.sh quick
	@echo "$(GREEN)✓ Services restarted!$(NC)"

status: ## Show service status
	@echo "$(BLUE)LabFace Service Status$(NC)"
	@echo "========================"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)Service URLs:$(NC)"
	@echo "Frontend: http://localhost:3000"
	@echo "Backend:  http://localhost:4000"
	@echo "ML Service: http://localhost:8000"
	@echo "MinIO: http://localhost:9001"
	@echo "Adminer: http://localhost:8080"

health: ## Check system health
	@echo "$(BLUE)Checking system health...$(NC)"
	@./scripts/health-check.sh
	@echo "$(GREEN)✓ Health check completed!$(NC)"

build: ## Build all Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	@docker-compose build
	@echo "$(GREEN)✓ Images built!$(NC)"

build-prod: ## Build production images
	@echo "$(BLUE)Building production images...$(NC)"
	@docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_PROD_FILE) build
	@echo "$(GREEN)✓ Production images built!$(NC)"

test: ## Run tests
	@echo "$(BLUE)Running tests...$(NC)"
	@cd backend && npm test
	@cd frontend && npm test
	@cd ml-service && python -m pytest
	@echo "$(GREEN)✓ Tests completed!$(NC)"

clean: ## Clean up system resources
	@echo "$(BLUE)Cleaning up system...$(NC)"
	@./scripts/cleanup.sh
	@echo "$(GREEN)✓ Cleanup completed!$(NC)"

logs: ## Show service logs
	@echo "$(BLUE)Showing service logs...$(NC)"
	@docker-compose logs -f

logs-backend: ## Show backend logs
	@docker-compose logs -f backend

logs-frontend: ## Show frontend logs
	@docker-compose logs -f frontend

logs-ml: ## Show ML service logs
	@docker-compose logs -f ml-service

logs-db: ## Show database logs
	@docker-compose logs -f mariadb

logs-minio: ## Show MinIO logs
	@docker-compose logs -f minio

monitor: ## Start continuous monitoring
	@echo "$(BLUE)Starting continuous monitoring...$(NC)"
	@./scripts/monitor.sh monitor

backup: ## Create system backup
	@echo "$(BLUE)Creating system backup...$(NC)"
	@./scripts/backup.sh
	@echo "$(GREEN)✓ Backup completed!$(NC)"

restore: ## Restore from backup
	@echo "$(BLUE)Restoring from backup...$(NC)"
	@./scripts/backup.sh restore
	@echo "$(GREEN)✓ Restore completed!$(NC)"

security: ## Run security audit
	@echo "$(BLUE)Running security audit...$(NC)"
	@./scripts/security-audit.sh
	@echo "$(GREEN)✓ Security audit completed!$(NC)"

ssl: ## Setup SSL certificates
	@echo "$(BLUE)Setting up SSL certificates...$(NC)"
	@./scripts/ssl-setup.sh
	@echo "$(GREEN)✓ SSL setup completed!$(NC)"

performance: ## Run performance tests
	@echo "$(BLUE)Running performance tests...$(NC)"
	@./scripts/performance-test.sh
	@echo "$(GREEN)✓ Performance tests completed!$(NC)"

camera-test: ## Test camera connectivity
	@echo "$(BLUE)Testing camera connectivity...$(NC)"
	@./scripts/camera-test.sh
	@echo "$(GREEN)✓ Camera test completed!$(NC)"

deploy: ## Deploy to production
	@echo "$(BLUE)Deploying to production...$(NC)"
	@./scripts/deploy.sh production
	@echo "$(GREEN)✓ Production deployment completed!$(NC)"

update: ## Update system
	@echo "$(BLUE)Updating system...$(NC)"
	@./scripts/update.sh
	@echo "$(GREEN)✓ System update completed!$(NC)"

dev: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	@docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d
	@echo "$(GREEN)✓ Development environment started!$(NC)"

prod: ## Start production environment
	@echo "$(BLUE)Starting production environment...$(NC)"
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
	@echo "$(GREEN)✓ Production environment started!$(NC)"

shell-backend: ## Open shell in backend container
	@docker-compose exec backend /bin/bash

shell-frontend: ## Open shell in frontend container
	@docker-compose exec frontend /bin/bash

shell-ml: ## Open shell in ML service container
	@docker-compose exec ml-service /bin/bash

shell-db: ## Open shell in database container
	@docker-compose exec mariadb /bin/bash

db-migrate: ## Run database migrations
	@echo "$(BLUE)Running database migrations...$(NC)"
	@docker-compose exec backend npm run migrate
	@echo "$(GREEN)✓ Migrations completed!$(NC)"

db-seed: ## Run database seeders
	@echo "$(BLUE)Running database seeders...$(NC)"
	@docker-compose exec backend npm run seed
	@echo "$(GREEN)✓ Seeders completed!$(NC)"

db-reset: ## Reset database
	@echo "$(BLUE)Resetting database...$(NC)"
	@docker-compose exec backend npm run migrate:rollback
	@docker-compose exec backend npm run migrate
	@echo "$(GREEN)✓ Database reset completed!$(NC)"

install: ## Install dependencies
	@echo "$(BLUE)Installing dependencies...$(NC)"
	@cd backend && npm install
	@cd frontend && npm install
	@cd ml-service && pip install -r requirements.txt
	@echo "$(GREEN)✓ Dependencies installed!$(NC)"

lint: ## Run linting
	@echo "$(BLUE)Running linting...$(NC)"
	@cd backend && npm run lint
	@cd frontend && npm run lint
	@echo "$(GREEN)✓ Linting completed!$(NC)"

format: ## Format code
	@echo "$(BLUE)Formatting code...$(NC)"
	@cd backend && npm run format
	@cd frontend && npm run format
	@echo "$(GREEN)✓ Code formatting completed!$(NC)"

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@cd backend && npm run docs
	@cd frontend && npm run docs
	@echo "$(GREEN)✓ Documentation generated!$(NC)"

version: ## Show version information
	@echo "$(BLUE)LabFace Attendance System$(NC)"
	@echo "=============================="
	@echo "Version: 1.0.0"
	@echo "Docker: $(shell docker --version)"
	@echo "Docker Compose: $(shell docker-compose --version)"
	@echo "Node: $(shell node --version 2>/dev/null || echo 'Not installed')"
	@echo "Python: $(shell python --version 2>/dev/null || echo 'Not installed')"

info: ## Show system information
	@echo "$(BLUE)System Information$(NC)"
	@echo "==================="
	@echo "OS: $(shell uname -a)"
	@echo "CPU: $(shell nproc) cores"
	@echo "Memory: $(shell free -h | awk 'NR==2{print $$2}')"
	@echo "Disk: $(shell df -h . | awk 'NR==2{print $$2}')"
	@echo ""
	@echo "$(BLUE)Service Status:$(NC)"
	@docker-compose ps

# Development shortcuts
dev-backend: ## Start backend in development mode
	@cd backend && npm run dev

dev-frontend: ## Start frontend in development mode
	@cd frontend && npm run dev

dev-ml: ## Start ML service in development mode
	@cd ml-service && python main.py

# Production shortcuts
prod-build: ## Build for production
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

prod-start: ## Start production services
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

prod-stop: ## Stop production services
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml down

# Maintenance shortcuts
maintenance: ## Run maintenance tasks
	@echo "$(BLUE)Running maintenance tasks...$(NC)"
	@./scripts/cleanup.sh
	@./scripts/backup.sh
	@./scripts/security-audit.sh
	@echo "$(GREEN)✓ Maintenance completed!$(NC)"

# Emergency shortcuts
emergency-stop: ## Emergency stop all services
	@echo "$(RED)Emergency stopping all services...$(NC)"
	@docker-compose kill
	@docker-compose down --volumes --remove-orphans
	@echo "$(GREEN)✓ Emergency stop completed!$(NC)"

emergency-clean: ## Emergency clean all resources
	@echo "$(RED)Emergency cleaning all resources...$(NC)"
	@docker-compose down --volumes --remove-orphans
	@docker system prune -af
	@docker volume prune -f
	@echo "$(GREEN)✓ Emergency clean completed!$(NC)"

# Quick commands
quick-start: ## Quick start (no build)
	@docker-compose up -d

quick-stop: ## Quick stop
	@docker-compose down

quick-restart: ## Quick restart
	@docker-compose restart

# Help targets
help-setup: ## Show setup help
	@echo "$(BLUE)Setup Help$(NC)"
	@echo "==========="
	@echo "1. Run 'make setup' for initial setup"
	@echo "2. Edit .env file with your configuration"
	@echo "3. Run 'make start' to start services"
	@echo "4. Access http://localhost:3000"

help-deploy: ## Show deployment help
	@echo "$(BLUE)Deployment Help$(NC)"
	@echo "=================="
	@echo "1. Configure production environment"
	@echo "2. Run 'make deploy' for production deployment"
	@echo "3. Setup SSL with 'make ssl'"
	@echo "4. Configure monitoring with 'make monitor'"

help-troubleshoot: ## Show troubleshooting help
	@echo "$(BLUE)Troubleshooting Help$(NC)"
	@echo "======================="
	@echo "1. Check status: 'make status'"
	@echo "2. Check health: 'make health'"
	@echo "3. View logs: 'make logs'"
	@echo "4. Run security audit: 'make security'"
	@echo "5. Check performance: 'make performance'"
