# Homelab Setup — Modular Scripts

Opinionated, modular scripts to turn a fresh Ubuntu 24 server into a LAN-only homelab you can reach from macOS/Windows.
Features: SSH, UFW, Fail2ban, Nginx reverse proxy, Docker (official repo) + Compose, Cockpit, KVM/Libvirt, XRDP (RDP), TigerVNC (VNC), Netdata, and a Docker stack with Portainer, code-server, and Grafana.
Your desktop environment is assumed to be already installed (no desktop is installed here).

---

## What You Get

* Secure remote access

  * SSH, UFW (LAN-only rules), Fail2ban
  * XRDP (RDP protocol) and TigerVNC (VNC protocol)
* Web management & reverse proxy

  * Cockpit (https\://SERVER\_IP:9090)
  * Nginx with paths:

    * `http://SERVER_IP/portainer` → Portainer
    * `http://SERVER_IP/code` → code-server
    * `http://SERVER_IP/grafana` → Grafana
* Containers & virtualization

  * Docker CE + Buildx + Compose plugin
  * KVM/QEMU/Libvirt + virt-manager
* Monitoring

  * Netdata (`http://SERVER_IP:19999`) and Glances (CLI)
* Networking

  * Optional static IP via Netplan (defaults to 192.168.1.10/24)

---

## Folder Layout

Create this folder on the server (e.g., `/opt/homelab-scripts`) and place the files inside:

```
homelab-scripts/
├─ 00-run-all.sh
├─ 01-basics-and-ssh.sh
├─ 02-firewall-ufw.sh
├─ 03-fail2ban.sh
├─ 04-nginx-certbot.sh
├─ 05-docker.sh
├─ 06-virtualization.sh
├─ 07-cockpit.sh
├─ 08-remote-desktop.sh
├─ 09-monitoring.sh
├─ 10-netplan-static-ip.sh
├─ 11-apps-compose.sh
├─ config.env
└─ lib/
   └─ common.sh
```

---

## Quick Start

```bash
# on Ubuntu 24 server
sudo mkdir -p /opt/homelab-scripts
cd /opt/homelab-scripts

# paste all files above into this folder…

# make executable
sudo chmod +x *.sh lib/common.sh

# tweak config if needed (defaults are sane)
sudo nano config.env

# run everything
sudo ./00-run-all.sh
```

After it finishes:

* Set a VNC password and start VNC:

  ```bash
  sudo -u <your-username> vncpasswd
  sudo systemctl start vncserver@1
  ```
* Re-login (or `newgrp docker`) so Docker group applies.
* Visit:

  * Portainer:  `http://SERVER_IP/portainer`  (or `:9000`)
  * code-server: `http://SERVER_IP/code` (or `:8080`) — password in `/opt/homelab/.env`
  * Grafana:    `http://SERVER_IP/grafana` (or `:3000`) — admin creds in `/opt/homelab/.env`
  * Cockpit:    `https://SERVER_IP:9090` (self-signed)
  * Netdata:    `http://SERVER_IP:19999`
* RDP: connect to `SERVER_IP:3389` (use your OS login).
* SSH: `ssh youruser@SERVER_IP`

---

## Configuration

All knobs live in `config.env`:

```ini
# Static IP (Netplan)
STATIC_IP_ENABLED=true
NET_IFACE=""                 # empty = auto-detect default route interface
STATIC_IP_CIDR="192.168.1.10/24"
GATEWAY_IP="192.168.1.1"
DNS_SERVERS="1.1.1.1,8.8.8.8"

# Domain (optional; leave empty to skip certbot)
DOMAIN_NAME=""
ADMIN_EMAIL=""

# Remote desktop
VNC_GEOMETRY="1920x1080"
VNC_DEPTH="24"

# UFW allow-list (space-separated CIDRs)
ALLOWED_CIDRS="192.168.0.0/16 10.0.0.0/8 172.16.0.0/12"

# Ports opened to ALLOWED_CIDRS
OPEN_PORTS="22 80 443 9090 3389 5901 19999 9000 9443 3000 8080"

# Docker apps
GRAFANA_ADMIN_USER="admin"
```

> Tip: If your NIC name isn’t auto-detected, set `NET_IFACE` explicitly (e.g., `enp0s3`, `ens18`).

---

## What Each Script Does

* **`01-basics-and-ssh.sh`** — apt update/upgrade; installs tools, SSH, tmux, etc.
* **`02-firewall-ufw.sh`** — LAN-only firewall rules based on `ALLOWED_CIDRS` and `OPEN_PORTS`.
* **`03-fail2ban.sh`** — SSH jail to block brute-force attempts.
* **`04-nginx-certbot.sh`** — Nginx site + reverse proxy to Portainer/code-server/Grafana. Installs certbot; issues TLS only if `DOMAIN_NAME` is set and reachable.
* **`05-docker.sh`** — Docker CE (official repo) + Buildx + Compose plugin; add your user to `docker` group.
* **`06-virtualization.sh`** — KVM/QEMU/Libvirt, virt-manager, OVMF; enables `libvirtd`; adds user to `kvm` & `libvirt`.
* **`07-cockpit.sh`** — Cockpit core + machines plugin; activates socket (`:9090`).
* **`08-remote-desktop.sh`** — XRDP and TigerVNC; creates `~/.vnc/xstartup`; systemd `vncserver@.service` (display `:1` on port 5901).
* **`09-monitoring.sh`** — Netdata (service) + Glances (CLI).
* **`10-netplan-static-ip.sh`** — Writes `/etc/netplan/01-homelab.yaml` and applies it if `STATIC_IP_ENABLED=true`.
* **`11-apps-compose.sh`** — Creates `/opt/homelab` compose stack (Portainer, code-server, Grafana) + systemd unit `homelab-compose.service`. Generates `/opt/homelab/.env` with secrets on first run.
* **`00-run-all.sh`** — Runs all scripts in sequence (safe to re-run; idempotent where possible).

---

## Default Endpoints (HTTP over LAN)

* `http://192.168.1.10/portainer`  or `http://192.168.1.10:9000`
* `http://192.168.1.10/code`       or `http://192.168.1.10:8080`
* `http://192.168.1.10/grafana`    or `http://192.168.1.10:3000`
* `https://192.168.1.10:9090` (Cockpit; self-signed)
* `http://192.168.1.10:19999` (Netdata)
* RDP: `192.168.1.10:3389`
* VNC: `192.168.1.10:5901`

> Replace with your actual server IP if different. TLS is added later when you point a domain and re-run certbot.

---

## Credentials & Secrets

* **code-server**: password is stored in `/opt/homelab/.env` as `CODE_SERVER_PASSWORD`.
* **Grafana**: admin user/password in `/opt/homelab/.env` (`GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`).
* **Portainer**: set on first visit to `/portainer`.
* **VNC**: set with `sudo -u <user> vncpasswd`.

To restart the app stack after editing secrets:

```bash
sudo systemctl restart homelab-compose
```

---

## Security Notes

* UFW allows access only from private LAN ranges defined in `ALLOWED_CIDRS`. Tighten as needed.
* Consider disabling SSH password auth after confirming key-based login:

  ```bash
  ssh-copy-id youruser@SERVER_IP
  sudoedit /etc/ssh/sshd_config   # PasswordAuthentication no
  sudo systemctl reload ssh
  ```
* If/when you expose services from the internet, put them behind HTTPS, auth, and ideally a VPN or ZTNA.

---

## Troubleshooting

* **VNC won’t start**
  Make sure you’ve set a password:

  ```bash
  sudo -u <user> vncpasswd
  sudo systemctl start vncserver@1
  journalctl -u vncserver@1 -e
  ```

* **RDP login fails on GNOME/Wayland**
  Switch the login session to “Ubuntu on Xorg” (or install a lighter DE like XFCE) for XRDP compatibility.

* **Nginx 502/404 for subpaths**
  Ensure the containers are running:

  ```bash
  docker ps
  sudo systemctl status homelab-compose
  sudo nginx -t && sudo systemctl reload nginx
  ```

* **Docker permissions**
  Re-login or:

  ```bash
  newgrp docker
  ```

* **Static IP issues**
  Verify NIC name and Netplan file:

  ```bash
  ip a
  cat /etc/netplan/01-homelab.yaml
  sudo netplan apply
  ```

---

## Manage Services

```bash
# Compose stack (Portainer, code-server, Grafana)
sudo systemctl {start|stop|restart|status} homelab-compose

# Cockpit
sudo systemctl {start|stop|status} cockpit.socket

# Netdata
sudo systemctl {start|stop|restart|status} netdata

# XRDP
sudo systemctl {start|stop|restart|status} xrdp

# VNC
sudo systemctl {start|stop|restart|status} vncserver@1

# Libvirt
sudo systemctl {start|stop|restart|status} libvirtd

# Nginx
sudo systemctl {start|stop|restart|status} nginx
```

---

## Customize / Extend

* Add more apps to `/opt/homelab/docker-compose.yml` (e.g., Prometheus + Node Exporter), then:

  ```bash
  sudo systemctl restart homelab-compose
  ```
* Change reverse-proxy paths in `/etc/nginx/sites-available/homelab`, test and reload:

  ```bash
  sudo nginx -t && sudo systemctl reload nginx
  ```

---

## Add a Domain + HTTPS Later

1. Point an A record of your domain to your public IP (port-forward 80/443 to the server).
2. Update `config.env`:

```ini
DOMAIN_NAME="your.domain.tld"
ADMIN_EMAIL="you@example.com"
```

3. Re-run only the Nginx/Certbot step:

```bash
sudo ./04-nginx-certbot.sh
```

---

## Uninstall / Cleanup (optional)

```bash
# Stop app stack and remove volumes (DANGER: deletes Grafana/Portainer/code data)
sudo systemctl stop homelab-compose
sudo docker compose -f /opt/homelab/docker-compose.yml down -v

# Remove Netplan file if you want to go back to DHCP
sudo rm -f /etc/netplan/01-homelab.yaml
sudo netplan apply
```

---

## License

MIT (or your choice).
