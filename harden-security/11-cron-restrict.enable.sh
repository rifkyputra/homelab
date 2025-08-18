#!/bin/bash
# 11-cron-restrict.enable.sh - restrict cron to root only
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "11-cron-restrict: starting"
if [[ -f /etc/cron.allow ]]; then
  bak=$(backup_file /etc/cron.allow)
  echo root > /etc/cron.allow
  chmod 600 /etc/cron.allow
  log "11-cron-restrict: /etc/cron.allow updated (backup $bak)"
else
  echo root > /etc/cron.allow
  chmod 600 /etc/cron.allow
  log "11-cron-restrict: created /etc/cron.allow"
fi
log "11-cron-restrict: done"
