#!/bin/bash
# PostgreSQL Health Monitoring Script
# Monitors database performance, connections, and system health

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(cat "$PROJECT_DIR/.env" | grep -v '#' | xargs)
fi

CONTAINER_NAME="postgres_primary"
LOG_FILE="$PROJECT_DIR/logs/monitoring.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_CONNECTIONS=80
ALERT_THRESHOLD_DISK=85

# Create logs directory
mkdir -p "$PROJECT_DIR/logs"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check if container is running
check_container() {
    if docker ps | grep -q "$CONTAINER_NAME"; then
        log "✅ Container is running"
        return 0
    else
        log "❌ Container is not running"
        return 1
    fi
}

# Function to check database connectivity
check_connectivity() {
    if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
        log "✅ Database is accepting connections"
        return 0
    else
        log "❌ Database is not accepting connections"
        return 1
    fi
}

# Function to get database metrics
get_db_metrics() {
    log "📊 Database Metrics:"
    
    # Connection count
    CONNECTIONS=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | xargs)
    
    MAX_CONNECTIONS=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SHOW max_connections;" 2>/dev/null | xargs)
    
    CONNECTION_PCT=$((CONNECTIONS * 100 / MAX_CONNECTIONS))
    log "   Active Connections: $CONNECTIONS/$MAX_CONNECTIONS ($CONNECTION_PCT%)"
    
    if [ $CONNECTION_PCT -gt $ALERT_THRESHOLD_CONNECTIONS ]; then
        log "⚠️  WARNING: High connection usage: $CONNECTION_PCT%"
    fi
    
    # Database size
    DB_SIZE=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT pg_size_pretty(pg_database_size('$POSTGRES_DB'));" 2>/dev/null | xargs)
    log "   Database Size: $DB_SIZE"
    
    # Transaction rate
    TPS=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT sum(xact_commit + xact_rollback) FROM pg_stat_database WHERE datname = '$POSTGRES_DB';" 2>/dev/null | xargs)
    log "   Total Transactions: $TPS"
    
    # Cache hit ratio
    CACHE_HIT=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT round(sum(blks_hit)*100/sum(blks_hit+blks_read),2) FROM pg_stat_database;" 2>/dev/null | xargs)
    log "   Cache Hit Ratio: $CACHE_HIT%"
    
    if (( $(echo "$CACHE_HIT < 95" | bc -l) )); then
        log "⚠️  WARNING: Low cache hit ratio: $CACHE_HIT%"
    fi
    
    # Longest running query
    LONGEST_QUERY=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT COALESCE(max(extract(epoch from (now() - query_start))), 0) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | xargs)
    log "   Longest Query Runtime: ${LONGEST_QUERY}s"
    
    if (( $(echo "$LONGEST_QUERY > 300" | bc -l) )); then
        log "⚠️  WARNING: Long-running query detected: ${LONGEST_QUERY}s"
    fi
}

# Function to get system metrics
get_system_metrics() {
    log "💻 System Metrics:"
    
    # Container CPU usage
    CPU_USAGE=$(docker stats "$CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}}" | tail -n 1 | sed 's/%//')
    log "   CPU Usage: $CPU_USAGE%"
    
    if (( $(echo "$CPU_USAGE > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        log "⚠️  WARNING: High CPU usage: $CPU_USAGE%"
    fi
    
    # Container memory usage
    MEM_USAGE=$(docker stats "$CONTAINER_NAME" --no-stream --format "table {{.MemPerc}}" | tail -n 1 | sed 's/%//')
    log "   Memory Usage: $MEM_USAGE%"
    
    if (( $(echo "$MEM_USAGE > $ALERT_THRESHOLD_MEMORY" | bc -l) )); then
        log "⚠️  WARNING: High memory usage: $MEM_USAGE%"
    fi
    
    # Disk usage
    DISK_USAGE=$(df -h "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    log "   Disk Usage: $DISK_USAGE%"
    
    if [ $DISK_USAGE -gt $ALERT_THRESHOLD_DISK ]; then
        log "⚠️  WARNING: High disk usage: $DISK_USAGE%"
    fi
}

# Function to check for blocked queries
check_blocked_queries() {
    BLOCKED_QUERIES=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock';" 2>/dev/null | xargs)
    
    if [ "$BLOCKED_QUERIES" -gt 0 ]; then
        log "⚠️  WARNING: $BLOCKED_QUERIES blocked queries detected"
        
        # Get details of blocked queries
        docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
            "SELECT pid, wait_event_type, wait_event, state, query FROM pg_stat_activity WHERE wait_event_type = 'Lock';" 2>/dev/null | head -20 >> "$LOG_FILE"
    fi
}

# Function to check WAL files
check_wal_files() {
    WAL_COUNT=$(docker exec "$CONTAINER_NAME" sh -c "ls -1 /var/lib/postgresql/data/pg_wal/ | wc -l" 2>/dev/null || echo "0")
    log "   WAL Files Count: $WAL_COUNT"
    
    if [ "$WAL_COUNT" -gt 100 ]; then
        log "⚠️  WARNING: High number of WAL files: $WAL_COUNT"
    fi
}

# Main monitoring function
run_monitoring() {
    log "🔍 Starting PostgreSQL Health Check"
    
    if check_container && check_connectivity; then
        get_db_metrics
        get_system_metrics
        check_blocked_queries
        check_wal_files
        log "✅ Health check completed successfully"
    else
        log "❌ Health check failed - service issues detected"
        exit 1
    fi
    
    log "==========================================="
}

# Run monitoring
run_monitoring
