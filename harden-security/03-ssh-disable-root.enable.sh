#!/bin/bash
# 03-ssh-disable-root.enable.sh - disable PermitRootLogin in sshd_config
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "03-ssh-disable-root: starting"
SSHD="/etc/ssh/sshd_config"
if [[ -f "$SSHD" ]]; then
  bak=$(backup_file "$SSHD")
  if grep -q '^PermitRootLogin' "$SSHD"; then
    sed -ri 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSHD"
  else
    echo 'PermitRootLogin no' >> "$SSHD"
  fi
  log "03-ssh-disable-root: updated $SSHD (backup: $bak)"
  systemctl reload sshd 2>/dev/null || service ssh reload 2>/dev/null || true
else
  log "03-ssh-disable-root: $SSHD not found"
fi
log "03-ssh-disable-root: done"
