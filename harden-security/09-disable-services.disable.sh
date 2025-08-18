#!/bin/bash
# 09-disable-services.disable.sh - enable previously disabled services if unit exists
set -euo pipefail
. ./lib/harden-lib.sh
require_root
SERVICES=(avahi-daemon cups)
log "09-disable-services.disable: starting"
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^$svc" 2>/dev/null; then
    systemctl enable "$svc" 2>/dev/null || true
    systemctl start "$svc" 2>/dev/null || true
    log "09-disable-services.disable: $svc started"
  else
    log "09-disable-services.disable: $svc not present"
  fi
done
log "09-disable-services.disable: done"
