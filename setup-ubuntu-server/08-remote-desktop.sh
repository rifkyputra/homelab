#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "Install XRDP (RDP) and TigerVNC (VNC)"
aptq install xrdp
adduser xrdp ssl-cert || true
systemctl enable --now xrdp

aptq install tigervnc-standalone-server
su - "${TARGET_USER}" -c "mkdir -p ~/.vnc && cat > ~/.vnc/xstartup <<'EOS'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
if command -v x-session-manager >/dev/null 2>&1; then
  exec x-session-manager
elif command -v gnome-session >/dev/null 2>&1; then
  exec gnome-session
else
  exec /etc/X11/Xsession
fi
EOS
chmod +x ~/.vnc/xstartup"

cat >/etc/systemd/system/vncserver@.service <<EOF
[Unit]
Description=TigerVNC server on display %i
After=network.target

[Service]
Type=forking
User=${TARGET_USER}
PAMName=login
PIDFile=${TARGET_HOME}/.vnc/%H:%i.pid
ExecStartPre=/usr/bin/bash -lc 'test -f ${TARGET_HOME}/.vnc/passwd || (echo "Run: sudo -u ${TARGET_USER} vncpasswd"; exit 1)'
ExecStart=/usr/bin/vncserver -localhost no -geometry ${VNC_GEOMETRY} -depth ${VNC_DEPTH} :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vncserver@1
echo "NOTE: Set a VNC password: sudo -u ${TARGET_USER} vncpasswd ; then: sudo systemctl start vncserver@1"
