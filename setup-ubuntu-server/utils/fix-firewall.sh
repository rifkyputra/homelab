#!/usr/bin/env bash
set -# Function to check and start VNC service
fix_vnc() {
    echo "🔧 Checking VNC service..."
    if ! systemctl is-active --quiet vncserver@1.service 2>/dev/null; then
        echo "  ⚠️  VNC service not running"
        echo "  ℹ️  VNC requires manual setup. To install and configure VNC:"
        echo "       1. Set VNC password: vncpasswd"
        echo "       2. Run: ./install-vnc.sh"
        echo "       3. Or troubleshoot: ./troubleshoot-vnc.sh"
    else
        echo "  ✅ VNC service is running"
    fi
}il

# Comprehensive homelab service diagnostics and fix script
echo "🔍 Diagnosing and fixing homelab service accessibility issues..."
echo "================================================================"

# Source the config
source ../config.env

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
            echo "  ℹ️  Try: sudo systemctl start code-server@$(whoami).service"
        else
            echo "  ❌ Code-server not installed"
            echo "  ℹ️  To install code-server, run: ./install-code-server.sh"
        fi
    else
        echo "  ✅ Code-server service is running"
    fi
}

# Function to check HTTPS/SSL
fix_https() {
    echo "🔧 Checking HTTPS configuration..."
    if ! sudo netstat -tlnp | grep -q ":443 "; then
        echo "  ⚠️  No service listening on port 443 (HTTPS)"
        if [[ -n "${DOMAIN_NAME:-}" ]] && [[ "${DOMAIN_NAME}" != "" ]]; then
            echo "  ℹ️  Domain configured: $DOMAIN_NAME"
            echo "  ℹ️  To enable HTTPS, run: sudo certbot --nginx -d $DOMAIN_NAME"
        else
            echo "  ℹ️  No domain configured in config.env"
            echo "  ℹ️  To enable HTTPS:"
            echo "       1. Set DOMAIN_NAME and ADMIN_EMAIL in ../config.env"
            echo "       2. Run: sudo certbot --nginx -d yourdomain.com"
            echo "  ℹ️  Or access services via HTTP on port 80 instead"
        fi
        
        # Check if nginx has any SSL configuration
        if sudo nginx -T 2>/dev/null | grep -q "listen.*443.*ssl"; then
            echo "  ⚠️  SSL configuration found in nginx but not active"
            echo "  ℹ️  Try: sudo systemctl reload nginx"
        fi
    fi
}

echo "🔍 Checking service accessibility..."
echo "=================================="

# Define services to check (port:name:fix_function)
declare -a SERVICES=(
    "19999:Netdata:fix_netdata"
    "443:HTTPS:fix_https"
    "8080:Code-server:fix_code_server"
    "5901:VNC:fix_vnc"
)

# Get netstat output once
NETSTAT_OUTPUT=$(sudo netstat -tlnp)

# Check each service
declare -A service_status
declare -A service_localhost
for service in "${SERVICES[@]}"; do
    IFS=':' read -r port name fix_func <<< "$service"
    echo "Checking $name (port $port)..."
    
    if echo "$NETSTAT_OUTPUT" | grep -q ":$port "; then
        bind_address=$(echo "$NETSTAT_OUTPUT" | grep ":$port " | awk '{print $4}' | cut -d: -f1)
        if [[ "$bind_address" == "127.0.0.1" ]]; then
            echo "  ⚠️  $name is running but only listening on localhost"
            service_status["$port"]=0
            service_localhost["$port"]="true"
        else
            echo "  ✅ $name is running and accessible"
            service_status["$port"]=0
            service_localhost["$port"]="false"
        fi
    else
        echo "  ❌ $name is not running on port $port"
        service_status["$port"]=2
        service_localhost["$port"]="false"
    fi
done

echo
echo "🔧 Applying fixes..."
echo "==================="

# Fix services that need fixing
for service in "${SERVICES[@]}"; do
    IFS=':' read -r port name fix_func <<< "$service"
    
    # Fix if service is localhost-only or not running
    if [[ "${service_localhost[$port]}" == "true" ]] || [[ "${service_status[$port]}" -eq 2 ]]; then
        $fix_func
    fi
done

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
