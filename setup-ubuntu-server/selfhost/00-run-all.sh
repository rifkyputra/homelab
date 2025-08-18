#!/usr/bin/env bash
set -euo pipefail
# Self-host (full homelab) profile: original comprehensive sequence.
SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)"
SCRIPTS=(
  "01-basics-and-ssh.sh"
  "02-unattended-upgrades.sh"
  "03-fail2ban.sh"
  "14-tailscale.sh"          # optional (skips if TAILSCALE_ENABLE!=true)
  "15-swap.sh"               # ensure swap before heavy builds
  "04-nginx-certbot.sh"
  "05-docker.sh"
  "06-virtualization.sh"
  "07-cockpit.sh"
  "08-remote-desktop.sh"
  "09-monitoring.sh"
  "10-netplan-static-ip.sh"
  "11-apps-compose.sh"
  "12-dokku.sh"
  "16-lynis.sh"              # audit near end
  "13-firewall-ufw.sh"       # final tighten (could move earlier)
)
source "${SCRIPT_ROOT}/runner.sh"
