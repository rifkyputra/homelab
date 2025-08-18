#!/bin/bash
# harden-linux.sh - Idempotent Linux hardening script
# Usage: sudo ./harden-linux.sh

set -euo pipefail

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# 1. Update & upgrade system
apt-get update -y && apt-get upgrade -y 2>/dev/null || yum update -y 2>/dev/null || dnf upgrade -y 2>/dev/null || true

# 2. Set strong password policy (Debian/Ubuntu)
if [ -f /etc/pam.d/common-password ]; then
  if ! grep -q 'minlen=12' /etc/pam.d/common-password; then
    sed -i '/pam_unix.so/ s/$/ minlen=12/' /etc/pam.d/common-password
  fi
fi

# 3. Disable root SSH login
if grep -q '^PermitRootLogin' /etc/ssh/sshd_config; then
  sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
else
  echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
fi
systemctl reload sshd 2>/dev/null || service ssh reload 2>/dev/null || true

# 4. Set up automatic security updates (Debian/Ubuntu)
if command -v apt-get &>/dev/null; then
  apt-get install -y unattended-upgrades
  dpkg-reconfigure -f noninteractive unattended-upgrades
fi

# 5. Install and enable firewall (UFW or firewalld)
if command -v ufw &>/dev/null; then
  ufw allow OpenSSH
  ufw --force enable
elif command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-service=ssh
  firewall-cmd --reload
fi

# 6. Install and enable fail2ban
if ! command -v fail2ban-server &>/dev/null; then
  if command -v apt-get &>/dev/null; then
    apt-get install -y fail2ban
  elif command -v yum &>/dev/null; then
    yum install -y fail2ban
  elif command -v dnf &>/dev/null; then
    dnf install -y fail2ban
  fi
fi
systemctl enable fail2ban 2>/dev/null || true
systemctl start fail2ban 2>/dev/null || true

# 7. Remove unused packages
if command -v apt-get &>/dev/null; then
  apt-get autoremove -y
elif command -v yum &>/dev/null; then
  yum autoremove -y 2>/dev/null || true
elif command -v dnf &>/dev/null; then
  dnf autoremove -y 2>/dev/null || true
fi

# 8. Set permissions on /etc/shadow
chmod 640 /etc/shadow
chown root:shadow /etc/shadow

# 9. Disable unused services (example: avahi-daemon)
for svc in avahi-daemon cups; do
  systemctl disable $svc 2>/dev/null || true
  systemctl stop $svc 2>/dev/null || true
  service $svc stop 2>/dev/null || true
  chkconfig $svc off 2>/dev/null || true
  rc-update del $svc default 2>/dev/null || true
  update-rc.d -f $svc remove 2>/dev/null || true
  true
  done

# 10. Set up basic sysctl hardening
SYSCTL_CONF=/etc/sysctl.d/99-hardening.conf
cat <<EOF > $SYSCTL_CONF
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
sysctl --system

# 11. Restrict cron to root only
if [ -f /etc/cron.allow ]; then
  echo root > /etc/cron.allow
  chmod 600 /etc/cron.allow
fi

# 12. Log script run
logger "harden-linux.sh run completed on $(hostname)"

echo "Linux hardening complete. Please review settings for your environment."
