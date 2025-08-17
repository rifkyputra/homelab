#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

# Error handling
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Network configuration failed"
    log "You may need to remove /etc/netplan/01-homelab.yaml and run 'netplan apply'"
  fi
  exit $exit_code
}
trap cleanup EXIT

if [[ "${STATIC_IP_ENABLED}" != "true" ]]; then
  msg "Static IP disabled in config; skipping Netplan."
  exit 0
fi

# Validate required variables
if [[ -z "${NET_IFACE}" ]]; then
  log_error "Could not detect NET_IFACE automatically; set it in config.env"
  exit 1
fi

if [[ -z "${STATIC_IP_CIDR}" ]]; then
  log_error "STATIC_IP_CIDR is not set in config.env"
  exit 1
fi

if [[ -z "${GATEWAY_IP}" ]]; then
  log_error "GATEWAY_IP is not set in config.env"
  exit 1
fi

if [[ -z "${DNS_SERVERS}" ]]; then
  log_error "DNS_SERVERS is not set in config.env"
  exit 1
fi

# Validate CIDR format
if ! validate_cidr "${STATIC_IP_CIDR}"; then
  log_error "Invalid STATIC_IP_CIDR format: ${STATIC_IP_CIDR}"
  exit 1
fi

# Validate gateway IP format
if [[ ! "${GATEWAY_IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  log_error "Invalid GATEWAY_IP format: ${GATEWAY_IP}"
  exit 1
fi

msg "Apply Netplan static IP for ${NET_IFACE} -> ${STATIC_IP_CIDR}"

# Parse DNS servers
IFS=',' read -r -a DNS_ARR <<< "${DNS_SERVERS}"
if [[ ${#DNS_ARR[@]} -eq 0 ]]; then
  log_error "No DNS servers specified"
  exit 1
fi

# Validate DNS servers
for dns in "${DNS_ARR[@]}"; do
  dns=$(echo "$dns" | tr -d ' ')  # Remove whitespace
  if [[ ! "$dns" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_error "Invalid DNS server format: $dns"
    exit 1
  fi
done

# Build DNS YAML
DNS_YAML=""
for d in "${DNS_ARR[@]}"; do 
  d=$(echo "$d" | tr -d ' ')  # Remove whitespace
  DNS_YAML="${DNS_YAML}      - ${d}\n"
done

# Backup existing netplan configs
BACKUP_DIR="/etc/netplan/backup-$(date +%Y%m%d-%H%M%S)"
if ls /etc/netplan/*.yaml >/dev/null 2>&1; then
  log "Backing up existing Netplan configs to ${BACKUP_DIR}"
  mkdir -p "${BACKUP_DIR}"
  cp /etc/netplan/*.yaml "${BACKUP_DIR}/" 2>/dev/null || true
fi

# Create Netplan configuration
NETPLAN_FILE="/etc/netplan/01-homelab.yaml"
log "Creating Netplan configuration: ${NETPLAN_FILE}"

cat >"${NETPLAN_FILE}" <<EOF
network:
  version: 2
  ethernets:
    ${NET_IFACE}:
      dhcp4: no
      addresses: [${STATIC_IP_CIDR}]
      routes:
        - to: default
          via: ${GATEWAY_IP}
      nameservers:
        addresses:
$(echo -e "${DNS_YAML}")
EOF

# Validate Netplan configuration
log "Validating Netplan configuration..."
if ! netplan generate; then
  log_error "Netplan configuration validation failed"
  rm -f "${NETPLAN_FILE}"
  exit 1
fi

# Apply Netplan configuration
log "Applying Netplan configuration..."
if ! netplan apply; then
  log_error "Failed to apply Netplan configuration"
  log "Rolling back changes..."
  rm -f "${NETPLAN_FILE}"
  netplan apply || true
  exit 1
fi

# Verify the configuration worked
sleep 3
CURRENT_IP=$(ip addr show "${NET_IFACE}" | grep -oP 'inet \K[0-9.]+/[0-9]+' | head -1 || true)

if [[ "${CURRENT_IP}" == "${STATIC_IP_CIDR}" ]]; then
  log_success "Static IP configured successfully: ${CURRENT_IP}"
else
  log_warning "Static IP may not have applied correctly"
  log "Expected: ${STATIC_IP_CIDR}"
  log "Current: ${CURRENT_IP}"
fi

# Show current network configuration
log "Current network configuration:"
ip addr show "${NET_IFACE}"
