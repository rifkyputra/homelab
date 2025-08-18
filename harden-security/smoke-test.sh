#!/bin/bash
# smoke-test.sh - verify basic expected changes (best-effort)
set -euo pipefail
. ./lib/harden-lib.sh
require_root
printf "Smoke test report:\n"
printf "- SSH PermitRootLogin: "; grep -i '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null || echo "not set"
printf "- /etc/shadow perms: "; ls -l /etc/shadow || true
printf "- sysctl hardening present: "; [[ -f /etc/sysctl.d/99-hardening.conf ]] && echo yes || echo no
printf "- cron.allow exists: "; [[ -f /etc/cron.allow ]] && echo yes || echo no
printf "- fail2ban running: "; systemctl is-active fail2ban 2>/dev/null || echo unknown
printf "- firewall status (ufw): "; if command -v ufw &>/dev/null; then ufw status | head -n1; elif command -v firewall-cmd &>/dev/null; then firewall-cmd --state; else echo none; fi
