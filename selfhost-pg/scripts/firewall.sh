#!/usr/bin/env bash
# Firewall management helper for selfhost-pg
# Allows toggling PostgreSQL / pgAdmin access via UFW
# Supports: allow-all, allow (restrict to IP list), close (remove rules), status

set -euo pipefail

POSTGRES_PORT=5432
PGADMIN_PORT=5050
COMMENT_TAG="selfhost-pg"

# Dry run: set DRY_RUN=1 to print commands without executing
DRY_RUN=${DRY_RUN:-0}

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "(dry-run) $*"
  else
    eval "$*"
  fi
}

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

info() { echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $*"; }
warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"; }
err() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2; }
header() { echo -e "${COLOR_BLUE}==== $* ====${COLOR_RESET}"; }

require_ufw() {
  if ! command -v ufw >/dev/null 2>&1; then
    err "ufw not installed. Install with: sudo apt install ufw"
    exit 1
  fi
}

usage() {
  cat <<EOF
Firewall management for selfhost-pg (UFW wrapper)

Usage: $0 <command> [options]

Commands:
  status                     Show current ufw rules for database ports
  allow-all                  Allow all IPv4/IPv6 sources to access ports ${POSTGRES_PORT}, ${PGADMIN_PORT}
  allow --ips "IP1 IP2"       Allow only the given space/comma separated IP addresses (replaces existing rules)
  allow IP1,IP2,IP3          Shorthand form without --ips
  allow-local                Allow ONLY localhost (127.0.0.1 and ::1 if IPv6 enabled)
  close                      Remove all selfhost-pg rules for these ports
  reload                     Reload ufw firewall
  help                       Show this help

Examples:
  $0 status
  $0 allow-all
  $0 allow --ips "10.0.0.5 203.0.113.7"
  $0 allow 10.0.0.5,203.0.113.7
  $0 close

Notes:
  - SSH (port 22) rules are untouched
  - Existing selfhost-pg rules for these ports are replaced on allow / allow-all
EOF
}

validate_ip() {
  local ip="$1"
  # Accept IPv4 simple regex
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    # Basic octet range check
    IFS='.' read -r o1 o2 o3 o4 <<<"$ip"
    for o in $o1 $o2 $o3 $o4; do
      if (( o < 0 || o > 255 )); then
        return 1
      fi
    done
    return 0
  fi
  # Accept CIDR form
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    IFS='/.' read -r o1 o2 o3 o4 mask <<<"${ip//\//.}"
    for o in $o1 $o2 $o3 $o4; do
      if (( o < 0 || o > 255 )); then
        return 1
      fi
    done
    if (( mask < 0 || mask > 32 )); then
      return 1
    fi
    return 0
  fi
  return 1
}

list_rule_numbers() {
  # Output ufw rule numbers (descending) for our tag + target ports
  sudo ufw status numbered | awk -v p1="$POSTGRES_PORT" -v p2="$PGADMIN_PORT" -v tag="$COMMENT_TAG" \
    'match($0, /\[( [0-9]+|[0-9]+)\]/) {num=$0; sub(/.*\[|\].*/, "", num)} /ALLOW/ && ($0 ~ p1 || $0 ~ p2) && $0 ~ tag {print num}' | sort -rn
}

remove_existing_rules() {
  local nums=( $(list_rule_numbers) )
  if ((${#nums[@]}==0)); then
    return 0
  fi
  warn "Removing existing selfhost-pg rules: ${nums[*]}"
  for n in "${nums[@]}"; do
    # Need yes to confirm deletion non-interactively
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "(dry-run) yes | sudo ufw delete $n"
    else
      yes | sudo ufw delete "$n" >/dev/null 2>&1 || true
    fi
  done
}

add_allow_all() {
  info "Allowing all sources to ${POSTGRES_PORT}, ${PGADMIN_PORT}"
  run_cmd "sudo ufw allow ${POSTGRES_PORT}/tcp comment '$COMMENT_TAG' || true"
  run_cmd "sudo ufw allow ${PGADMIN_PORT}/tcp comment '$COMMENT_TAG' || true"
}

add_allow_ips() {
  local ips=("$@")
  info "Allowing specific IPs: ${ips[*]}"
  for ip in "${ips[@]}"; do
    validate_ip "$ip" || { err "Invalid IP/CIDR: $ip"; exit 1; }
  run_cmd "sudo ufw allow from '$ip' to any port ${POSTGRES_PORT} proto tcp comment '$COMMENT_TAG' || true"
  run_cmd "sudo ufw allow from '$ip' to any port ${PGADMIN_PORT} proto tcp comment '$COMMENT_TAG' || true"
  done
}

show_status() {
  header "UFW Status (filtered)"
  sudo ufw status | grep -E "(${POSTGRES_PORT}|${PGADMIN_PORT})" || echo "No explicit rules for target ports"
}

add_allow_local() {
  info "Restricting access to localhost only"
  run_cmd "sudo ufw allow from 127.0.0.1 to any port ${POSTGRES_PORT} proto tcp comment '$COMMENT_TAG' || true"
  run_cmd "sudo ufw allow from 127.0.0.1 to any port ${PGADMIN_PORT} proto tcp comment '$COMMENT_TAG' || true"
  # Try IPv6 loopback silently (ignore if IPv6 disabled)
  run_cmd "sudo ufw allow from ::1 to any port ${POSTGRES_PORT} proto tcp comment '$COMMENT_TAG' 2>/dev/null || true"
  run_cmd "sudo ufw allow from ::1 to any port ${PGADMIN_PORT} proto tcp comment '$COMMENT_TAG' 2>/dev/null || true"
}

reload_firewall() {
  info "Reloading ufw"
  run_cmd "sudo ufw reload || true"
}

main() {
  local cmd="${1:-help}"; shift || true
  require_ufw

  case "$cmd" in
    help|-h|--help)
      usage ;;
    status)
      show_status ;;
    allow-all)
      remove_existing_rules
      add_allow_all
      reload_firewall
      show_status ;;
    allow|restrict)
      local ips_list=""
      if [[ "${1:-}" == "--ips" ]]; then
        shift
        ips_list="${1:-}"; shift || true
      else
        ips_list="${1:-}"; shift || true
      fi
      if [[ -z "$ips_list" ]]; then
        err "No IPs provided. Use: $0 allow --ips \"1.2.3.4 5.6.7.8\""; exit 1
      fi
      # Normalize separators (commas/space/newline)
      ips_list=$(echo "$ips_list" | tr ',' ' ')
      read -r -a ips_arr <<<"$ips_list"
      remove_existing_rules
      add_allow_ips "${ips_arr[@]}"
      reload_firewall
      show_status ;;
    allow-local)
      remove_existing_rules
      add_allow_local
      reload_firewall
      show_status ;;
    close|deny|remove)
      remove_existing_rules
      reload_firewall
      show_status ;;
    reload)
      reload_firewall ;;
    *)
      err "Unknown command: $cmd"
      usage
      exit 1 ;;
  esac
}

main "$@"
