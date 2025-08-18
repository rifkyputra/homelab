#!/bin/bash
# 09-disable-services.enable.sh - disable a list of user-specified services
set -euo pipefail
. ./lib/harden-lib.sh
require_root
SERVICES=(avahi-daemon cups)
log "09-disable-services: starting"
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^$svc" 2>/dev/null; then
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    log "09-disable-services: $svc disabled"
  else
    log "09-disable-services: $svc not present"
  fi
done
log "09-disable-services: done"
