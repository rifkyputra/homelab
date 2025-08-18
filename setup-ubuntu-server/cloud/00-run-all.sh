#!/usr/bin/env bash
set -euo pipefail
# Cloud (public VPS/EC2/DigitalOcean) lean profile.
# Omits virtualization, desktop, static IP, optionally monitoring (can add later).
# Puts firewall early; expects tighter ALLOWED_CIDRS and OPEN_PORTS.
SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)"
SCRIPTS=(
  "01-basics-and-ssh.sh"
  "02-unattended-upgrades.sh"
  "03-fail2ban.sh"
  "13-firewall-ufw.sh"     # early lock-down
  "14-tailscale.sh"         # optional
  "15-swap.sh"
  "05-docker.sh"
  "04-nginx-certbot.sh"
  "11-apps-compose.sh"
  "12-dokku.sh"
  "16-lynis.sh"
)
# To add monitoring later insert "09-monitoring.sh" before dokku.
source "${SCRIPT_ROOT}/runner.sh"
