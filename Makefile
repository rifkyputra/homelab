# PostgreSQL Production Management Makefile
# Usage: make help

.PHONY: help start stop restart status backup monitor security health logs clean

# Default target
help: ## Show this help message
	@echo "PostgreSQL Production Management Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Environment setup
check-env: ## Check if environment is properly configured
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Copy .env.template to .env and configure it."; \
		exit 1; \
	fi
	@echo "✅ Environment configuration found"

# Production services
start: check-env ## Start production services
	@echo "🚀 Starting production PostgreSQL services..."
	docker compose -f docker-compose.prod.yml up -d
	@echo "✅ Services started successfully"
	@make status

stop: ## Stop all services
	@echo "🛑 Stopping services..."
	docker compose -f docker-compose.prod.yml down
	@echo "✅ Services stopped"

restart: ## Restart all services
	@echo "🔄 Restarting services..."
	docker compose -f docker-compose.prod.yml down
	docker compose -f docker-compose.prod.yml up -d
	@echo "✅ Services restarted"

status: ## Show service status
	@echo "📊 Service Status:"
	@docker compose -f docker-compose.prod.yml ps

# Development services (fallback to regular compose)
dev-start: check-env ## Start development services
	@echo "🔧 Starting development services..."
	docker compose up -d
	@echo "✅ Development services started"

dev-stop: ## Stop development services
	@echo "🛑 Stopping development services..."
	docker compose down

# Database operations
backup: ## Create database backup
	@echo "💾 Creating database backup..."
	./scripts/backup.sh
	@echo "✅ Backup completed"

restore: ## Restore database from backup (requires BACKUP_FILE variable)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "❌ Please specify BACKUP_FILE=path/to/backup.sql.gz"; \
		exit 1; \
	fi
	@echo "📥 Restoring database from $(BACKUP_FILE)..."
	@if [ -f "$(BACKUP_FILE)" ]; then \
		zcat "$(BACKUP_FILE)" | docker exec -i postgres_primary psql -U postgres_admin -d production_db; \
		echo "✅ Database restored successfully"; \
	else \
		echo "❌ Backup file not found: $(BACKUP_FILE)"; \
		exit 1; \
	fi

# Monitoring and maintenance
monitor: ## Run health monitoring
	@echo "🔍 Running health check..."
	./scripts/monitor.sh

security: ## Run security audit
	@echo "🔒 Running security audit..."
	./scripts/security-audit.sh

health: ## Quick health check
	@echo "❤️  Quick Health Check:"
	@docker exec postgres_primary pg_isready -U postgres_admin -d production_db && echo "✅ Database is healthy" || echo "❌ Database is not responding"
	@docker exec pgadmin_web wget --quiet --tries=1 --spider http://localhost/misc/ping && echo "✅ pgAdmin is healthy" || echo "❌ pgAdmin is not responding"

# Logs and debugging
logs: ## Show service logs
	@echo "📋 Service Logs:"
	docker compose -f docker-compose.prod.yml logs --tail=50

logs-follow: ## Follow service logs in real-time
	@echo "📋 Following logs (Ctrl+C to stop)..."
	docker compose -f docker-compose.prod.yml logs -f

logs-db: ## Show database logs only
	@echo "🗃️ Database Logs:"
	docker compose -f docker-compose.prod.yml logs database --tail=50

logs-pgadmin: ## Show pgAdmin logs only  
	@echo "🌐 pgAdmin Logs:"
	docker compose -f docker-compose.prod.yml logs pgladmin --tail=50

# Database connection
connect: ## Connect to database via psql
	@echo "🔗 Connecting to database..."
	docker exec -it postgres_primary psql -U postgres_admin -d production_db

connect-readonly: ## Connect as readonly user
	@echo "🔗 Connecting as readonly user..."
	docker exec -it postgres_primary psql -U readonly_user -d production_db

# Maintenance operations
vacuum: ## Run database vacuum (maintenance)
	@echo "🧹 Running database vacuum..."
	docker exec postgres_primary psql -U postgres_admin -d production_db -c "VACUUM ANALYZE;"
	@echo "✅ Vacuum completed"

reindex: ## Reindex database
	@echo "📊 Reindexing database..."
	docker exec postgres_primary psql -U postgres_admin -d production_db -c "REINDEX DATABASE production_db;"
	@echo "✅ Reindex completed"

stats: ## Show database statistics
	@echo "📈 Database Statistics:"
	@docker exec postgres_primary psql -U postgres_admin -d production_db -c "\
		SELECT schemaname, tablename, n_tup_ins as inserts, n_tup_upd as updates, n_tup_del as deletes \
		FROM pg_stat_user_tables ORDER BY n_tup_ins DESC LIMIT 10;"

# Cleanup operations
clean-logs: ## Clean old log files
	@echo "🧹 Cleaning old logs..."
	find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
	find logs/ -name "security_report_*.txt" -mtime +30 -delete 2>/dev/null || true
	@echo "✅ Logs cleaned"

clean-backups: ## Clean old backups (keeps last 30 days)
	@echo "🧹 Cleaning old backups..."
	find backups/ -name "full_backup_*.sql*" -mtime +30 -delete 2>/dev/null || true
	find backups/ -name "config_backup_*.tar.gz" -mtime +30 -delete 2>/dev/null || true
	@echo "✅ Old backups cleaned"

clean-all: clean-logs clean-backups ## Clean all temporary files

# Security operations
update-passwords: ## Update database passwords (interactive)
	@echo "🔒 Password Update Process:"
	@echo "This will guide you through updating database passwords..."
	@./scripts/update-passwords.sh

ssl-setup: ## Setup SSL certificates
	@echo "🔐 SSL Certificate Setup:"
	@echo "Place your SSL certificates in the ssl/ directory"
	@echo "Required files: server.crt, server.key, ca.crt"
	@mkdir -p ssl/
	@ls -la ssl/ 2>/dev/null || echo "SSL directory created. Add your certificates."

# Disaster recovery
emergency-stop: ## Emergency stop all services
	@echo "🚨 EMERGENCY STOP - Forcing container shutdown..."
	docker kill postgres_primary pgladmin_web 2>/dev/null || true
	docker compose -f docker-compose.prod.yml down --remove-orphans
	@echo "✅ Emergency stop completed"

reset-pgladmin: ## Reset pgAdmin (clears settings and passwords)
	@echo "🔄 Resetting pgAdmin..."
	docker compose -f docker-compose.prod.yml stop pgladmin
	docker compose -f docker-compose.prod.yml rm -f pgladmin  
	docker volume rm selfhostpg_pgladmin_data 2>/dev/null || true
	docker compose -f docker-compose.prod.yml up pgladmin -d
	@echo "✅ pgAdmin reset completed"

# Information
version: ## Show versions of all components
	@echo "📋 Component Versions:"
	@echo "PostgreSQL: $$(docker exec postgres_primary psql -U postgres_admin -d production_db -t -c 'SELECT version();' 2>/dev/null | head -1 || echo 'Not running')"
	@echo "Docker Compose: $$(docker compose --version)"
	@echo "Docker: $$(docker --version)"

info: ## Show system information  
	@echo "ℹ️  System Information:"
	@echo "Containers: $$(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E '(postgres|pgladmin)')"
	@echo "Volumes: $$(docker volume ls --format 'table {{.Name}}' | grep selfhostpg)"
	@echo "Networks: $$(docker network ls --format 'table {{.Name}}' | grep selfhostpg)"
	@echo "Disk Usage: $$(du -sh backups/ logs/ 2>/dev/null || echo 'No data directories')"
