#!/bin/bash
# Common helpers for harden-security scripts
set -euo pipefail

HARDEN_DIR="/var/lib/harden-security"
LOG_DIR="/var/log/harden-security"
mkdir -p "$HARDEN_DIR" "$LOG_DIR"

timestamp(){ date -u +%Y%m%dT%H%M%SZ; }
require_root(){ if [[ $EUID -ne 0 ]]; then echo "This script must be run as root." >&2; exit 1; fi }
log(){ echo "$(date -Is) - $*" | tee -a "$LOG_DIR/harden.log"; }

backup_file(){
  local src="$1"
  if [[ -e "$src" ]]; then
    local bak="$HARDEN_DIR/$(basename "$src").bak.$(timestamp)"
    cp -a "$src" "$bak"
    echo "$bak"
  else
    echo ""
  fi
}

restore_file(){
  local bak="$1"
  local dest="$2"
  if [[ -e "$bak" ]]; then
    cp -a "$bak" "$dest"
    log "Restored $dest from $bak"
    return 0
  fi
  return 1
}

detect_pkg_mgr(){
  if command -v apt-get &>/dev/null; then echo apt; return; fi
  if command -v dnf &>/dev/null; then echo dnf; return; fi
  if command -v yum &>/dev/null; then echo yum; return; fi
  echo ""; }

install_pkgs(){
  local mgr; mgr=$(detect_pkg_mgr)
  if [[ -z "$mgr" ]]; then log "No known package manager"; return 1; fi
  if [[ "$mgr" == "apt" ]]; then apt-get update -y && apt-get install -y "$@"; fi
  if [[ "$mgr" == "dnf" ]]; then dnf install -y "$@"; fi
  if [[ "$mgr" == "yum" ]]; then yum install -y "$@"; fi
}

is_installed(){
  command -v "$1" &>/dev/null || dpkg -s "$1" &>/dev/null || rpm -q "$1" &>/dev/null
}

save_state(){
  local name="$1"; shift
  local out="$HARDEN_DIR/state-$name.$(timestamp).txt"
  printf "%s\n" "$@" > "$out"
  echo "$out"
}

safe_sed_replace(){
  # usage: safe_sed_replace file pattern replacement
  local file="$1"; local pattern="$2"; local repl="$3"
  grep -qE "$pattern" "$file" 2>/dev/null && sed -ri "s/$pattern/$repl/" "$file" || echo "$repl" >> "$file"
}

# end of lib
