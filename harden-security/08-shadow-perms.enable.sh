#!/bin/bash
# 08-shadow-perms.enable.sh - set secure perms on /etc/shadow
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "08-shadow-perms: starting"
if [[ -e /etc/shadow ]]; then
  bak=$(backup_file /etc/shadow)
  chown root:shadow /etc/shadow 2>/dev/null || chown root:root /etc/shadow
  chmod 640 /etc/shadow
  log "08-shadow-perms: applied (backup $bak)"
else
  log "08-shadow-perms: /etc/shadow not found"
fi
log "08-shadow-perms: done"
