#!/usr/bin/env bash
set -euo pipefail

# Load config
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Check if config.env exists
if [[ ! -f "${SCRIPT_DIR}/../config.env" ]]; then
  echo "ERROR: config.env not found in $(dirname "${SCRIPT_DIR}")" >&2
  echo "Please create config.env file before running scripts" >&2
  exit 1
fi

# Source config file with error handling
if ! source "${SCRIPT_DIR}/../config.env"; then
  echo "ERROR: Failed to load config.env. Check for syntax errors." >&2
  exit 1
fi

# Logging functions
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }
log_success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*"; }
log_warning() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*" >&2; }

# Helper funcs with error handling
aptq() { 
  if ! DEBIAN_FRONTEND=noninteractive apt-get -yq "$@"; then
    log_error "apt-get failed: $*"
    return 1
  fi
}

msg() { 
  echo
  log "$*"
  echo
}

need_root() {
  if [[ ${EUID} -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Usage: sudo $0" >&2
    exit 1
  fi
}

# Figure out target user (the non-root user invoking sudo)
get_target_user() {
  local u="${SUDO_USER:-}"
  if [[ -z "${u}" || "${u}" == "root" ]]; then
    # best-effort: first real user with uid >= 1000
    u="$(awk -F: '$3>=1000 && $1!="nobody"{print $1; exit}' /etc/passwd 2>/dev/null || true)"
  fi
  
  if [[ -z "${u}" ]]; then
    log_error "Could not determine target user"
    log_error "Please run as: sudo -u <username> $0"
    exit 1
  fi
  
  echo "${u}"
}

# Validate user exists and get info
validate_target_user() {
  local user="$1"
  
  if ! id "${user}" >/dev/null 2>&1; then
    log_error "User '${user}' does not exist"
    exit 1
  fi
  
  # Check if user has a valid home directory
  local user_home
  user_home="$(eval echo "~${user}" 2>/dev/null)" || {
    log_error "Could not determine home directory for user '${user}'"
    exit 1
  }
  
  if [[ ! -d "${user_home}" ]]; then
    log_error "Home directory '${user_home}' does not exist for user '${user}'"
    exit 1
  fi
}

TARGET_USER="$(get_target_user)"
validate_target_user "${TARGET_USER}"
TARGET_HOME="$(eval echo "~${TARGET_USER}")"
TARGET_UID="$(id -u "${TARGET_USER}")"
TARGET_GID="$(id -g "${TARGET_USER}")"

log "Target user: ${TARGET_USER} (${TARGET_UID}:${TARGET_GID})"
log "Target home: ${TARGET_HOME}"

default_iface() {
  local iface
  iface="$(ip route | awk '/default/ {print $5; exit}' 2>/dev/null)" || {
    log_error "Could not determine default network interface"
    return 1
  }
  
  if [[ -z "${iface}" ]]; then
    log_error "No default route found"
    return 1
  fi
  
  echo "${iface}"
}

NET_IFACE="${NET_IFACE:-}"
if [[ -z "${NET_IFACE}" || "${NET_IFACE}" == '""' ]]; then
  if ! NET_IFACE="$(default_iface)"; then
    log_error "Could not auto-detect network interface"
    log_error "Please set NET_IFACE in config.env"
    exit 1
  fi
fi

# Validate network interface exists
if [[ -n "${NET_IFACE}" ]] && ! ip link show "${NET_IFACE}" >/dev/null 2>&1; then
  log_error "Network interface '${NET_IFACE}' does not exist"
  log "Available interfaces:"
  ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | tr -d ' ' | head -5
  exit 1
fi

log "Network interface: ${NET_IFACE}"

# Validation functions
validate_cidr() {
  local cidr="$1"
  if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    return 1
  fi
  
  # Validate IP octets and subnet mask
  local ip="${cidr%/*}"
  local mask="${cidr#*/}"
  
  IFS='.' read -ra octets <<< "$ip"
  for octet in "${octets[@]}"; do
    if [[ $octet -gt 255 ]]; then
      return 1
    fi
  done
  
  if [[ $mask -gt 32 ]]; then
    return 1
  fi
  
  return 0
}

validate_port() {
  local port="$1"
  if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
    return 1
  fi
  return 0
}
