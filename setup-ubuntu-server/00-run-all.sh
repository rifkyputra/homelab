#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }
log_success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*"; }

# Error handling
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Script failed with exit code $exit_code"
    log_error "Check the logs above for details"
  fi
  exit $exit_code
}
trap cleanup EXIT

# Ensure we run as root
if [[ ${EUID} -ne 0 ]]; then
  log_error "This script must be run as root"
  echo "Usage: sudo $0"
  exit 1
fi

# Check if config.env exists
if [[ ! -f "${BASE_DIR}/config.env" ]]; then
  log_error "config.env file not found in ${BASE_DIR}"
  log_error "Please create config.env file before running this script"
  exit 1
fi

# Execution order
SCRIPTS=(
  "01-basics-and-ssh.sh"
  "02-firewall-ufw.sh"
  "03-fail2ban.sh"
  "04-nginx-certbot.sh"
  "05-docker.sh"
  "06-virtualization.sh"
  "07-cockpit.sh"
  "08-remote-desktop.sh"
  "09-monitoring.sh"
  "10-netplan-static-ip.sh"
  "11-apps-compose.sh"
)

# Verify all scripts exist before execution
log "Verifying all scripts exist..."
for s in "${SCRIPTS[@]}"; do
  if [[ ! -f "${BASE_DIR}/${s}" ]]; then
    log_error "Script not found: ${BASE_DIR}/${s}"
    exit 1
  fi
  if [[ ! -x "${BASE_DIR}/${s}" ]]; then
    log_error "Script not executable: ${BASE_DIR}/${s}"
    log "Making script executable..."
    chmod +x "${BASE_DIR}/${s}"
  fi
done

# Execute scripts
log "Starting homelab setup..."
FAILED_SCRIPTS=()

for s in "${SCRIPTS[@]}"; do
  log "Running ${s}..."
  if bash "${BASE_DIR}/${s}"; then
    log_success "Completed ${s}"
  else
    log_error "Failed to execute ${s}"
    FAILED_SCRIPTS+=("$s")
    # Continue with other scripts unless it's a critical failure
    if [[ "$s" =~ ^(01-basics|02-firewall|05-docker) ]]; then
      log_error "Critical script failed. Stopping execution."
      exit 1
    fi
  fi
done

# Report results
if [[ ${#FAILED_SCRIPTS[@]} -eq 0 ]]; then
  log_success "All scripts completed successfully ✅"
else
  log_error "The following scripts failed: ${FAILED_SCRIPTS[*]}"
  log "You may need to run these manually or check their logs"
fi

echo
log_success "Homelab setup completed!"
echo "Next steps:"
echo "- If you enabled static IP, verify with: ip a show"
echo "- Set VNC password: sudo -u \$(awk -F: '\$3>=1000 && \$1!=\"nobody\"{print \$1; exit}' /etc/passwd) vncpasswd"
echo "- Re-login (or: newgrp docker) so your user gets Docker group"
echo "- Access services:"
echo "  * Cockpit: https://<SERVER_IP>:9090"
echo "  * Netdata: http://<SERVER_IP>:19999"
echo "  * Portainer: http://<SERVER_IP>/portainer"
echo "  * Code-server: http://<SERVER_IP>/code"
echo "  * Grafana: http://<SERVER_IP>/grafana"
