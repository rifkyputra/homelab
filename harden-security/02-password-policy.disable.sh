#!/bin/bash
# 02-password-policy.disable.sh - restore previous pam file if backup exists
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "02-password-policy.disable: starting"
# find most recent backup for common-password
bak=$(ls -1t /var/lib/harden-security/common-password.bak.* 2>/dev/null | head -n1 || true)
if [[ -n "$bak" ]]; then
  restore_file "$bak" /etc/pam.d/common-password && log "02-password-policy.disable: restored $bak"
else
  log "02-password-policy.disable: no backup found"
fi
log "02-password-policy.disable: done"
