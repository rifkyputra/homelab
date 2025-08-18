#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

# NOTE: This script runs LAST to ensure all services are installed first
# This prevents issues where services might not start properly due to firewall restrictions
# All ports defined in OPEN_PORTS will be opened for the networks in ALLOWED_CIDRS

# Error handling
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Firewall configuration failed"
    log "You may need to reset UFW manually: ufw --force reset"
  fi
  exit $exit_code
}
trap cleanup EXIT

msg "Configure UFW firewall (LAN-only for selected ports)"

# Skip full reset if desired rules unchanged (idempotency optimization)
STATE_DIR=/var/lib/homelab
install -d -m 0755 "$STATE_DIR" || true
RULE_SIG_FILE="$STATE_DIR/ufw_rules.sha256"
CURRENT_SIG=$(printf '%s\n%s' "${ALLOWED_CIDRS}" "${OPEN_PORTS}" | sha256sum | awk '{print $1}')
if [[ -f "$RULE_SIG_FILE" ]]; then
  PREV_SIG=$(cat "$RULE_SIG_FILE" 2>/dev/null || true)
  if [[ "$PREV_SIG" == "$CURRENT_SIG" ]]; then
    log "Firewall rule inputs unchanged; skipping reconfigure"
    ufw status verbose || true
    exit 0
  else
    log "Rule signature changed; re-applying firewall configuration"
  fi
fi

# Validate ALLOWED_CIDRS and OPEN_PORTS
if [[ -z "${ALLOWED_CIDRS}" ]]; then
  log_error "ALLOWED_CIDRS is empty in config.env"
  exit 1
fi

if [[ -z "${OPEN_PORTS}" ]]; then
  log_error "OPEN_PORTS is empty in config.env"
  exit 1
fi

# Validate CIDRs
log "Validating CIDR blocks..."
for CIDR in ${ALLOWED_CIDRS}; do
  if ! validate_cidr "$CIDR"; then
    log_error "Invalid CIDR block: '$CIDR'"
    exit 1
  fi
done

# Validate ports
log "Validating port numbers..."
for P in ${OPEN_PORTS}; do
  if ! validate_port "$P"; then
    log_error "Invalid port number: '$P'"
    exit 1
  fi
done

# Reset firewall
log "Resetting UFW configuration..."
if ! ufw --force reset; then
  log_error "Failed to reset UFW"
  exit 1
fi

# Set default policies
log "Setting default policies..."
ufw default deny incoming || exit 1
ufw default allow outgoing || exit 1

# Add rules
log "Adding firewall rules..."
RULES_ADDED=0
for CIDR in ${ALLOWED_CIDRS}; do
  for P in ${OPEN_PORTS}; do
    if ufw allow from "$CIDR" to any port "$P" comment "Allow ${P} from ${CIDR}"; then
      log "Added rule: Allow ${P} from ${CIDR}"
      ((RULES_ADDED++))
    else
      log_warning "Failed to add rule for port ${P} from ${CIDR}"
    fi
  done
done

if [[ $RULES_ADDED -eq 0 ]]; then
  log_error "No firewall rules were added successfully"
  exit 1
fi

# Enable firewall
log "Enabling UFW firewall..."
if ! ufw --force enable; then
  log_error "Failed to enable UFW"
  exit 1
fi

# Show status
log "UFW firewall configuration:"
ufw status verbose

log_success "Firewall configured successfully with ${RULES_ADDED} rules"
echo "$CURRENT_SIG" > "$RULE_SIG_FILE" || true
