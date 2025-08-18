#!/bin/bash
# 04-unattended.disable.sh - disable unattended-upgrades (Debian/Ubuntu)
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "04-unattended.disable: starting"
if systemctl list-unit-files | grep -q unattended-upgrades; then
  systemctl stop unattended-upgrades 2>/dev/null || true
  systemctl disable unattended-upgrades 2>/dev/null || true
  log "04-unattended.disable: stopped and disabled"
else
  log "04-unattended.disable: unattended-upgrades not present"
fi
log "04-unattended.disable: done"
