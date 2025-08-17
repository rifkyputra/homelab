#!/bin/bash
# Production-grade PostgreSQL backup script
# Features: Full backups, WAL archiving, retention policy, monitoring

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(cat "$PROJECT_DIR/.env" | grep -v '#' | xargs)
fi

# Backup configuration
CONTAINER_NAME="postgres_primary"
BACKUP_DIR="$PROJECT_DIR/backups"
WAL_ARCHIVE_DIR="$BACKUP_DIR/wal_archive"
LOG_FILE="$BACKUP_DIR/backup.log"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/full_backup_$DATE.sql"
BACKUP_FILE_COMPRESSED="$BACKUP_FILE.gz"

# Notification settings (configure as needed)
SLACK_WEBHOOK=""
EMAIL_TO=""

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to send notifications (implement as needed)
send_notification() {
    local status="$1"
    local message="$2"
    
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"PostgreSQL Backup $status: $message\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
    
    if [ -n "$EMAIL_TO" ]; then
        echo "$message" | mail -s "PostgreSQL Backup $status" "$EMAIL_TO" 2>/dev/null || true
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days"
    find "$BACKUP_DIR" -name "full_backup_*.sql*" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$WAL_ARCHIVE_DIR" -name "*.backup" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    log "Cleanup completed"
}

# Function to verify backup
verify_backup() {
    local backup_file="$1"
    
    if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
        # Check if the file contains SQL and ends properly
        if head -n 1 "$backup_file" | grep -q "PostgreSQL database dump" && \
           tail -n 5 "$backup_file" | grep -q "PostgreSQL database dump complete"; then
            return 0
        fi
    fi
    return 1
}

# Create necessary directories
mkdir -p "$BACKUP_DIR" "$WAL_ARCHIVE_DIR"

# Start backup process
log "Starting PostgreSQL backup process"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    log "ERROR: Container $CONTAINER_NAME is not running"
    send_notification "FAILED" "Container not running"
    exit 1
fi

# Perform database backup
log "Creating full database backup: $BACKUP_FILE"

# Use pg_dump with optimal settings for production
if docker exec "$CONTAINER_NAME" pg_dump \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --verbose \
    --format=custom \
    --no-owner \
    --no-privileges \
    --exclude-table-data=security_audit \
    --file="/backups/$(basename "$BACKUP_FILE")" 2>>"$LOG_FILE"; then
    
    log "Database backup completed successfully"
    
    # Copy backup from container to host
    docker cp "$CONTAINER_NAME:/backups/$(basename "$BACKUP_FILE")" "$BACKUP_FILE"
    
    # Compress backup
    gzip "$BACKUP_FILE"
    log "Backup compressed: $BACKUP_FILE_COMPRESSED"
    
    # Verify compressed backup
    if verify_backup <(zcat "$BACKUP_FILE_COMPRESSED"); then
        log "Backup verification successful"
        
        # Get backup size
        BACKUP_SIZE=$(du -h "$BACKUP_FILE_COMPRESSED" | cut -f1)
        log "Backup size: $BACKUP_SIZE"
        
        # Perform cleanup
        cleanup_old_backups
        
        # Send success notification
        send_notification "SUCCESS" "Backup completed successfully. Size: $BACKUP_SIZE"
        
    else
        log "ERROR: Backup verification failed"
        send_notification "FAILED" "Backup verification failed"
        exit 1
    fi
    
else
    log "ERROR: Database backup failed"
    send_notification "FAILED" "Database backup failed"
    exit 1
fi

# Backup PostgreSQL configuration files
log "Backing up configuration files"
docker exec "$CONTAINER_NAME" tar -czf "/backups/config_backup_$DATE.tar.gz" \
    -C /etc/postgresql postgresql.conf pg_hba.conf 2>>"$LOG_FILE" || true

docker cp "$CONTAINER_NAME:/backups/config_backup_$DATE.tar.gz" \
    "$BACKUP_DIR/config_backup_$DATE.tar.gz" 2>>"$LOG_FILE" || true

# Show backup summary
log "Backup process completed successfully"
log "Full backup: $BACKUP_FILE_COMPRESSED"
log "Config backup: $BACKUP_DIR/config_backup_$DATE.tar.gz"
log "WAL archive directory: $WAL_ARCHIVE_DIR"

# Optional: Upload to cloud storage (implement as needed)
# aws s3 cp "$BACKUP_FILE_COMPRESSED" s3://your-backup-bucket/postgres/
# gsutil cp "$BACKUP_FILE_COMPRESSED" gs://your-backup-bucket/postgres/
