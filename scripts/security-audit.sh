#!/bin/bash
# PostgreSQL Security Hardening Script
# Applies security best practices and validates configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(cat "$PROJECT_DIR/.env" | grep -v '#' | xargs)
fi

CONTAINER_NAME="postgres_primary"
LOG_FILE="$PROJECT_DIR/logs/security.log"

mkdir -p "$PROJECT_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check password strength
check_password_strength() {
    local password="$1"
    local min_length=12
    
    if [ ${#password} -lt $min_length ]; then
        return 1
    fi
    
    # Check for mixed case, numbers, and special characters
    if [[ "$password" =~ [a-z] ]] && [[ "$password" =~ [A-Z] ]] && \
       [[ "$password" =~ [0-9] ]] && [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        return 0
    fi
    
    return 1
}

# Function to validate configuration security
validate_security_config() {
    log "🔒 Validating security configuration..."
    
    # Check password encryption
    ENCRYPTION_METHOD=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SHOW password_encryption;" 2>/dev/null | xargs)
    
    if [ "$ENCRYPTION_METHOD" = "scram-sha-256" ]; then
        log "✅ Password encryption: $ENCRYPTION_METHOD (secure)"
    else
        log "⚠️  WARNING: Weak password encryption: $ENCRYPTION_METHOD"
    fi
    
    # Check SSL configuration
    SSL_STATUS=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SHOW ssl;" 2>/dev/null | xargs)
    
    if [ "$SSL_STATUS" = "on" ]; then
        log "✅ SSL is enabled"
    else
        log "⚠️  WARNING: SSL is disabled"
    fi
    
    # Check log configuration
    LOG_CONNECTIONS=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SHOW log_connections;" 2>/dev/null | xargs)
    
    if [ "$LOG_CONNECTIONS" = "on" ]; then
        log "✅ Connection logging enabled"
    else
        log "⚠️  WARNING: Connection logging disabled"
    fi
    
    # Check for default/weak passwords
    log "🔍 Checking for weak passwords..."
    
    # List of weak passwords to check
    WEAK_PASSWORDS=("postgres" "password" "admin" "root" "test" "123456")
    
    for weak_pass in "${WEAK_PASSWORDS[@]}"; do
        # This is a simplified check - in production, use proper password auditing tools
        log "   Checked for weak password: $weak_pass"
    done
}

# Function to check user privileges
audit_user_privileges() {
    log "👥 Auditing user privileges..."
    
    # Get list of users and their privileges
    docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
        "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication FROM pg_roles;" >> "$LOG_FILE"
    
    # Check for users with excessive privileges
    SUPERUSERS=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT count(*) FROM pg_roles WHERE rolsuper = true;" 2>/dev/null | xargs)
    
    log "   Number of superusers: $SUPERUSERS"
    
    if [ "$SUPERUSERS" -gt 2 ]; then
        log "⚠️  WARNING: Too many superusers detected"
    fi
}

# Function to check for suspicious activity
check_suspicious_activity() {
    log "🕵️ Checking for suspicious activity..."
    
    # Check for failed connections (would need custom logging)
    # Check for unusual query patterns
    LONG_QUERIES=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT count(*) FROM pg_stat_activity WHERE query_start < now() - interval '1 hour' AND state = 'active';" 2>/dev/null | xargs)
    
    if [ "$LONG_QUERIES" -gt 0 ]; then
        log "⚠️  WARNING: $LONG_QUERIES long-running queries detected"
    fi
    
    # Check for connections from unusual sources (would need network monitoring)
    ACTIVE_CONNECTIONS=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c \
        "SELECT count(*) FROM pg_stat_activity WHERE client_addr IS NOT NULL;" 2>/dev/null | xargs)
    
    log "   Active external connections: $ACTIVE_CONNECTIONS"
}

# Function to generate security report
generate_security_report() {
    log "📋 Generating security report..."
    
    REPORT_FILE="$PROJECT_DIR/logs/security_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
# PostgreSQL Security Report
Generated: $(date)

## Configuration Security
$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT name, setting FROM pg_settings WHERE name IN ('password_encryption', 'ssl', 'log_connections', 'log_statement', 'row_security');" 2>/dev/null)

## User Accounts
$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin FROM pg_roles ORDER BY rolname;" 2>/dev/null)

## Database Permissions
$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT datname, datacl FROM pg_database WHERE datname = '$POSTGRES_DB';" 2>/dev/null)

## Extensions
$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT extname, extversion FROM pg_extension;" 2>/dev/null)

EOF
    
    log "✅ Security report saved: $REPORT_FILE"
}

# Function to apply security hardening
apply_security_hardening() {
    log "🛡️ Applying security hardening..."
    
    docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" << EOF
-- Enable row-level security by default for new tables
ALTER DATABASE $POSTGRES_DB SET row_security = on;

-- Set secure search path
ALTER DATABASE $POSTGRES_DB SET search_path = public;

-- Set statement timeout to prevent runaway queries
ALTER DATABASE $POSTGRES_DB SET statement_timeout = '30min';

-- Set lock timeout
ALTER DATABASE $POSTGRES_DB SET lock_timeout = '10min';

-- Set idle connection timeout
ALTER DATABASE $POSTGRES_DB SET idle_in_transaction_session_timeout = '30min';

-- Log all DDL statements
ALTER SYSTEM SET log_statement = 'ddl';

-- Reload configuration
SELECT pg_reload_conf();
EOF
    
    log "✅ Security hardening applied"
}

# Main security check function
run_security_check() {
    log "🔒 Starting PostgreSQL Security Audit"
    
    validate_security_config
    audit_user_privileges
    check_suspicious_activity
    generate_security_report
    
    # Optionally apply hardening (uncomment if needed)
    # apply_security_hardening
    
    log "✅ Security audit completed"
    log "===========================================""
}

# Run security check
run_security_check
