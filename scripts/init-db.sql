-- Database initialization script for TestJava Price Service
-- This script runs when the PostgreSQL container starts for the first time

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create application user with limited privileges (if not exists)
DO
$do$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'priceservice_app') THEN
      CREATE ROLE priceservice_app LOGIN;
   END IF;
END
$do$;

-- Grant necessary permissions
GRANT CONNECT ON DATABASE priceservice TO priceservice_app;
GRANT USAGE ON SCHEMA public TO priceservice_app;
GRANT CREATE ON SCHEMA public TO priceservice_app;

-- Create audit table for tracking changes
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    user_id VARCHAR(100),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- Create index for audit log queries
CREATE INDEX IF NOT EXISTS idx_audit_log_table_timestamp ON audit_log(table_name, timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_timestamp ON audit_log(user_id, timestamp);

-- Create function for audit logging
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log(table_name, operation, old_data)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, operation, old_data, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(table_name, operation, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create configuration table for application settings
CREATE TABLE IF NOT EXISTS app_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    description TEXT,
    is_sensitive BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert default configuration values
INSERT INTO app_config (config_key, config_value, description, is_sensitive) VALUES 
    ('max_price_queries_per_minute', '1000', 'Maximum price queries allowed per minute per client', FALSE),
    ('cache_ttl_seconds', '3600', 'Cache time-to-live in seconds for price data', FALSE),
    ('api_rate_limit_enabled', 'true', 'Enable API rate limiting', FALSE),
    ('maintenance_mode', 'false', 'Enable maintenance mode', FALSE)
ON CONFLICT (config_key) DO NOTHING;

-- Create performance monitoring view
CREATE OR REPLACE VIEW performance_metrics AS
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    most_common_vals,
    most_common_freqs,
    histogram_bounds
FROM pg_stats 
WHERE schemaname = 'public';

-- Create database maintenance function
CREATE OR REPLACE FUNCTION perform_maintenance()
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
BEGIN
    -- Update table statistics
    ANALYZE;
    result := result || 'Statistics updated. ';
    
    -- Clean old audit logs (keep 90 days)
    DELETE FROM audit_log WHERE timestamp < NOW() - INTERVAL '90 days';
    result := result || 'Old audit logs cleaned. ';
    
    -- Vacuum and reindex critical tables
    VACUUM ANALYZE prices;
    result := result || 'Tables vacuumed. ';
    
    RETURN result || 'Maintenance completed successfully.';
END;
$$ LANGUAGE plpgsql;

-- Create monitoring function for database health
CREATE OR REPLACE FUNCTION database_health_check()
RETURNS JSON AS $$
DECLARE
    db_size BIGINT;
    active_connections INTEGER;
    result JSON;
BEGIN
    -- Get database size
    SELECT pg_database_size(current_database()) INTO db_size;
    
    -- Get active connections
    SELECT count(*) FROM pg_stat_activity WHERE state = 'active' INTO active_connections;
    
    result := json_build_object(
        'database_size_bytes', db_size,
        'database_size_mb', ROUND(db_size / 1024.0 / 1024.0, 2),
        'active_connections', active_connections,
        'max_connections', current_setting('max_connections')::INTEGER,
        'timestamp', CURRENT_TIMESTAMP
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions to application user
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO priceservice_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO priceservice_app;
GRANT EXECUTE ON FUNCTION perform_maintenance() TO priceservice_app;
GRANT EXECUTE ON FUNCTION database_health_check() TO priceservice_app;

-- Create scheduled maintenance job (requires pg_cron extension - optional)
-- SELECT cron.schedule('db-maintenance', '0 2 * * 0', 'SELECT perform_maintenance();');

COMMIT;