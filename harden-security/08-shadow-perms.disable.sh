#!/bin/bash
# 08-shadow-perms.disable.sh - restore /etc/shadow from backup if available
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "08-shadow-perms.disable: starting"
bak=$(ls -1t /var/lib/harden-security/shadow.bak.* 2>/dev/null | head -n1 || true)
if [[ -n "$bak" ]]; then
  restore_file "$bak" /etc/shadow && log "08-shadow-perms.disable: restored $bak"
else
  log "08-shadow-perms.disable: no backup found; adjusting perms to conservative defaults"
  chown root:root /etc/shadow || true
  chmod 600 /etc/shadow || true
fi
log "08-shadow-perms.disable: done"
