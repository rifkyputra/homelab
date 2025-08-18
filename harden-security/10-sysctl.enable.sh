#!/bin/bash
# 10-sysctl.enable.sh - apply network hardening via sysctl.d
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "10-sysctl: starting"
SYSCTL_CONF="/etc/sysctl.d/99-hardening.conf"
bak=$(backup_file "$SYSCTL_CONF")
cat > "$SYSCTL_CONF" <<'EOF'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
sysctl --system || true
log "10-sysctl: applied (backup: $bak)"
log "10-sysctl: done"
