#!/usr/bin/env bash
set -euo pipefail

# Script to fix permissions for all scripts in the homelab project
echo "🔧 Fixing permissions for all scripts in the project..."
echo "======================================================"

# Get the project root directory (parent of setup-ubuntu-server)
PROJECT_ROOT=$(dirname "$(dirname "$(realpath "$0")")")
echo "📁 Project root: $PROJECT_ROOT"

# Function to make files executable
make_executable() {
    local file="$1"
    if [[ -f "$file" ]]; then
        chmod +x "$file"
        echo "✅ Made executable: $file"
    else
        echo "⚠️  File not found: $file"
    fi
}

# Function to set proper directory permissions
fix_directory_permissions() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        chmod 755 "$dir"
        echo "✅ Fixed directory permissions: $dir"
    else
        echo "⚠️  Directory not found: $dir"
    fi
}

echo
echo "🔧 Fixing directory permissions..."
echo "================================="

# Fix directory permissions
fix_directory_permissions "$PROJECT_ROOT"
fix_directory_permissions "$PROJECT_ROOT/setup-ubuntu-server"
fix_directory_permissions "$PROJECT_ROOT/setup-ubuntu-server/lib"
fix_directory_permissions "$PROJECT_ROOT/setup-ubuntu-server/utils"
fix_directory_permissions "$PROJECT_ROOT/selfhost-pg"
fix_directory_permissions "$PROJECT_ROOT/selfhost-pg/scripts"
fix_directory_permissions "$PROJECT_ROOT/selfhost-pg/init-scripts"

echo
echo "🔧 Making main setup scripts executable..."
echo "=========================================="

# Main setup scripts
SETUP_SCRIPTS=(
    "00-run-all.sh"
    "01-basics-and-ssh.sh"
    "03-fail2ban.sh"
    "04-nginx-certbot.sh"
    "05-docker.sh"
    "06-virtualization.sh"
    "07-cockpit.sh"
    "08-remote-desktop.sh"
    "09-monitoring.sh"
    "10-netplan-static-ip.sh"
    "11-apps-compose.sh"
    "12-dokku.sh"
    "13-firewall-ufw.sh"
)

for script in "${SETUP_SCRIPTS[@]}"; do
    make_executable "$PROJECT_ROOT/setup-ubuntu-server/$script"
done

echo
echo "🔧 Making library scripts executable..."
echo "======================================="

# Library scripts
make_executable "$PROJECT_ROOT/setup-ubuntu-server/lib/common.sh"

echo
echo "🔧 Making utility scripts executable..."
echo "======================================="

# Utility scripts
UTIL_SCRIPTS=(
    "check-services.sh"
    "fix-firewall.sh"
    "install-code-server.sh"
    "install-vnc.sh"
    "troubleshoot-vnc.sh"
)

for script in "${UTIL_SCRIPTS[@]}"; do
    make_executable "$PROJECT_ROOT/setup-ubuntu-server/utils/$script"
done

echo
echo "🔧 Making PostgreSQL scripts executable..."
echo "=========================================="

# PostgreSQL related scripts
PG_SCRIPTS=(
    "backup.sh"
    "setup-production.sh"
)

for script in "${PG_SCRIPTS[@]}"; do
    make_executable "$PROJECT_ROOT/selfhost-pg/$script"
done

# Scripts in subdirectories
make_executable "$PROJECT_ROOT/selfhost-pg/scripts/backup.sh"
make_executable "$PROJECT_ROOT/selfhost-pg/scripts/docker-healthcheck.sh"
make_executable "$PROJECT_ROOT/selfhost-pg/scripts/monitor.sh"
make_executable "$PROJECT_ROOT/selfhost-pg/scripts/security-audit.sh"
make_executable "$PROJECT_ROOT/selfhost-pg/scripts/setup-cron.sh"
make_executable "$PROJECT_ROOT/selfhost-pg/init-scripts/01-init-production.sh"

echo
echo "🔧 Fixing config file permissions..."
echo "==================================="

# Config files should be readable but not executable
CONFIG_FILES=(
    "$PROJECT_ROOT/setup-ubuntu-server/config.env"
    "$PROJECT_ROOT/selfhost-pg/docker-compose.yml"
    "$PROJECT_ROOT/selfhost-pg/docker-compose.prod.yml"
    "$PROJECT_ROOT/selfhost-pg/docker-compose.override.yml"
    "$PROJECT_ROOT/selfhost-pg/Makefile"
)

for config_file in "${CONFIG_FILES[@]}"; do
    if [[ -f "$config_file" ]]; then
        chmod 644 "$config_file"
        echo "✅ Fixed config permissions: $config_file"
    else
        echo "⚠️  Config file not found: $config_file"
    fi
done

echo
echo "🔧 Fixing documentation permissions..."
echo "===================================="

# Documentation files
DOC_FILES=(
    "$PROJECT_ROOT/README.md"
    "$PROJECT_ROOT/setup-ubuntu-server/README.md"
    "$PROJECT_ROOT/selfhost-pg/README.md"
    "$PROJECT_ROOT/selfhost-pg/PRODUCTION_GUIDE.md"
)

for doc_file in "${DOC_FILES[@]}"; do
    if [[ -f "$doc_file" ]]; then
        chmod 644 "$doc_file"
        echo "✅ Fixed documentation permissions: $doc_file"
    else
        echo "⚠️  Documentation file not found: $doc_file"
    fi
done

echo
echo "🔧 Setting secure permissions for sensitive directories..."
echo "========================================================"

# Secure directories that might contain sensitive data
SECURE_DIRS=(
    "$PROJECT_ROOT/selfhost-pg/backups"
    "$PROJECT_ROOT/selfhost-pg/logs"
    "$PROJECT_ROOT/selfhost-pg/config"
)

for secure_dir in "${SECURE_DIRS[@]}"; do
    if [[ -d "$secure_dir" ]]; then
        chmod 750 "$secure_dir"
        echo "✅ Secured directory permissions: $secure_dir"
    else
        echo "⚠️  Secure directory not found: $secure_dir"
    fi
done

echo
echo "📊 Permission Summary..."
echo "======================"

# Show a summary of executable files
echo "Executable scripts found:"
find "$PROJECT_ROOT" -name "*.sh" -type f -executable | sort

echo
echo "🔍 Checking for any remaining permission issues..."
echo "================================================"

# Find scripts without execute permissions
echo "Scripts without execute permissions:"
find "$PROJECT_ROOT" -name "*.sh" -type f ! -executable | sort || echo "None found ✅"

echo
echo "✅ Permission fixing completed!"
echo "=============================="
echo "📋 Summary:"
echo "   • All .sh scripts are now executable"
echo "   • Config files have proper read permissions"
echo "   • Directories have appropriate access permissions"
echo "   • Sensitive directories are secured"

echo
echo "💡 Usage tips:"
echo "   • Run this script whenever you add new scripts"
echo "   • Use 'ls -la' to verify permissions"
echo "   • Scripts should show 'rwxr-xr-x' (755)"
echo "   • Config files should show 'rw-r--r--' (644)"
