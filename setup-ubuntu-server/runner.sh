#!/usr/bin/env bash
set -euo pipefail

# Generic profile runner.
# Normal usage: sourced from profile script (selfhost/00-run-all.sh or cloud/00-run-all.sh)
# which defines:
#   SCRIPT_ROOT  (directory containing scripts + config.env)
#   SCRIPTS      (array of script filenames to run in order)
# Convenience: if executed directly, optionally accept a profile name and delegate.

# If invoked directly (not sourced) and required vars missing, delegate to profile wrapper.
if [[ "${BASH_SOURCE[0]}" == "$0" ]] && { [[ -z "${SCRIPT_ROOT:-}" ]] || ! declare -p SCRIPTS >/dev/null 2>&1; }; then
  profile="${1:-selfhost}"
  base_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  case "$profile" in
    selfhost|cloud)
      exec "${base_dir}/${profile}/00-run-all.sh" "${@:2}" ;;
    *)
      echo "Usage: sudo ./selfhost/00-run-all.sh | sudo ./cloud/00-run-all.sh" >&2
      echo "Or:   sudo ./runner.sh [selfhost|cloud]" >&2
      exit 1 ;;
  esac
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }
log_success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $*"; }

cleanup() { local ec=$?; [[ $ec -ne 0 ]] && log_error "Profile run failed (exit $ec)"; exit $ec; }
trap cleanup EXIT

if [[ ${EUID} -ne 0 ]]; then
  log_error "Must run as root (sudo)."; echo "Usage: sudo $0" >&2; exit 1; fi

if [[ -z "${SCRIPT_ROOT:-}" || ! -d "${SCRIPT_ROOT}" ]]; then
  log_error "SCRIPT_ROOT invalid or not set: '${SCRIPT_ROOT:-}'"; exit 1; fi

if [[ ! -f "${SCRIPT_ROOT}/config.env" ]]; then
  log_error "config.env missing in ${SCRIPT_ROOT}"; exit 1; fi

# Validate SCRIPTS array presence & non-empty
if ! declare -p SCRIPTS >/dev/null 2>&1; then
  log_error "SCRIPTS array not defined by caller (export SCRIPTS before invoking runner)"; exit 1; fi
if ((${#SCRIPTS[@]} == 0)); then
  log_error "SCRIPTS array empty; profile misconfigured"; exit 1; fi

log "Verifying scripts..."
for s in "${SCRIPTS[@]}"; do
  path="${SCRIPT_ROOT}/${s}"
  [[ -f "$path" ]] || { log_error "Missing script: $path"; exit 1; }
  [[ -x "$path" ]] || chmod +x "$path" || { log_error "Cannot chmod $path"; exit 1; }
done

FAILED=()
log "Running profile scripts: ${SCRIPTS[*]}"
for s in "${SCRIPTS[@]}"; do
  log "==> ${s}";
  if bash "${SCRIPT_ROOT}/${s}"; then
    log_success "Done ${s}"
  else
    log_error "Failed ${s}"; FAILED+=("${s}")
    [[ "$s" =~ ^(01-basics|05-docker) ]] && { log_error "Critical failure; aborting."; break; }
  fi
done

if [[ ${#FAILED[@]} -eq 0 ]]; then
  log_success "Profile completed successfully ✅"
else
  log_error "Failed scripts: ${FAILED[*]}"
fi

echo
log_success "Setup run finished"
echo "Next steps (if applicable):"
echo "- newgrp docker  # or logout/login"
echo "- ufw status verbose"
echo "- Access services via configured IP/domain"
