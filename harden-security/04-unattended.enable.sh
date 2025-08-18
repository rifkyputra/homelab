#!/bin/bash
# 04-unattended.enable.sh - install and enable unattended-upgrades on Debian/Ubuntu
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "04-unattended: starting"
if command -v apt-get &>/dev/null; then
  install_pkgs unattended-upgrades
  dpkg-reconfigure -f noninteractive unattended-upgrades || true
  systemctl enable unattended-upgrades 2>/dev/null || true
  systemctl start unattended-upgrades 2>/dev/null || true
  log "04-unattended: enabled"
else
  log "04-unattended: apt not found; skipping"
fi
log "04-unattended: done"
