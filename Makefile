# Root Makefile for Homelab + selfhost-pg
# Provides unified shortcuts for server setup, utilities, and PostgreSQL stack
# Usage: make help

SHELL := /bin/bash
SETUP_DIR := setup-ubuntu-server
UTIL_DIR := $(SETUP_DIR)/utils
PG_DIR := selfhost-pg

# Detect if running inside a POSIX shell without sudo (mac vs linux usage)
UNAME_S := $(shell uname -s)
SUDO := sudo
ifeq ($(UNAME_S),Darwin)
	# Allow overriding sudo on mac if not needed
	SUDO := sudo
endif

.PHONY: help setup-all firewall-fix permissions install-code-server install-vnc troubleshoot-vnc services postgres-start postgres-stop postgres-restart postgres-status backup-pg logs-pg monitor-pg security-pg compose-restart netdata-restart pg-shell vnc-password code-password clean root-info

help: ## Show this help message
	@echo "Homelab Unified Commands:"; echo;
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' | sort
	@echo; echo "PostgreSQL specific commands also live in $(PG_DIR)/Makefile (invoke with: make -C $(PG_DIR) help)"

root-info: ## Show key directories and scripts
	@echo "Setup dir:        $(SETUP_DIR)"; \
	echo "Utilities dir:    $(UTIL_DIR)"; \
	echo "Postgres dir:     $(PG_DIR)"; \
	echo "Config file:      $(SETUP_DIR)/config.env"; \
	echo "Permissions fixer: $(UTIL_DIR)/fix-permissions.sh";

# ---------------------------------------------------------------------------
# Setup & Utilities
# ---------------------------------------------------------------------------
setup-all: ## Run full homelab setup (on target Ubuntu server)
	@echo "🚀 Running full setup sequence"; \
	chmod +x $(SETUP_DIR)/*.sh $(SETUP_DIR)/lib/common.sh || true; \
	$(SUDO) $(SETUP_DIR)/00-run-all.sh

firewall-fix: ## Diagnose & fix service accessibility / firewall
	@echo "🛡  Running firewall & service diagnostics"; \
	chmod +x $(UTIL_DIR)/fix-firewall.sh; \
	$(SUDO) $(UTIL_DIR)/fix-firewall.sh || true

permissions: ## Fix permissions for all project scripts
	@echo "🔧 Fixing script & config permissions"; \
	chmod +x $(UTIL_DIR)/fix-permissions.sh; \
	$(UTIL_DIR)/fix-permissions.sh

install-code-server: ## Install & configure code-server service
	@echo "🧩 Installing code-server"; \
	chmod +x $(UTIL_DIR)/install-code-server.sh; \
	$(UTIL_DIR)/install-code-server.sh

install-vnc: ## Install & configure VNC (TigerVNC)
	@echo "🖥  Installing VNC server"; \
	chmod +x $(UTIL_DIR)/install-vnc.sh; \
	$(UTIL_DIR)/install-vnc.sh

troubleshoot-vnc: ## Run VNC troubleshooting diagnostics
	@chmod +x $(UTIL_DIR)/troubleshoot-vnc.sh; \
	$(UTIL_DIR)/troubleshoot-vnc.sh

services: ## Quick check of core listening services & ports
	@echo "🔍 Checking core service ports"; \
	netstat -tlnp 2>/dev/null | grep -E ':(443|8080|5901|19999) ' || echo "(netstat output unavailable)"; \
	$(SUDO) ufw status | grep -E '(443|8080|5901|19999)' || true

netdata-restart: ## Restart Netdata after config edits
	$(SUDO) systemctl restart netdata && $(SUDO) systemctl status netdata --no-pager -l | head -20

compose-restart: ## Restart homelab Docker compose stack (Portainer/code/Grafana)
	$(SUDO) systemctl restart homelab-compose && $(SUDO) systemctl status homelab-compose --no-pager -l | head -20

vnc-password: ## Set / change VNC password (run as your user)
	vncpasswd

code-password: ## Show code-server password (compose env or user config)
	@if [ -f /opt/homelab/.env ]; then \
		grep CODE_SERVER_PASSWORD /opt/homelab/.env || echo "Password not found in /opt/homelab/.env"; \
	elif [ -f $$HOME/.config/code-server/config.yaml ]; then \
		grep '^password:' $$HOME/.config/code-server/config.yaml; \
	else \
		echo "code-server config not found"; \
	fi

# ---------------------------------------------------------------------------
# PostgreSQL Delegated Commands (pass-through to sub Makefile)
# ---------------------------------------------------------------------------
postgres-start: ## Start PostgreSQL production stack
	$(MAKE) -C $(PG_DIR) start

postgres-stop: ## Stop PostgreSQL production stack
	$(MAKE) -C $(PG_DIR) stop

postgres-restart: ## Restart PostgreSQL production stack
	$(MAKE) -C $(PG_DIR) restart

postgres-status: ## Show PostgreSQL container status
	$(MAKE) -C $(PG_DIR) status

backup-pg: ## Run database backup (delegated)
	$(MAKE) -C $(PG_DIR) backup

logs-pg: ## Show PostgreSQL logs (delegated)
	$(MAKE) -C $(PG_DIR) logs

monitor-pg: ## Run PostgreSQL health monitor
	$(MAKE) -C $(PG_DIR) monitor

security-pg: ## Run PostgreSQL security audit
	$(MAKE) -C $(PG_DIR) security

pg-shell: ## Open psql interactive shell (delegated)
	$(MAKE) -C $(PG_DIR) connect

# ---------------------------------------------------------------------------
# Cleaning / Maintenance
# ---------------------------------------------------------------------------
clean: ## Clean transient artifacts (logs + old backups via sub-make)
	$(MAKE) -C $(PG_DIR) clean-all || true
	@echo "✅ Clean complete"

# End of Makefile
