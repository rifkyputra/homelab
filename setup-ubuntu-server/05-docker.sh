#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

# Error handling
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Docker installation failed"
    log "You may need to clean up: rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg"
  fi
  exit $exit_code
}
trap cleanup EXIT

msg "Install Docker (official repo) + compose plugin"

# Check if Docker is already installed
if command -v docker >/dev/null 2>&1; then
  log "Docker is already installed, checking version..."
  docker --version
  if docker compose version >/dev/null 2>&1; then
    log "Docker Compose plugin is already installed"
    log_success "Docker setup already completed"
    exit 0
  fi
fi

# Create keyrings directory
log "Setting up Docker repository..."
if ! install -m 0755 -d /etc/apt/keyrings; then
  log_error "Failed to create keyrings directory"
  exit 1
fi

# Download Docker GPG key
log "Downloading Docker GPG key..."
if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
  log_error "Failed to download Docker GPG key"
  exit 1
fi

if ! chmod a+r /etc/apt/keyrings/docker.gpg; then
  log_error "Failed to set permissions on Docker GPG key"
  exit 1
fi

# Get system information
ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release; echo "$VERSION_CODENAME")"

if [[ -z "${ARCH}" || -z "${CODENAME}" ]]; then
  log_error "Could not determine system architecture or codename"
  exit 1
fi

log "System: ${CODENAME} (${ARCH})"

# Add Docker repository
log "Adding Docker repository..."
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

# Update package lists
log "Updating package lists..."
if ! aptq update; then
  log_error "Failed to update package lists after adding Docker repository"
  exit 1
fi

# Install Docker packages
log "Installing Docker packages..."
DOCKER_PACKAGES=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
)

for package in "${DOCKER_PACKAGES[@]}"; do
  if ! aptq install "$package"; then
    log_error "Failed to install $package"
    exit 1
  fi
done

# Add user to docker group
log "Adding ${TARGET_USER} to docker group..."
if ! usermod -aG docker "${TARGET_USER}"; then
  log_error "Failed to add ${TARGET_USER} to docker group"
  exit 1
fi

# Enable and start Docker service
log "Enabling Docker service..."
if ! systemctl enable --now docker; then
  log_error "Failed to enable Docker service"
  exit 1
fi

# Verify Docker installation
log "Verifying Docker installation..."
if ! systemctl is-active --quiet docker; then
  log_error "Docker service is not running"
  exit 1
fi

# Test Docker
if ! docker run --rm hello-world >/dev/null 2>&1; then
  log_warning "Docker test failed, but installation appears successful"
else
  log "Docker test successful"
fi

# Show versions
docker --version
docker compose version

log_success "Docker installation completed successfully"
log "Note: ${TARGET_USER} needs to log out and back in (or run 'newgrp docker') to use Docker"
