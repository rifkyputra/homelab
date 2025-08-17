#!/bin/bash
# Cron job setup script for PostgreSQL production automation
# Run this script to install automated tasks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔧 Setting up PostgreSQL automation cron jobs..."

# Create cron jobs
CRON_FILE="/tmp/postgres_cron"

cat > "$CRON_FILE" << EOF
# PostgreSQL Production Automation
# Generated on $(date)

# Daily backup at 2:00 AM
0 2 * * * cd $PROJECT_DIR && ./scripts/backup.sh >> logs/cron.log 2>&1

# Health monitoring every 15 minutes
*/15 * * * * cd $PROJECT_DIR && ./scripts/monitor.sh >> logs/cron.log 2>&1

# Security audit weekly on Sunday at 3:00 AM
0 3 * * 0 cd $PROJECT_DIR && ./scripts/security-audit.sh >> logs/cron.log 2>&1

# Database maintenance monthly on 1st day at 4:00 AM
0 4 1 * * cd $PROJECT_DIR && make vacuum >> logs/cron.log 2>&1

# Log rotation weekly on Monday at 1:00 AM
0 1 * * 1 cd $PROJECT_DIR && make clean-logs >> logs/cron.log 2>&1

# Backup cleanup monthly on 15th at 5:00 AM
0 5 15 * * cd $PROJECT_DIR && make clean-backups >> logs/cron.log 2>&1

EOF

# Install cron jobs
crontab "$CRON_FILE"
rm "$CRON_FILE"

echo "✅ Cron jobs installed successfully!"
echo ""
echo "📋 Installed jobs:"
echo "  • Daily backups at 2:00 AM"
echo "  • Health monitoring every 15 minutes" 
echo "  • Weekly security audits on Sunday at 3:00 AM"
echo "  • Monthly database maintenance on 1st at 4:00 AM"
echo "  • Weekly log cleanup on Monday at 1:00 AM"
echo "  • Monthly backup cleanup on 15th at 5:00 AM"
echo ""
echo "View installed cron jobs: crontab -l"
echo "Remove cron jobs: crontab -r"
