#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

# Error handling
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Basic system setup failed"
  fi
  exit $exit_code
}
trap cleanup EXIT

msg "System update & basic tools + SSH"

# Update package lists
log "Updating package lists..."
if ! aptq update; then
  log_error "Failed to update package lists"
  exit 1
fi

# Upgrade system
log "Upgrading system packages..."
if ! aptq upgrade; then
  log_error "Failed to upgrade system packages"
  exit 1
fi

# Install basic packages
log "Installing basic tools..."
PACKAGES=(
  curl wget git unzip ca-certificates gnupg lsb-release software-properties-common
  build-essential net-tools dnsutils traceroute nmap iperf3
  htop btop neofetch tmux ufw openssh-server jq
)

for package in "${PACKAGES[@]}"; do
  if ! aptq install "$package"; then
    log_warning "Failed to install $package, continuing..."
  fi
done

# Enable SSH service
log "Enabling SSH service..."
if ! systemctl enable --now ssh; then
  log_error "Failed to enable SSH service"
  exit 1
fi

log_success "Basic system setup completed"
