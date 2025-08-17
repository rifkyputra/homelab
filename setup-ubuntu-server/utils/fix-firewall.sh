#!/usr/bin/env bash
set -euo pipefail

# Comprehensive homelab service diagnostics and fix script
echo "🔍 Diagnosing and fixing homelab service accessibility issues..."
echo "================================================================"

# Source the config
source ../config.env

# Function to check if a service is listening on a port
check_service_port() {
    local port=$1
    local service_name=$2
    echo "Checking $service_name (port $port)..."
    
    if sudo netstat -tlnp | grep -q ":$port "; then
        local bind_address=$(sudo netstat -tlnp | grep ":$port " | awk '{print $4}' | cut -d: -f1)
        if [[ "$bind_address" == "127.0.0.1" ]]; then
            echo "  ⚠️  $service_name is running but only listening on localhost"
            return 1
        else
            echo "  ✅ $service_name is running and accessible"
            return 0
        fi
    else
        echo "  ❌ $service_name is not running on port $port"
        return 2
    fi
}

# Function to fix Netdata configuration
fix_netdata() {
    echo "🔧 Fixing Netdata configuration..."
    if [[ -f "/etc/netdata/netdata.conf" ]]; then
        sudo sed -i 's/bind socket to IP = 127.0.0.1/bind socket to IP = 0.0.0.0/' /etc/netdata/netdata.conf
        sudo systemctl restart netdata
        echo "  ✅ Netdata configured to listen on all interfaces"
    else
        echo "  ⚠️  Netdata config not found, creating basic config..."
        sudo mkdir -p /etc/netdata
        echo -e "[global]\n    bind socket to IP = 0.0.0.0\n    default port = 19999" | sudo tee /etc/netdata/netdata.conf
        sudo systemctl restart netdata
    fi
}

# Function to check and start VNC service
fix_vnc() {
    echo "🔧 Checking VNC service..."
    if ! systemctl is-active --quiet vncserver@:1.service 2>/dev/null; then
        echo "  ⚠️  VNC service not running, attempting to start..."
        # Try to start VNC for the current user
        sudo systemctl enable vncserver@:1.service 2>/dev/null || true
        sudo systemctl start vncserver@:1.service 2>/dev/null || echo "  ⚠️  VNC service may need manual configuration"
    fi
}

# Function to check and start code-server
fix_code_server() {
    echo "🔧 Checking code-server..."
    if ! systemctl is-active --quiet code-server@$(whoami).service 2>/dev/null; then
        echo "  ⚠️  Code-server not running"
        if command -v code-server >/dev/null 2>&1; then
            echo "  ⚠️  Code-server installed but not running as service"
            echo "  ℹ️  You may need to configure it manually"
        else
            echo "  ❌ Code-server not installed"
        fi
    fi
}

# Function to check HTTPS/SSL
fix_https() {
    echo "🔧 Checking HTTPS configuration..."
    if ! sudo netstat -tlnp | grep -q ":443 "; then
        echo "  ⚠️  No service listening on port 443 (HTTPS)"
        echo "  ℹ️  If you have a domain configured, run certbot to enable HTTPS"
        if [[ -n "${DOMAIN_NAME:-}" ]]; then
            echo "  ℹ️  Domain configured: $DOMAIN_NAME"
            echo "  ℹ️  Run: sudo certbot --nginx -d $DOMAIN_NAME"
        fi
    fi
}

echo "🔍 Checking service accessibility..."
echo "=================================="

# Check each problematic service
check_service_port 19999 "Netdata"
netdata_status=$?

check_service_port 443 "HTTPS"
https_status=$?

check_service_port 8080 "Code-server"
codeserver_status=$?

check_service_port 5901 "VNC"
vnc_status=$?

echo
echo "🔧 Applying fixes..."
echo "==================="

# Fix services that need fixing
if [[ $netdata_status -eq 1 ]]; then
    fix_netdata
fi

if [[ $vnc_status -eq 2 ]]; then
    fix_vnc
fi

if [[ $codeserver_status -eq 2 ]]; then
    fix_code_server
fi

if [[ $https_status -eq 2 ]]; then
    fix_https
fi

# Ensure firewall rules are in place
echo
echo "🔧 Ensuring firewall rules are configured..."
echo "==========================================="

# Add rules for each port from OPEN_PORTS to ALLOWED_CIDRS
for CIDR in ${ALLOWED_CIDRS}; do
  for PORT in ${OPEN_PORTS}; do
    if ! sudo ufw status | grep -q "Allow ${PORT} from ${CIDR}"; then
        echo "Adding rule: Allow port ${PORT} from ${CIDR}"
        sudo ufw allow from "$CIDR" to any port "$PORT" comment "Allow ${PORT} from ${CIDR}"
    fi
  done
done

echo
echo "📊 Final Status Check..."
echo "======================="
echo "Current UFW status:"
sudo ufw status | grep -E "(443|8080|5901|19999)"

echo
echo "Services listening:"
sudo netstat -tlnp | grep -E ":(443|8080|5901|19999)\s" || echo "No services found on problematic ports"

echo
echo "✅ Service diagnostics and fixes completed!"
echo "ℹ️  Re-run your accessibility check to see improvements."
