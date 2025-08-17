#!/usr/bin/env bash
set -euo pipefail

# TigerVNC installation + systemd setup with fallback mode
echo "🚀 Installing and configuring VNC server..."
echo "==========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

CURRENT_USER=$(whoami)
if [[ "$CURRENT_USER" == "root" ]]; then
	echo "❌ Don't run this as root. Use your normal user."; exit 1; fi

echo "👤 User: $CURRENT_USER"

if ! command -v vncserver >/dev/null 2>&1; then
	echo "📦 Installing TigerVNC..."
	sudo apt update
	sudo apt install -y tigervnc-standalone-server tigervnc-common
else
	echo "✅ TigerVNC already installed"
fi

echo "🛑 Stopping any existing :1"
vncserver -kill :1 2>/dev/null || true
sudo systemctl stop vncserver@1.service 2>/dev/null || true

mkdir -p ~/.vnc

echo "🔐 Checking VNC password file (~/.vnc/passwd)"
if [[ ! -f ~/.vnc/passwd ]]; then
	echo "⚠️ No password set. Run: vncpasswd  (then re-run this script)"
	exit 1
fi

echo "⚙️ Writing xstartup"
cat > ~/.vnc/xstartup <<'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
if command -v gnome-session >/dev/null 2>&1; then
	exec gnome-session
elif command -v startxfce4 >/dev/null 2>&1; then
	exec startxfce4
elif command -v startlxqt >/dev/null 2>&1; then
	exec startlxqt
elif command -v startlxde >/dev/null 2>&1; then
	exec startlxde
else
	exec xterm
fi
EOF
chmod +x ~/.vnc/xstartup

echo "⚙️ Writing config"
cat > ~/.vnc/config <<EOF
session=gnome
geometry=${VNC_GEOMETRY:-1920x1080}
localhost=no
alwaysshared
EOF

USER_HOME=$(getent passwd "$CURRENT_USER" | cut -d: -f6)
echo "🔍 Home dir: $USER_HOME"
if [[ ! -d "$USER_HOME" ]]; then echo "❌ Home directory missing"; exit 1; fi
if ! ls -ld "$USER_HOME" | grep -q "$CURRENT_USER"; then
	echo "⚠️ Ownership mismatch. Fix: sudo chown -R $CURRENT_USER:$CURRENT_USER $USER_HOME"; fi

# Primary (forking) unit
echo "🔧 Installing systemd unit (forking mode)"
sudo tee /etc/systemd/system/vncserver@.service >/dev/null <<EOF
[Unit]
Description=TigerVNC server for $CURRENT_USER on display :%i
After=network.target syslog.target

[Service]
Type=forking
User=$CURRENT_USER
Group=$CURRENT_USER
PAMName=login
WorkingDirectory=$USER_HOME
Environment=HOME=$USER_HOME USER=$CURRENT_USER LOGNAME=$CURRENT_USER
PIDFile=$USER_HOME/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1 || true
ExecStart=/usr/bin/vncserver -localhost no -depth ${VNC_DEPTH:-24} -geometry ${VNC_GEOMETRY:-1920x1080} :%i
ExecStop=/usr/bin/vncserver -kill :%i
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vncserver@1.service || true

echo "🚀 Starting VNC (forking)"
if sudo systemctl start vncserver@1.service; then
	sleep 2
	if systemctl is-active --quiet vncserver@1.service; then
		echo "✅ Started (forking)"
	fi
else
	echo "❌ Initial start failed"
fi

if ! systemctl is-active --quiet vncserver@1.service; then
	echo "🔁 Switching to simple/foreground mode fallback"
	sudo tee /etc/systemd/system/vncserver@.service >/dev/null <<EOF
[Unit]
Description=TigerVNC (simple) for $CURRENT_USER on display :%i
After=network.target syslog.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$USER_HOME
Environment=HOME=$USER_HOME USER=$CURRENT_USER LOGNAME=$CURRENT_USER
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1 || true
ExecStart=/usr/bin/vncserver -fg -localhost no -depth ${VNC_DEPTH:-24} -geometry ${VNC_GEOMETRY:-1920x1080} :%i
ExecStop=/usr/bin/vncserver -kill :%i
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
	sudo systemctl daemon-reload
	sudo systemctl restart vncserver@1.service || true
fi

STATUS="failed"
if systemctl is-active --quiet vncserver@1.service; then STATUS="running"; fi

echo "📊 Final status: $STATUS"
if [[ "$STATUS" != "running" ]]; then
	echo "📋 systemd status:"; sudo systemctl status vncserver@1.service --no-pager -l || true
	LOGFILE="$USER_HOME/.vnc/$(hostname):1.log"
	[[ -f "$LOGFILE" ]] && { echo "📄 Last 40 log lines:"; tail -n 40 "$LOGFILE"; } || echo "(Log file not yet created)"
	echo "Common causes:"
	echo "  • Missing desktop environment (install ubuntu-desktop or xfce4)"
	echo "  • Wrong ownership of $USER_HOME"
	echo "  • Stale lock files in ~/.vnc (remove and retry)"
	exit 1
fi

IP_DISPLAY=${STATIC_IP_CIDR:-}
if [[ -n "$IP_DISPLAY" ]]; then IP_DISPLAY=${IP_DISPLAY%%/*}; else IP_DISPLAY=$(hostname -I | awk '{print $1}'); fi

echo
echo "🌐 VNC up on ${IP_DISPLAY}:5901 (display :1)"
echo "🔐 Password stored in ~/.vnc/passwd"
echo "🔎 Logs: tail -f ~/.vnc/$(hostname):1.log"
echo "Restart: sudo systemctl restart vncserver@1.service"
echo "Stop:    sudo systemctl stop vncserver@1.service"
echo
echo "⚠️  Consider tunneling for security: ssh -L 5901:localhost:5901 $CURRENT_USER@${IP_DISPLAY}"
echo "✅ Done"