#!/bin/bash
# 01-update.enable.sh - update & upgrade system (idempotent)
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "01-update: starting"
mgr=$(detect_pkg_mgr)
if [[ "$mgr" == "apt" ]]; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  log "apt upgrade performed"
elif [[ "$mgr" == "dnf" ]]; then
  dnf upgrade -y
  log "dnf upgrade performed"
elif [[ "$mgr" == "yum" ]]; then
  yum update -y
  log "yum update performed"
else
  log "No known package manager; skipping updates"
fi
log "01-update: done"
