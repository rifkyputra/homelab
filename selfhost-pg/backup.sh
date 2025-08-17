#!/bin/bash

# PostgreSQL Backup Script
# Usage: ./backup.sh

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
fi

CONTAINER_NAME="selfhostpg-database-1"
DB_USER="$POSTGRES_USER"
DB_NAME="$POSTGRES_DB"
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.sql"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Create backup
echo "Creating backup: $BACKUP_FILE"
docker exec $CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "Backup completed successfully!"
    echo "File: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi
