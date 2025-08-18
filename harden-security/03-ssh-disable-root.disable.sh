#!/bin/bash
# 03-ssh-disable-root.disable.sh - restore sshd_config from backup if available
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "03-ssh-disable-root.disable: starting"
bak=$(ls -1t /var/lib/harden-security/sshd_config.bak.* 2>/dev/null | head -n1 || true)
if [[ -n "$bak" ]]; then
  restore_file "$bak" /etc/ssh/sshd_config && (systemctl reload sshd 2>/dev/null || service ssh reload 2>/dev/null || true)
  log "03-ssh-disable-root.disable: restored $bak"
else
  log "03-ssh-disable-root.disable: no backup found"
fi
log "03-ssh-disable-root.disable: done"
