#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "[16] Install and run Lynis security audit"

if ! command -v lynis >/dev/null 2>&1; then
  aptq update || true
  aptq install lynis || { log_error "Failed installing lynis"; exit 1; }
else
  log "Lynis already installed"
fi

REPORT_DIR=/var/log/lynis
mkdir -p "$REPORT_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
log "Running baseline audit (this may take a few minutes)"
lynis audit system --quiet --logfile "$REPORT_DIR/lynis-$STAMP.log" || log_warning "Lynis returned non-zero (some findings expected)"

SUG_FILE="/var/log/lynis-report.dat"
if [[ -f "$SUG_FILE" ]]; then
  cp "$SUG_FILE" "$REPORT_DIR/report-$STAMP.dat" || true
  log "Stored report copy: $REPORT_DIR/report-$STAMP.dat"
fi

log_success "Lynis audit completed. Review findings above."
