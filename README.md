# Self-Hosted PostgreSQL Homelab

A complete homelab setup.

## 🏗️ Project Structure

This repository contains two main components:

### 📊 `selfhost-pg/` - Production PostgreSQL Stack
A comprehensive PostgreSQL deployment with enterprise-grade security, automated backups, monitoring, and administration tools.

**Features:**
- **Enterprise Security**: SCRAM-SHA-256 encryption, SSL/TLS, network isolation
- **High Availability**: Health checks, automatic restarts, connection pooling ready
- **Automated Backups**: Daily backups with 30-day retention, WAL archiving, cloud integration
- **Real-time Monitoring**: Performance metrics, security audits, resource tracking
- **pgAdmin Web Interface**: Full database administration via web browser
- **Production Operations**: 30+ Makefile commands, cron jobs, log rotation

### 🖥️ `setup-ubuntu-server/` - Automated Server Configuration
Modular scripts to transform a fresh Ubuntu 24 server into a secure, fully-featured homelab environment.

**Features:**
- **Security Hardening**: SSH, UFW firewall, Fail2ban intrusion prevention
- **Web Services**: Nginx reverse proxy, Cockpit web management
- **Containerization**: Docker CE + Compose, Portainer container management
- **Remote Access**: RDP (XRDP), VNC (TigerVNC), code-server web IDE
- **Virtualization**: KVM/QEMU/Libvirt with virt-manager
- **Monitoring**: Netdata, Grafana, Glances system monitoring
- **Networking**: Static IP configuration, LAN-only security model

## 🚀 Quick Start

```bash
# 1. First, set up your Ubuntu server
cd setup-ubuntu-server/
sudo chmod +x *.sh lib/common.sh
sudo ./00-run-all.sh

# 2. Then deploy PostgreSQL
cd ../selfhost-pg/
docker compose up -d
```

### 🔥 Firewall (UFW) Management (Database Access)

The stack ships with a firewall helper (`selfhost-pg/scripts/firewall.sh`) and Makefile targets to control who can reach PostgreSQL (5432) and pgAdmin.

Common operations (run inside `selfhost-pg/`):

```bash
make firewall-status          # Show current rules for DB ports
make firewall-local           # Restrict access to localhost only
make firewall-open-all        # Allow access from anywhere (NOT recommended)
make firewall-allow IPS="1.2.3.4 5.6.7.8"   # Allow only specific IPs
make firewall-close           # Remove rules (falls back to default UFW policy)
```

Dry run (preview commands without applying):

```bash
DRY_RUN=1 ./scripts/firewall.sh allow --ips "203.0.113.5 198.51.100.7"
```

Rules are tagged with `selfhost-pg` for easy cleanup.


## 🛡️ Security Features

### PostgreSQL Security
- **SCRAM-SHA-256** password authentication
- **SSL/TLS encryption** for all connections
- **Network isolation** (localhost binding)
- **Row-level security** policies
- **Comprehensive audit logging**
- **Regular security scanning**
- **Backup encryption** and verification

### Server Security  
- **UFW Firewall** with LAN-only rules
- **Fail2ban** intrusion prevention
- **SSH hardening** with key-based auth
- **Automatic security updates**
- **Log monitoring** and rotation
- **Network segmentation**


## 📚 Documentation

- **[PostgreSQL Setup Guide](selfhost-pg/README.md)** - Database deployment
- **[Production Guide](selfhost-pg/PRODUCTION_GUIDE.md)** - Enterprise deployment
- **[Server Setup Guide](setup-ubuntu-server/README.md)** - Complete server configuration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🆘 Support

- **Issues**: Report bugs or request features via [GitHub Issues]
- **Documentation**: Check the individual README files in each directory
- **Security**: For security concerns, please create a private issue

---

## Built with ❤️ for the self-hosting community
