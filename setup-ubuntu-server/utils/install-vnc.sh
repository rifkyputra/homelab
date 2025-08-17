#!/usr/bin/env bash
set -euo pipefail

# VNC installation and configuration script
echo "🚀 Installing and configuring VNC server..."
echo "==========================================="

# Source the config
source ../config.env

# Get the current user
CURRENT_USER=$(whoami)
if [[ "$CURRENT_USER" == "root" ]]; then
    echo "❌ This script should not be run as root"
    echo "   Run it as your regular user with sudo when needed"
    exit 1
fi

echo "👤 Setting up VNC for user: $CURRENT_USER"

# Install TigerVNC if not already installed
if ! command -v vncserver >/dev/null 2>&1; then
    echo "📦 Installing TigerVNC server..."
    sudo apt update
    sudo apt install -y tigervnc-standalone-server tigervnc-common
    echo "✅ TigerVNC installed"
else
    echo "✅ TigerVNC is already installed"
fi

# Stop any existing VNC server
echo "🛑 Stopping any existing VNC servers..."
vncserver -kill :1 2>/dev/null || true
sudo systemctl stop vncserver@1.service 2>/dev/null || true

# Create VNC directory
mkdir -p ~/.vnc

# Check if VNC password is set
echo "🔐 Checking VNC password..."
if [[ ! -f ~/.vnc/passwd ]]; then
    echo "⚠️  No VNC password found. You'll need to set one."
    echo "💡 Run: vncpasswd"
    echo "   Then restart this script."
    exit 1
else
    echo "✅ VNC password is already set"
fi

# Create xstartup script
echo "⚙️  Creating VNC startup script..."
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
# Try to start the desktop environment
if command -v gnome-session >/dev/null 2>&1; then
    exec gnome-session
elif command -v startxfce4 >/dev/null 2>&1; then
    exec startxfce4
elif command -v startkde >/dev/null 2>&1; then
    exec startkde
elif command -v startlxde >/dev/null 2>&1; then
    exec startlxde
else
    # Fallback to a simple window manager
    exec xterm
fi
EOF

chmod +x ~/.vnc/xstartup
echo "✅ VNC startup script created"

# Create VNC config
echo "⚙️  Creating VNC configuration..."
cat > ~/.vnc/config << EOF
session=gnome
geometry=${VNC_GEOMETRY:-1920x1080}
localhost=no
alwaysshared
EOF

echo "✅ VNC configuration created"

# Create systemd service file
echo "🔧 Setting up systemd service..."
sudo tee /etc/systemd/system/vncserver@.service > /dev/null << 'EOF'
[Unit]
Description=Start TigerVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=%i
Group=%i
WorkingDirectory=%h

PIDFile=%h/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1920x1080 :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

echo "✅ VNC systemd service created"

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable vncserver@1.service

# Start VNC server
echo "🚀 Starting VNC server..."
if sudo systemctl start vncserver@1.service; then
    echo "✅ VNC server started successfully"
else
    echo "❌ VNC server failed to start"
    echo "📋 Checking service status..."
    sudo systemctl status vncserver@1.service --no-pager -l
    echo
    echo "📋 Recent logs:"
    sudo journalctl -u vncserver@1.service --no-pager -l -n 20
    exit 1
fi

# Wait a moment and check status
sleep 2
if systemctl is-active --quiet vncserver@1.service; then
    echo "✅ VNC server is running"
    
    # Show connection information
    echo
    echo "🌐 VNC server is now accessible!"
    echo "==============================="
    echo "🔗 VNC Display: :1"
    echo "🔗 Port: 5901"
    if [[ -n "${STATIC_IP_CIDR:-}" ]]; then
        STATIC_IP=$(echo "${STATIC_IP_CIDR}" | cut -d'/' -f1)
        echo "🔗 Connect to: ${STATIC_IP}:5901"
    else
        echo "🔗 Connect to: $(hostname -I | awk '{print $1}'):5901"
    fi
    echo "🔐 Use the password you set with 'vncpasswd'"
    
    echo
    echo "📋 VNC Client Examples:"
    echo "   • Windows: Use TigerVNC Viewer, RealVNC Viewer, or TightVNC Viewer"
    echo "   • macOS: Use built-in Screen Sharing or VNC Viewer"
    echo "   • Linux: Use Remmina, TigerVNC Viewer, or vncviewer"
    
    echo
    echo "📋 Useful commands:"
    echo "   Check status:    systemctl status vncserver@1.service"
    echo "   View logs:       journalctl -u vncserver@1.service -f"
    echo "   Restart:         sudo systemctl restart vncserver@1.service"
    echo "   Stop:            sudo systemctl stop vncserver@1.service"
    echo "   Change password: vncpasswd"
else
    echo "❌ VNC server is not running properly"
    echo "📋 Service status:"
    sudo systemctl status vncserver@1.service --no-pager -l
fi

echo
echo "⚠️  Security Notes:"
echo "   • VNC traffic is not encrypted by default"
echo "   • Consider using SSH tunneling for remote access:"
echo "     ssh -L 5901:localhost:5901 user@server"
echo "   • Access is allowed from your LAN (firewall rules already configured)"

echo
echo "✅ VNC server installation and configuration completed!"
