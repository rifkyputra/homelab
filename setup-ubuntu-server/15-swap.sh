#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "[15] Create swap file if absent"

SWAP_SIZE_GB=${SWAP_SIZE_GB:-2}
SWAPFILE=${SWAPFILE:-/swapfile}

if swapon --show | grep -q '^'; then
  log "Swap already present; skipping"
  exit 0
fi

log "Creating ${SWAP_SIZE_GB}G swap at ${SWAPFILE}"
if ! fallocate -l "${SWAP_SIZE_GB}G" "$SWAPFILE" 2>/dev/null; then
  log_warning "fallocate failed, falling back to dd (slower)"
  dd if=/dev/zero of="$SWAPFILE" bs=1G count="$SWAP_SIZE_GB" status=progress || { log_error "dd failed"; exit 1; }
fi
chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE"
swapon "$SWAPFILE"
grep -q "$SWAPFILE" /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
sysctl vm.swappiness=10 || true
grep -q 'vm.swappiness' /etc/sysctl.conf || echo 'vm.swappiness=10' >> /etc/sysctl.conf
log_success "Swap enabled"
free -h || true
