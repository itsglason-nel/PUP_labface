#!/bin/bash

# LabFace System Cleanup Script
# This script cleans up the LabFace system and frees up resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLEANUP_LOG="logs/cleanup.log"
DAYS_TO_KEEP=${1:-30}

echo -e "${BLUE}LabFace System Cleanup${NC}"
echo "======================"
echo "Keeping logs and backups for $DAYS_TO_KEEP days"
echo ""

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$CLEANUP_LOG"
}

# Function to clean up Docker resources
cleanup_docker() {
    echo -e "${YELLOW}Cleaning up Docker resources...${NC}"
    
    # Remove unused containers
    local unused_containers=$(docker container ls -a --filter "status=exited" -q)
    if [ -n "$unused_containers" ]; then
        echo "Removing unused containers..."
        docker container rm $unused_containers
        echo -e "${GREEN}✓ Removed unused containers${NC}"
    else
        echo -e "${GREEN}✓ No unused containers found${NC}"
    fi
    
    # Remove unused images
    local unused_images=$(docker images --filter "dangling=true" -q)
    if [ -n "$unused_images" ]; then
        echo "Removing unused images..."
        docker rmi $unused_images
        echo -e "${GREEN}✓ Removed unused images${NC}"
    else
        echo -e "${GREEN}✓ No unused images found${NC}"
    fi
    
    # Remove unused volumes
    local unused_volumes=$(docker volume ls --filter "dangling=true" -q)
    if [ -n "$unused_volumes" ]; then
        echo "Removing unused volumes..."
        docker volume rm $unused_volumes
        echo -e "${GREEN}✓ Removed unused volumes${NC}"
    else
        echo -e "${GREEN}✓ No unused volumes found${NC}"
    fi
    
    # Remove unused networks
    local unused_networks=$(docker network ls --filter "type=custom" --format "{{.Name}}" | grep -v "labface-network" || true)
    if [ -n "$unused_networks" ]; then
        echo "Removing unused networks..."
        echo "$unused_networks" | xargs -r docker network rm
        echo -e "${GREEN}✓ Removed unused networks${NC}"
    else
        echo -e "${GREEN}✓ No unused networks found${NC}"
    fi
    
    log "DOCKER: Cleanup completed"
}

# Function to clean up logs
cleanup_logs() {
    echo -e "${YELLOW}Cleaning up log files...${NC}"
    
    # Create logs directory if it doesn't exist
    mkdir -p logs
    
    # Remove old log files
    local old_logs=$(find logs -name "*.log" -type f -mtime +$DAYS_TO_KEEP 2>/dev/null | wc -l)
    if [ "$old_logs" -gt 0 ]; then
        echo "Removing $old_logs old log files..."
        find logs -name "*.log" -type f -mtime +$DAYS_TO_KEEP -delete
        echo -e "${GREEN}✓ Removed $old_logs old log files${NC}"
    else
        echo -e "${GREEN}✓ No old log files found${NC}"
    fi
    
    # Compress large log files
    local large_logs=$(find logs -name "*.log" -type f -size +10M 2>/dev/null)
    if [ -n "$large_logs" ]; then
        echo "Compressing large log files..."
        echo "$large_logs" | xargs -I {} gzip {}
        echo -e "${GREEN}✓ Compressed large log files${NC}"
    fi
    
    log "LOGS: Cleanup completed"
}

# Function to clean up backups
cleanup_backups() {
    echo -e "${YELLOW}Cleaning up backup files...${NC}"
    
    if [ -d "backups" ]; then
        # Remove old backup files
        local old_backups=$(find backups -name "labface_backup_*.tar.gz" -type f -mtime +$DAYS_TO_KEEP 2>/dev/null | wc -l)
        if [ "$old_backups" -gt 0 ]; then
            echo "Removing $old_backups old backup files..."
            find backups -name "labface_backup_*.tar.gz" -type f -mtime +$DAYS_TO_KEEP -delete
            echo -e "${GREEN}✓ Removed $old_backups old backup files${NC}"
        else
            echo -e "${GREEN}✓ No old backup files found${NC}"
        fi
        
        # Keep only last 7 backups
        local total_backups=$(find backups -name "labface_backup_*.tar.gz" -type f 2>/dev/null | wc -l)
        if [ "$total_backups" -gt 7 ]; then
            local to_remove=$((total_backups - 7))
            echo "Keeping only last 7 backups, removing $to_remove oldest..."
            find backups -name "labface_backup_*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | head -n $to_remove | cut -d' ' -f2- | xargs rm
            echo -e "${GREEN}✓ Kept only last 7 backups${NC}"
        fi
    else
        echo -e "${GREEN}✓ No backup directory found${NC}"
    fi
    
    log "BACKUPS: Cleanup completed"
}

# Function to clean up temporary files
cleanup_temp() {
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    
    # Remove temporary files
    local temp_files=$(find . -name "*.tmp" -o -name "*.temp" -o -name "*~" -o -name ".DS_Store" 2>/dev/null | wc -l)
    if [ "$temp_files" -gt 0 ]; then
        echo "Removing $temp_files temporary files..."
        find . -name "*.tmp" -o -name "*.temp" -o -name "*~" -o -name ".DS_Store" -delete
        echo -e "${GREEN}✓ Removed temporary files${NC}"
    else
        echo -e "${GREEN}✓ No temporary files found${NC}"
    fi
    
    # Clean up node_modules if they exist
    if [ -d "node_modules" ]; then
        echo "Removing node_modules directory..."
        rm -rf node_modules
        echo -e "${GREEN}✓ Removed node_modules${NC}"
    fi
    
    # Clean up Python cache
    local pycache_dirs=$(find . -name "__pycache__" -type d 2>/dev/null | wc -l)
    if [ "$pycache_dirs" -gt 0 ]; then
        echo "Removing $pycache_dirs Python cache directories..."
        find . -name "__pycache__" -type d -exec rm -rf {} +
        echo -e "${GREEN}✓ Removed Python cache${NC}"
    fi
    
    log "TEMP: Cleanup completed"
}

# Function to clean up database
cleanup_database() {
    echo -e "${YELLOW}Cleaning up database...${NC}"
    
    # Check if database is accessible
    if docker-compose exec -T mariadb mysqladmin ping -h localhost --silent 2>/dev/null; then
        # Clean up old attendance records (older than 1 year)
        local old_attendance=$(docker-compose exec -T backend node -e "
            const knex = require('knex')({
                client: 'mysql2',
                connection: {
                    host: 'mariadb',
                    user: process.env.DB_USER || 'root',
                    password: process.env.DB_PASSWORD || '',
                    database: process.env.DB_NAME || 'labface'
                }
            });
            knex('attendance').where('checkin_ts', '<', new Date(Date.now() - 365*24*60*60*1000)).count('* as count')
                .then(result => {
                    console.log(result[0].count);
                    process.exit(0);
                })
                .catch(() => {
                    console.log('0');
                    process.exit(0);
                });
        " 2>/dev/null || echo "0")
        
        if [ "$old_attendance" -gt 0 ]; then
            echo "Found $old_attendance old attendance records..."
            echo "Archiving old attendance records..."
            # Archive old records instead of deleting
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
                knex('attendance').where('checkin_ts', '<', new Date(Date.now() - 365*24*60*60*1000))
                    .update({ archived: true })
                    .then(() => process.exit(0))
                    .catch(() => process.exit(0));
            " 2>/dev/null || true
            echo -e "${GREEN}✓ Archived old attendance records${NC}"
        else
            echo -e "${GREEN}✓ No old attendance records found${NC}"
        fi
        
        # Clean up old presence events (older than 6 months)
        local old_events=$(docker-compose exec -T backend node -e "
            const knex = require('knex')({
                client: 'mysql2',
                connection: {
                    host: 'mariadb',
                    user: process.env.DB_USER || 'root',
                    password: process.env.DB_PASSWORD || '',
                    database: process.env.DB_NAME || 'labface'
                }
            });
            knex('presence_events').where('event_ts', '<', new Date(Date.now() - 180*24*60*60*1000)).count('* as count')
                .then(result => {
                    console.log(result[0].count);
                    process.exit(0);
                })
                .catch(() => {
                    console.log('0');
                    process.exit(0);
                });
        " 2>/dev/null || echo "0")
        
        if [ "$old_events" -gt 0 ]; then
            echo "Found $old_events old presence events..."
            echo "Archiving old presence events..."
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
                knex('presence_events').where('event_ts', '<', new Date(Date.now() - 180*24*60*60*1000))
                    .del()
                    .then(() => process.exit(0))
                    .catch(() => process.exit(0));
            " 2>/dev/null || true
            echo -e "${GREEN}✓ Cleaned up old presence events${NC}"
        else
            echo -e "${GREEN}✓ No old presence events found${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Database not accessible, skipping database cleanup${NC}"
    fi
    
    log "DATABASE: Cleanup completed"
}

# Function to clean up MinIO
cleanup_minio() {
    echo -e "${YELLOW}Cleaning up MinIO storage...${NC}"
    
    # Check if MinIO is accessible
    if curl -f -s http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        # Clean up old images (older than 1 year)
        local old_images=$(docker-compose exec -T minio mc find minio/labface --older-than 365d 2>/dev/null | wc -l)
        if [ "$old_images" -gt 0 ]; then
            echo "Found $old_images old images..."
            echo "Removing old images..."
            docker-compose exec -T minio mc find minio/labface --older-than 365d --exec "mc rm {}" 2>/dev/null || true
            echo -e "${GREEN}✓ Cleaned up old images${NC}"
        else
            echo -e "${GREEN}✓ No old images found${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ MinIO not accessible, skipping storage cleanup${NC}"
    fi
    
    log "MINIO: Cleanup completed"
}

# Function to show cleanup summary
show_summary() {
    echo ""
    echo -e "${BLUE}Cleanup Summary:${NC}"
    echo "================"
    
    # Show disk usage before and after
    echo "Disk usage:"
    df -h . | tail -n 1
    
    # Show Docker resource usage
    echo ""
    echo "Docker resource usage:"
    docker system df
    
    # Show log file sizes
    if [ -d "logs" ]; then
        echo ""
        echo "Log files:"
        ls -lh logs/*.log 2>/dev/null || echo "No log files found"
    fi
    
    # Show backup files
    if [ -d "backups" ]; then
        echo ""
        echo "Backup files:"
        ls -lh backups/*.tar.gz 2>/dev/null || echo "No backup files found"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Cleanup completed successfully!${NC}"
    log "CLEANUP: Completed successfully"
}

# Function to perform full cleanup
full_cleanup() {
    echo "Starting comprehensive cleanup..."
    echo ""
    
    cleanup_docker
    cleanup_logs
    cleanup_backups
    cleanup_temp
    cleanup_database
    cleanup_minio
    show_summary
}

# Function to perform quick cleanup
quick_cleanup() {
    echo "Starting quick cleanup..."
    echo ""
    
    cleanup_docker
    cleanup_temp
    show_summary
}

# Main execution
main() {
    case "${2:-full}" in
        "full")
            full_cleanup
            ;;
        "quick")
            quick_cleanup
            ;;
        "docker")
            cleanup_docker
            ;;
        "logs")
            cleanup_logs
            ;;
        "backups")
            cleanup_backups
            ;;
        "temp")
            cleanup_temp
            ;;
        "database")
            cleanup_database
            ;;
        "minio")
            cleanup_minio
            ;;
        *)
            echo "Usage: $0 <days_to_keep> [full|quick|docker|logs|backups|temp|database|minio]"
            echo ""
            echo "Arguments:"
            echo "  days_to_keep  - Number of days to keep logs and backups (default: 30)"
            echo ""
            echo "Commands:"
            echo "  full     - Perform full cleanup (default)"
            echo "  quick    - Perform quick cleanup"
            echo "  docker   - Clean up Docker resources only"
            echo "  logs     - Clean up log files only"
            echo "  backups  - Clean up backup files only"
            echo "  temp     - Clean up temporary files only"
            echo "  database - Clean up database only"
            echo "  minio    - Clean up MinIO storage only"
            exit 1
            ;;
    esac
}

# Create logs directory if it doesn't exist
mkdir -p logs

# Run main function
main "$@"
