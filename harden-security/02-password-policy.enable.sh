#!/bin/bash
# 02-password-policy.enable.sh - set min password length to 8 for pam_unix (Debian/Ubuntu)
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "02-password-policy: starting"
PAM_FILE="/etc/pam.d/common-password"
if [[ -f "$PAM_FILE" ]]; then
  bak=$(backup_file "$PAM_FILE")
  if ! grep -q 'minlen=8' "$PAM_FILE"; then
    sed -ri 's/(pam_unix.so.*)/\1 minlen=8/' "$PAM_FILE" || true
    echo "Applied minlen=8"
    log "02-password-policy: modified $PAM_FILE, backup at $bak"
  else
    log "02-password-policy: already configured"
  fi
else
  log "02-password-policy: $PAM_FILE not found; skipping"
fi
log "02-password-policy: done"
