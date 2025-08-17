#!/usr/bin/env bash
set -euo pipefail

# Quick fix script to add missing firewall rules
echo "Adding missing UFW rules for homelab services..."

# Source the config
source /Users/rifkyputra/Projects/selfhostpg/setup-ubuntu-server/config.env

# Add rules for each port from OPEN_PORTS to ALLOWED_CIDRS
for CIDR in ${ALLOWED_CIDRS}; do
  for PORT in ${OPEN_PORTS}; do
    echo "Adding rule: Allow port ${PORT} from ${CIDR}"
    sudo ufw allow from "$CIDR" to any port "$PORT" comment "Allow ${PORT} from ${CIDR}"
  done
done

echo "Current UFW status:"
sudo ufw status verbose

echo "✅ Firewall rules updated! You should now be able to access services from your LAN."
echo "Try accessing Netdata at: http://192.168.1.10:19999"
