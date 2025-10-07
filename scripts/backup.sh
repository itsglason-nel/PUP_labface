#!/bin/bash

# LabFace Backup Script
# This script creates backups of the LabFace system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="labface_backup_$DATE"
RETENTION_DAYS=${1:-30}

echo -e "${BLUE}LabFace Backup Script${NC}"
echo "======================"
echo "Backup Name: $BACKUP_NAME"
echo "Retention: $RETENTION_DAYS days"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/backup.log"
}

# Function to create backup directory
create_backup_dir() {
    echo -e "${YELLOW}Creating backup directory...${NC}"
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
    echo -e "${GREEN}✓ Backup directory created: $BACKUP_DIR/$BACKUP_NAME${NC}"
    log "BACKUP_DIR: Created $BACKUP_DIR/$BACKUP_NAME"
}

# Function to backup database
backup_database() {
    echo -e "${YELLOW}Backing up database...${NC}"
    
    # Check if database is accessible
    if docker-compose exec -T mariadb mysqladmin ping -h localhost --silent 2>/dev/null; then
        # Create database dump
        docker-compose exec -T mariadb mysqldump -u root -p"$DB_PASSWORD" labface > "$BACKUP_DIR/$BACKUP_NAME/database.sql" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Database backup completed${NC}"
            log "DATABASE: Backup completed successfully"
        else
            echo -e "${RED}✗ Database backup failed${NC}"
            log "DATABASE: Backup failed"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Database not accessible, skipping database backup${NC}"
        log "DATABASE: Not accessible, skipped"
    fi
}

# Function to backup MinIO data
backup_minio() {
    echo -e "${YELLOW}Backing up MinIO data...${NC}"
    
    # Check if MinIO is accessible
    if curl -f -s http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        # Create MinIO data backup
        docker-compose exec -T minio mc mirror /data "$BACKUP_DIR/$BACKUP_NAME/minio_data" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ MinIO data backup completed${NC}"
            log "MINIO: Data backup completed successfully"
        else
            echo -e "${RED}✗ MinIO data backup failed${NC}"
            log "MINIO: Data backup failed"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ MinIO not accessible, skipping MinIO backup${NC}"
        log "MINIO: Not accessible, skipped"
    fi
}

# Function to backup configuration
backup_config() {
    echo -e "${YELLOW}Backing up configuration...${NC}"
    
    # Copy configuration files
    cp .env "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || echo "No .env file found"
    cp docker-compose.yml "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || echo "No docker-compose.yml found"
    cp docker-compose.prod.yml "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || echo "No docker-compose.prod.yml found"
    cp nginx.conf "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || echo "No nginx.conf found"
    
    # Copy migration files
    cp -r backend/migrations "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || echo "No migrations found"
    
    # Copy SSL certificates if they exist
    if [ -d "ssl" ]; then
        cp -r ssl "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || echo "No SSL certificates found"
    fi
    
    echo -e "${GREEN}✓ Configuration backup completed${NC}"
    log "CONFIG: Backup completed successfully"
}

# Function to backup logs
backup_logs() {
    echo -e "${YELLOW}Backing up logs...${NC}"
    
    # Create logs directory
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME/logs"
    
    # Copy application logs
    if [ -d "logs" ]; then
        cp -r logs/* "$BACKUP_DIR/$BACKUP_NAME/logs/" 2>/dev/null || echo "No logs found"
    fi
    
    # Copy Docker logs
    docker-compose logs > "$BACKUP_DIR/$BACKUP_NAME/logs/docker_compose.log" 2>/dev/null || echo "No Docker logs found"
    
    # Copy individual service logs
    docker-compose logs backend > "$BACKUP_DIR/$BACKUP_NAME/logs/backend.log" 2>/dev/null || echo "No backend logs found"
    docker-compose logs frontend > "$BACKUP_DIR/$BACKUP_NAME/logs/frontend.log" 2>/dev/null || echo "No frontend logs found"
    docker-compose logs ml-service > "$BACKUP_DIR/$BACKUP_NAME/logs/ml-service.log" 2>/dev/null || echo "No ML service logs found"
    docker-compose logs mariadb > "$BACKUP_DIR/$BACKUP_NAME/logs/mariadb.log" 2>/dev/null || echo "No MariaDB logs found"
    docker-compose logs minio > "$BACKUP_DIR/$BACKUP_NAME/logs/minio.log" 2>/dev/null || echo "No MinIO logs found"
    
    echo -e "${GREEN}✓ Logs backup completed${NC}"
    log "LOGS: Backup completed successfully"
}

# Function to backup source code
backup_source() {
    echo -e "${YELLOW}Backing up source code...${NC}"
    
    # Create source directory
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME/source"
    
    # Copy source code (excluding node_modules, .git, etc.)
    rsync -av --exclude 'node_modules' --exclude '.git' --exclude 'logs' --exclude 'backups' --exclude 'data' --exclude '.next' --exclude 'dist' --exclude 'build' . "$BACKUP_DIR/$BACKUP_NAME/source/" 2>/dev/null || echo "Source backup failed"
    
    echo -e "${GREEN}✓ Source code backup completed${NC}"
    log "SOURCE: Backup completed successfully"
}

# Function to create backup archive
create_archive() {
    echo -e "${YELLOW}Creating backup archive...${NC}"
    
    cd "$BACKUP_DIR"
    tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
    rm -rf "$BACKUP_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup archive created: $BACKUP_DIR/$BACKUP_NAME.tar.gz${NC}"
        log "ARCHIVE: Created $BACKUP_NAME.tar.gz"
    else
        echo -e "${RED}✗ Failed to create backup archive${NC}"
        log "ARCHIVE: Failed to create archive"
        return 1
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    echo -e "${YELLOW}Cleaning up old backups...${NC}"
    
    # Remove old backup files
    local old_backups=$(find "$BACKUP_DIR" -name "labface_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
    if [ "$old_backups" -gt 0 ]; then
        echo "Removing $old_backups old backup files..."
        find "$BACKUP_DIR" -name "labface_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
        echo -e "${GREEN}✓ Removed $old_backups old backup files${NC}"
    else
        echo -e "${GREEN}✓ No old backup files found${NC}"
    fi
    
    # Keep only last 7 backups
    local total_backups=$(find "$BACKUP_DIR" -name "labface_backup_*.tar.gz" -type f 2>/dev/null | wc -l)
    if [ "$total_backups" -gt 7 ]; then
        local to_remove=$((total_backups - 7))
        echo "Keeping only last 7 backups, removing $to_remove oldest..."
        find "$BACKUP_DIR" -name "labface_backup_*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | head -n $to_remove | cut -d' ' -f2- | xargs rm
        echo -e "${GREEN}✓ Kept only last 7 backups${NC}"
    fi
    
    log "CLEANUP: Removed old backups (retention: $RETENTION_DAYS days)"
}

# Function to verify backup
verify_backup() {
    echo -e "${YELLOW}Verifying backup...${NC}"
    
    local backup_file="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
    
    if [ -f "$backup_file" ]; then
        # Check archive integrity
        if tar -tzf "$backup_file" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Backup archive is valid${NC}"
            log "VERIFY: Backup archive is valid"
        else
            echo -e "${RED}✗ Backup archive is corrupted${NC}"
            log "VERIFY: Backup archive is corrupted"
            return 1
        fi
        
        # Check archive size
        local backup_size=$(du -h "$backup_file" | cut -f1)
        echo "Backup size: $backup_size"
        log "VERIFY: Backup size is $backup_size"
    else
        echo -e "${RED}✗ Backup file not found${NC}"
        log "VERIFY: Backup file not found"
        return 1
    fi
}

# Function to show backup info
show_backup_info() {
    echo ""
    echo -e "${BLUE}Backup Information:${NC}"
    echo "==================="
    echo "Backup Name: $BACKUP_NAME"
    echo "Backup Size: $(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)"
    echo "Backup Location: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
    echo ""
    
    echo -e "${BLUE}Backup Contents:${NC}"
    echo "================="
    echo "• Database dump (database.sql)"
    echo "• MinIO data (minio_data/)"
    echo "• Configuration files (.env, docker-compose.yml, nginx.conf)"
    echo "• Migration files (migrations/)"
    echo "• Application logs (logs/)"
    echo "• Source code (source/)"
    echo "• SSL certificates (ssl/)"
    echo ""
    
    echo -e "${BLUE}Backup History:${NC}"
    echo "==============="
    ls -lh "$BACKUP_DIR"/labface_backup_*.tar.gz 2>/dev/null || echo "No previous backups found"
    echo ""
}

# Function to restore backup
restore_backup() {
    local backup_file="$2"
    
    if [ -z "$backup_file" ]; then
        echo -e "${RED}Please specify backup file to restore${NC}"
        echo "Usage: $0 restore <backup_file.tar.gz>"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Backup file not found: $backup_file${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring backup: $backup_file${NC}"
    
    # Stop services
    docker-compose down
    
    # Extract backup
    tar -xzf "$backup_file"
    
    # Restore database
    if [ -f "database.sql" ]; then
        echo "Restoring database..."
        docker-compose up -d mariadb
        sleep 10
        docker-compose exec -T mariadb mysql -u root -p"$DB_PASSWORD" labface < database.sql
        echo -e "${GREEN}✓ Database restored${NC}"
    fi
    
    # Restore MinIO data
    if [ -d "minio_data" ]; then
        echo "Restoring MinIO data..."
        docker-compose up -d minio
        sleep 10
        docker-compose exec -T minio mc mirror minio_data /data
        echo -e "${GREEN}✓ MinIO data restored${NC}"
    fi
    
    # Restore configuration
    if [ -f ".env" ]; then
        cp .env .env.restored
        echo -e "${GREEN}✓ Configuration restored${NC}"
    fi
    
    # Start services
    docker-compose up -d
    
    echo -e "${GREEN}✓ Backup restored successfully${NC}"
    log "RESTORE: Backup restored from $backup_file"
}

# Function to perform full backup
full_backup() {
    echo "Starting full backup process..."
    echo ""
    
    create_backup_dir
    backup_database
    backup_minio
    backup_config
    backup_logs
    backup_source
    create_archive
    cleanup_old_backups
    verify_backup
    show_backup_info
    
    echo -e "${GREEN}✓ Full backup completed successfully!${NC}"
    log "BACKUP: Full backup completed successfully"
}

# Function to perform quick backup
quick_backup() {
    echo "Starting quick backup process..."
    echo ""
    
    create_backup_dir
    backup_database
    backup_config
    create_archive
    cleanup_old_backups
    verify_backup
    show_backup_info
    
    echo -e "${GREEN}✓ Quick backup completed successfully!${NC}"
    log "BACKUP: Quick backup completed successfully"
}

# Main execution
main() {
    case "${2:-full}" in
        "full")
            full_backup
            ;;
        "quick")
            quick_backup
            ;;
        "restore")
            restore_backup "$@"
            ;;
        "verify")
            verify_backup
            ;;
        "cleanup")
            cleanup_old_backups
            ;;
        "info")
            show_backup_info
            ;;
        *)
            echo "Usage: $0 <retention_days> [full|quick|restore <backup_file>|verify|cleanup|info]"
            echo ""
            echo "Arguments:"
            echo "  retention_days  - Number of days to keep backups (default: 30)"
            echo ""
            echo "Commands:"
            echo "  full     - Perform full backup (default)"
            echo "  quick    - Perform quick backup"
            echo "  restore  - Restore from backup"
            echo "  verify   - Verify backup integrity"
            echo "  cleanup  - Clean up old backups"
            echo "  info     - Show backup information"
            exit 1
            ;;
    esac
}

# Create backup directory if it doesn't exist
mkdir -p backups

# Run main function
main "$@"