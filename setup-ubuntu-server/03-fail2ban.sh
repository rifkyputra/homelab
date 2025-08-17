#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "Install and configure Fail2ban"
aptq install fail2ban
cat >/etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1
[sshd]
enabled = true
EOF
systemctl enable --now fail2ban
