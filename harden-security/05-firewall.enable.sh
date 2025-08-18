#!/bin/bash
# 05-firewall.enable.sh - enable UFW or firewalld and allow SSH
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "05-firewall: starting"
if command -v ufw &>/dev/null; then
  ufw allow OpenSSH || true
  ufw --force enable
  log "05-firewall: ufw enabled"
elif command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-service=ssh
  firewall-cmd --reload
  log "05-firewall: firewalld configured"
else
  log "05-firewall: no known firewall installed; attempting to install ufw"
  install_pkgs ufw || true
  if command -v ufw &>/dev/null; then
    ufw allow OpenSSH
    ufw --force enable
    log "05-firewall: ufw installed and enabled"
  fi
fi
log "05-firewall: done"
