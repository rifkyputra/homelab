#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "Install Cockpit (+ machines)"
aptq install cockpit cockpit-machines
systemctl enable --now cockpit.socket
