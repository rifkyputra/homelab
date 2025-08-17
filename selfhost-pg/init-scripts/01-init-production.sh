#!/bin/bash
# Database initialization script for production
# Creates necessary extensions, users, and security configurations

set -e

echo "🔧 Initializing production database..."

# Create extensions
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Enable important extensions
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Create read-only user for monitoring/reporting
    CREATE USER readonly_user WITH ENCRYPTED PASSWORD '${POSTGRES_READONLY_PASSWORD}';
    GRANT CONNECT ON DATABASE $POSTGRES_DB TO readonly_user;
    GRANT USAGE ON SCHEMA public TO readonly_user;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;
    
    -- Create application user with limited privileges
    CREATE USER app_user WITH ENCRYPTED PASSWORD '${POSTGRES_APP_USER_PASSWORD}';
    GRANT CONNECT ON DATABASE $POSTGRES_DB TO app_user;
    GRANT USAGE, CREATE ON SCHEMA public TO app_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
    
    -- Create backup user
    CREATE USER backup_user WITH ENCRYPTED PASSWORD '${POSTGRES_BACKUP_USER_PASSWORD}';
    GRANT CONNECT ON DATABASE $POSTGRES_DB TO backup_user;
    ALTER USER backup_user WITH REPLICATION;
    
    -- Security: Revoke public schema privileges from public role
    REVOKE CREATE ON SCHEMA public FROM PUBLIC;
    REVOKE ALL ON DATABASE $POSTGRES_DB FROM PUBLIC;
    
    -- Create audit table for security monitoring
    CREATE TABLE IF NOT EXISTS security_audit (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        user_name TEXT,
        database_name TEXT,
        command_tag TEXT,
        object_type TEXT,
        object_name TEXT,
        client_addr INET
    );
    
    -- Grant permissions on audit table
    GRANT SELECT, INSERT ON security_audit TO app_user;
    GRANT SELECT ON security_audit TO readonly_user;
    
    -- Create performance monitoring view
    CREATE OR REPLACE VIEW performance_stats AS
    SELECT 
        query,
        calls,
        total_time,
        mean_time,
        rows,
        100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
    FROM pg_stat_statements 
    ORDER BY total_time DESC 
    LIMIT 20;
    
    GRANT SELECT ON performance_stats TO readonly_user;
    
    -- Set up row-level security example
    -- ALTER TABLE your_sensitive_table ENABLE ROW LEVEL SECURITY;
    -- CREATE POLICY user_data_policy ON your_sensitive_table FOR ALL TO app_user USING (user_id = current_setting('app.current_user_id')::int);
    
EOSQL

echo "✅ Database initialization completed successfully!"
echo "📊 Available users:"
echo "   - $POSTGRES_USER (superuser)"
echo "   - app_user (application access)"
echo "   - readonly_user (monitoring/reporting)"
echo "   - backup_user (backup operations)"
