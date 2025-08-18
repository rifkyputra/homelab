#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "[02] Enable unattended security upgrades"

if ! dpkg -s unattended-upgrades >/dev/null 2>&1; then
  aptq update || true
  aptq install unattended-upgrades apt-listchanges || {
    log_error "Failed installing unattended-upgrades"
    exit 1
  }
fi

CFG="/etc/apt/apt.conf.d/50unattended-upgrades"
ALLOW_NON_SECURITY_UPDATES=${ALLOW_NON_SECURITY_UPDATES:-false}
if [[ ! -f "$CFG" ]]; then
  log_warning "Configuration file $CFG missing (package install issue?)"
else
  if [[ "$ALLOW_NON_SECURITY_UPDATES" != "true" ]]; then
    sed -i 's#^\s*"\${distro_id}:\${distro_codename}-updates";#// "${distro_id}:${distro_codename}-updates";#' "$CFG" || true
  fi
  grep -q 'Automatic-Reboot-Time' "$CFG" || cat >>"$CFG" <<'EOF'

// Auto reboot if needed at 03:30
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:30";
EOF
fi

DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive unattended-upgrades || true
systemctl restart unattended-upgrades || true

log_success "Unattended upgrades configured"
