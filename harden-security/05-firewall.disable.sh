#!/bin/bash
# 05-firewall.disable.sh - disable UFW or remove SSH rule
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "05-firewall.disable: starting"
if command -v ufw &>/dev/null; then
  # remove OpenSSH rule (best-effort)
  ufw deny OpenSSH || true
  ufw --force disable || true
  log "05-firewall.disable: ufw disabled"
elif command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --remove-service=ssh || true
  firewall-cmd --reload || true
  log "05-firewall.disable: firewalld rule removed"
else
  log "05-firewall.disable: no firewall found"
fi
log "05-firewall.disable: done"
