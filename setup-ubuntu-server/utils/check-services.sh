#!/usr/bin/env bash

# Service accessibility check
SERVER_IP="192.168.1.10"

echo "🔍 Checking homelab service accessibility..."
echo "========================================="

# Array of services to check
declare -A SERVICES=(
  ["SSH"]="22"
  ["HTTP"]="80"
  ["HTTPS"]="443"
  ["Cockpit"]="9090"
  ["Netdata"]="19999"
  ["Portainer"]="9000"
  ["Portainer-SSL"]="9443"
  ["Grafana"]="3000"
  ["Code-server"]="8080"
  ["VNC"]="5901"
)

# Check each service
for service in "${!SERVICES[@]}"; do
  port="${SERVICES[$service]}"
  printf "%-15s (port %s): " "$service" "$port"
  
  if timeout 3 bash -c "</dev/tcp/$SERVER_IP/$port" 2>/dev/null; then
    echo "✅ Accessible"
  else
    echo "❌ Not accessible"
  fi
done

echo ""
echo "📋 Service URLs:"
echo "  • Cockpit: https://$SERVER_IP:9090"
echo "  • Netdata: http://$SERVER_IP:19999"
echo "  • Portainer: http://$SERVER_IP:9000"
echo "  • Code-server: http://$SERVER_IP:8080"
echo "  • Grafana: http://$SERVER_IP:3000"
echo ""
echo "💡 If services show as not accessible, run: ./fix-firewall.sh"
