#!/usr/bin/env bash
set -euo pipefail

# Code-server installation and configuration script
echo "🚀 Installing and configuring code-server..."
echo "============================================="

# Source the config
source ../config.env

# Check if code-server is already installed
if command -v code-server >/dev/null 2>&1; then
    echo "✅ Code-server is already installed"
    CODE_SERVER_VERSION=$(code-server --version | head -n1)
    echo "   Version: $CODE_SERVER_VERSION"
else
    echo "📦 Installing code-server..."
    
    # Install code-server using the official install script
    curl -fsSL https://code-server.dev/install.sh | sh
    
    echo "✅ Code-server installed successfully"
fi

# Configure code-server
echo "⚙️  Configuring code-server..."

# Create config directory
mkdir -p ~/.config/code-server

# Generate a random password if none exists
if [[ ! -f ~/.config/code-server/config.yaml ]]; then
    CODESERVER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${CODESERVER_PASSWORD}
cert: false
EOF
    
    echo "✅ Code-server configuration created"
    echo "🔐 Generated password: ${CODESERVER_PASSWORD}"
    echo "📝 Password saved in: ~/.config/code-server/config.yaml"
else
    echo "✅ Code-server configuration already exists"
    EXISTING_PASSWORD=$(grep "password:" ~/.config/code-server/config.yaml | cut -d' ' -f2)
    echo "🔐 Existing password: ${EXISTING_PASSWORD}"
fi

# Create systemd service for code-server
echo "🔧 Setting up systemd service..."

sudo tee /etc/systemd/system/code-server@.service > /dev/null << 'EOF'
[Unit]
Description=code-server
After=network.target

[Service]
Type=exec
ExecStart=/usr/bin/code-server
Restart=always
User=%i
# Our unit name is "code-server@$USER" so this gives us the right User automatically.

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
echo "🚀 Starting code-server service..."
sudo systemctl daemon-reload
sudo systemctl enable code-server@$(whoami).service
sudo systemctl start code-server@$(whoami).service

# Wait a moment for service to start
sleep 3

# Check service status
if systemctl is-active --quiet code-server@$(whoami).service; then
    echo "✅ Code-server service is running"
else
    echo "❌ Code-server service failed to start"
    echo "📋 Service status:"
    systemctl status code-server@$(whoami).service --no-pager -l
    exit 1
fi

# Show connection information
echo
echo "🌐 Code-server is now accessible!"
echo "================================="
echo "🔗 Local access: http://localhost:8080"
if [[ -n "${STATIC_IP_CIDR:-}" ]]; then
    STATIC_IP=$(echo "${STATIC_IP_CIDR}" | cut -d'/' -f1)
    echo "🔗 Network access: http://${STATIC_IP}:8080"
fi
echo "🔐 Password: $(grep "password:" ~/.config/code-server/config.yaml | cut -d' ' -f2)"

echo
echo "📋 Useful commands:"
echo "   Check status:    systemctl status code-server@$(whoami).service"
echo "   View logs:       journalctl -u code-server@$(whoami).service -f"
echo "   Restart:         sudo systemctl restart code-server@$(whoami).service"
echo "   Stop:            sudo systemctl stop code-server@$(whoami).service"

echo
echo "⚠️  Security Notes:"
echo "   • Code-server is configured with password authentication"
echo "   • Access is allowed from your LAN (firewall rules already configured)"
echo "   • Consider using HTTPS in production environments"

echo
echo "✅ Code-server installation and configuration completed!"
