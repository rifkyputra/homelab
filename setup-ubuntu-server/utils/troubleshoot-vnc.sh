#!/usr/bin/env bash
set -euo pipefail

# VNC troubleshooting script
echo "🔍 VNC Server Troubleshooting"
echo "============================="

echo "📋 Service Status:"
systemctl status vncserver@1.service --no-pager -l || true

echo
echo "📋 Recent Logs (last 20 lines):"
journalctl -u vncserver@1.service --no-pager -l -n 20 || true

echo
echo "📋 VNC Process Check:"
ps aux | grep vnc | grep -v grep || echo "No VNC processes found"

echo
echo "📋 Network Listening Check:"
sudo netstat -tlnp | grep :5901 || echo "No service listening on port 5901"

echo
echo "📋 VNC Files Check:"
echo "VNC directory contents (~/.vnc/):"
ls -la ~/.vnc/ 2>/dev/null || echo "VNC directory doesn't exist"

echo
echo "📋 Display Check:"
echo "Active displays:"
ls /tmp/.X11-unix/ 2>/dev/null || echo "No X11 displays found"

echo
echo "📋 VNC Password Check:"
if [[ -f ~/.vnc/passwd ]]; then
    echo "✅ VNC password file exists"
else
    echo "❌ VNC password file missing - run: vncpasswd"
fi

echo
echo "📋 Desktop Environment Check:"
if command -v gnome-session >/dev/null 2>&1; then
    echo "✅ GNOME found"
elif command -v startxfce4 >/dev/null 2>&1; then
    echo "✅ XFCE found"
elif command -v startkde >/dev/null 2>&1; then
    echo "✅ KDE found"
else
    echo "⚠️  No desktop environment detected"
fi

echo
echo "🔧 Quick Fixes:"
echo "1. Set VNC password: vncpasswd"
echo "2. Restart VNC service: sudo systemctl restart vncserver@1.service"
echo "3. Check firewall: sudo ufw status | grep 5901"
echo "4. Manual start: vncserver :1"
echo "5. Kill and restart: vncserver -kill :1 && vncserver :1"
