#!/bin/bash
# 07-cleanup.enable.sh - autoremove unused packages
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "07-cleanup: starting"
mgr=$(detect_pkg_mgr)
if [[ "$mgr" == "apt" ]]; then
  apt-get autoremove -y
  log "apt autoremove run"
elif [[ "$mgr" == "dnf" ]]; then
  dnf autoremove -y || true
  log "dnf autoremove run"
elif [[ "$mgr" == "yum" ]]; then
  yum autoremove -y || true
  log "yum autoremove run"
else
  log "07-cleanup: no known package manager"
fi
log "07-cleanup: done"
