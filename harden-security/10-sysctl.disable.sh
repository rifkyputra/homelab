#!/bin/bash
# 10-sysctl.disable.sh - restore previous sysctl config if available
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "10-sysctl.disable: starting"
bak=$(ls -1t /var/lib/harden-security/99-hardening.conf.bak.* 2>/dev/null | head -n1 || true)
conf="/etc/sysctl.d/99-hardening.conf"
if [[ -n "$bak" ]]; then
  restore_file "$bak" "$conf" && sysctl --system || true
  log "10-sysctl.disable: restored $bak"
else
  rm -f "$conf" || true
  sysctl --system || true
  log "10-sysctl.disable: removed $conf"
fi
log "10-sysctl.disable: done"
