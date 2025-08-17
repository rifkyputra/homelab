#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

# Error handling
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Docker Compose apps deployment failed"
    log "You may need to clean up: docker compose -f /opt/homelab/docker-compose.yml down"
  fi
  exit $exit_code
}
trap cleanup EXIT

msg "Deploy Portainer, code-server, Grafana via Docker Compose"

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
  log_error "Docker is not installed or not in PATH"
  exit 1
fi

# Check if Docker Compose is available
if ! docker compose version >/dev/null 2>&1; then
  log_error "Docker Compose plugin is not available"
  exit 1
fi

# Check if Docker service is running
if ! systemctl is-active --quiet docker; then
  log_error "Docker service is not running"
  exit 1
fi

# Create homelab directory
HOMELAB_DIR="/opt/homelab"
log "Creating homelab directory: ${HOMELAB_DIR}"
if ! install -d -m 0755 "${HOMELAB_DIR}"; then
  log_error "Failed to create ${HOMELAB_DIR}"
  exit 1
fi

# Create or keep .env with generated secrets
ENV_FILE="${HOMELAB_DIR}/.env"
log "Managing environment file: ${ENV_FILE}"

if [[ ! -f "${ENV_FILE}" ]]; then
  log "Generating new environment file with secrets..."
  CODE_SERVER_PASSWORD="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20 2>/dev/null || openssl rand -base64 20 | tr -d '=+/' | cut -c1-20)"
  GRAFANA_ADMIN_PASSWORD="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20 2>/dev/null || openssl rand -base64 20 | tr -d '=+/' | cut -c1-20)"
  
  if [[ -z "${CODE_SERVER_PASSWORD}" || -z "${GRAFANA_ADMIN_PASSWORD}" ]]; then
    log_error "Failed to generate random passwords"
    exit 1
  fi
  
  cat >"${ENV_FILE}" <<EOF
CODE_SERVER_PASSWORD=${CODE_SERVER_PASSWORD}
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
EOF
  
  chmod 600 "${ENV_FILE}"
  log "Environment file created with generated passwords"
else
  log "Using existing environment file"
fi

# Ensure env has required variables
log "Validating environment variables..."
REQUIRED_ENV_VARS=("GRAFANA_ADMIN_USER" "GRAFANA_ADMIN_PASSWORD" "CODE_SERVER_PASSWORD")

for var in "${REQUIRED_ENV_VARS[@]}"; do
  if ! grep -q "^${var}=" "${ENV_FILE}"; then
    case "$var" in
      "GRAFANA_ADMIN_USER")
        echo "${var}=${GRAFANA_ADMIN_USER}" >> "${ENV_FILE}"
        ;;
      "GRAFANA_ADMIN_PASSWORD")
        echo "${var}=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)" >> "${ENV_FILE}"
        ;;
      "CODE_SERVER_PASSWORD")
        echo "${var}=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)" >> "${ENV_FILE}"
        ;;
    esac
    log "Added missing environment variable: ${var}"
  fi
done

# Compose file
COMPOSE_FILE="${HOMELAB_DIR}/docker-compose.yml"
log "Creating Docker Compose file: ${COMPOSE_FILE}"

cat >"${COMPOSE_FILE}" <<EOF
services:
  portainer:
    image: portainer/portainer-ce:latest
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  code:
    image: codercom/code-server:latest
    restart: unless-stopped
    environment:
      - PASSWORD=\${CODE_SERVER_PASSWORD}
      - DEFAULT_WORKSPACE=/home/coder/project
    user: "${TARGET_UID}:${TARGET_GID}"
    volumes:
      - code_data:/home/coder/project
    ports:
      - "8080:8080"
    command: ["--auth","password","--bind-addr","0.0.0.0:8080","--base-path","/code"]

  grafana:
    image: grafana/grafana-oss:latest
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=\${GRAFANA_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_ADMIN_PASSWORD}
      - GF_SERVER_ROOT_URL=/grafana
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  portainer_data:
  code_data:
  grafana_data:
EOF

# Validate compose file
log "Validating Docker Compose file..."
if ! docker compose -f "${COMPOSE_FILE}" config >/dev/null; then
  log_error "Docker Compose file validation failed"
  exit 1
fi

# systemd unit for compose stack
SYSTEMD_SERVICE="/etc/systemd/system/homelab-compose.service"
log "Creating systemd service: ${SYSTEMD_SERVICE}"

cat >"${SYSTEMD_SERVICE}" <<EOF
[Unit]
Description=Homelab Docker Compose stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=${HOMELAB_DIR}
RemainAfterExit=yes
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
log "Enabling homelab-compose service..."
if ! systemctl daemon-reload; then
  log_error "Failed to reload systemd daemon"
  exit 1
fi

if ! systemctl enable homelab-compose.service; then
  log_error "Failed to enable homelab-compose service"
  exit 1
fi

# Start the service
log "Starting homelab-compose service..."
if ! systemctl start homelab-compose.service; then
  log_error "Failed to start homelab-compose service"
  log "Check logs with: journalctl -u homelab-compose.service"
  exit 1
fi

# Verify services are running
log "Verifying services are running..."
sleep 10

RUNNING_CONTAINERS=$(docker compose -f "${COMPOSE_FILE}" ps --services --filter "status=running" | wc -l)
EXPECTED_CONTAINERS=3

if [[ $RUNNING_CONTAINERS -eq $EXPECTED_CONTAINERS ]]; then
  log_success "All ${EXPECTED_CONTAINERS} services are running successfully"
else
  log_warning "Only ${RUNNING_CONTAINERS}/${EXPECTED_CONTAINERS} services are running"
  docker compose -f "${COMPOSE_FILE}" ps
fi

echo
log_success "Docker Compose stack deployment completed!"
echo "Stack URLs (HTTP over LAN):"
echo "  Portainer:   http://<SERVER_IP>/portainer   or :9000"
echo "  code-server: http://<SERVER_IP>/code        or :8080  (password in ${ENV_FILE})"
echo "  Grafana:     http://<SERVER_IP>/grafana     or :3000  (admin creds in ${ENV_FILE})"
echo
echo "Management commands:"
echo "  Status:  systemctl status homelab-compose"
echo "  Restart: systemctl restart homelab-compose"
echo "  Logs:    journalctl -u homelab-compose.service"
