#!/bin/bash
# 11-cron-restrict.disable.sh - restore previous cron.allow if exists
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "11-cron-restrict.disable: starting"
bak=$(ls -1t /var/lib/harden-security/cron.allow.bak.* 2>/dev/null | head -n1 || true)
if [[ -n "$bak" ]]; then
  restore_file "$bak" /etc/cron.allow && log "11-cron-restrict.disable: restored $bak"
else
  rm -f /etc/cron.allow || true
  log "11-cron-restrict.disable: removed /etc/cron.allow"
fi
log "11-cron-restrict.disable: done"
