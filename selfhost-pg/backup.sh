#!/bin/bash

# PostgreSQL Backup Script
# Usage: ./backup.sh

set -euo pipefail

# Error handling
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "[ERROR] Backup script failed with exit code $exit_code" >&2
    echo "[ERROR] Check the output above for details" >&2
  fi
  exit $exit_code
}
trap cleanup EXIT

# Load environment variables from .env file
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
else
    echo "[ERROR] .env file not found" >&2
    exit 1
fi

# Validate required environment variables
REQUIRED_VARS=("POSTGRES_USER" "POSTGRES_DB")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "[ERROR] Required environment variable $var is not set" >&2
        exit 1
    fi
done

CONTAINER_NAME="selfhostpg-database-1"
DB_USER="$POSTGRES_USER"
DB_NAME="$POSTGRES_DB"
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.sql"

# Check if container exists and is running
if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "[ERROR] Container $CONTAINER_NAME is not running" >&2
    echo "Available containers:" >&2
    docker ps --format "table {{.Names}}\t{{.Status}}" >&2
    exit 1
fi

# Create backup directory if it doesn't exist
if ! mkdir -p "$BACKUP_DIR"; then
    echo "[ERROR] Failed to create backup directory: $BACKUP_DIR" >&2
    exit 1
fi

# Create backup
echo "[INFO] Creating backup: $BACKUP_FILE"
if docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"; then
    # Verify backup file was created and has content
    if [[ -f "$BACKUP_FILE" && -s "$BACKUP_FILE" ]]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        echo "[SUCCESS] Backup completed successfully!"
        echo "[INFO] File: $BACKUP_FILE"
        echo "[INFO] Size: $BACKUP_SIZE"
        
        # Simple validation - check if file contains SQL
        if head -5 "$BACKUP_FILE" | grep -q "PostgreSQL database dump"; then
            echo "[INFO] Backup file validation passed"
        else
            echo "[WARNING] Backup file may be corrupted - missing PostgreSQL header"
        fi
    else
        echo "[ERROR] Backup file is empty or was not created" >&2
        exit 1
    fi
else
    echo "[ERROR] Backup command failed!" >&2
    exit 1
fi
