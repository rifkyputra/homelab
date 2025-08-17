#!/bin/bash
# Docker health check script for PostgreSQL container
# Used by Docker to determine container health status

set -e

# Health check parameters
DB_USER="${POSTGRES_USER:-postgres_admin}"
DB_NAME="${POSTGRES_DB:-production_db}"
TIMEOUT=10

# Function to check database connectivity
check_database() {
    timeout "$TIMEOUT" pg_isready -h localhost -p 5432 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1
    return $?
}

# Function to check if database can execute queries
check_query_execution() {
    timeout "$TIMEOUT" psql -h localhost -p 5432 -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1
    return $?
}

# Function to check disk space
check_disk_space() {
    local usage=$(df /var/lib/postgresql/data | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -gt 90 ]; then
        echo "CRITICAL: Disk usage is ${usage}%"
        return 1
    fi
    return 0
}

# Function to check memory usage
check_memory() {
    local mem_usage=$(free | awk '/^Mem:/{printf "%.1f", $3/$2*100}')
    local mem_usage_int=${mem_usage%.*}
    
    if [ "$mem_usage_int" -gt 95 ]; then
        echo "WARNING: Memory usage is ${mem_usage}%"
        return 1
    fi
    return 0
}

# Main health check
main() {
    echo "Running PostgreSQL health check..."
    
    # Check 1: Database connectivity
    if ! check_database; then
        echo "FAILED: Database connectivity check failed"
        exit 1
    fi
    
    # Check 2: Query execution
    if ! check_query_execution; then
        echo "FAILED: Database query execution failed"
        exit 1
    fi
    
    # Check 3: Disk space
    if ! check_disk_space; then
        echo "FAILED: Disk space check failed"
        exit 1
    fi
    
    # Check 4: Memory usage
    if ! check_memory; then
        echo "WARNING: Memory usage is high but not critical"
        # Don't fail for memory warnings, just log them
    fi
    
    echo "SUCCESS: All health checks passed"
    exit 0
}

# Run health check
main "$@"
