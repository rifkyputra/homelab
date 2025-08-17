#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "Install Netdata + Glances"
aptq install netdata glances
systemctl enable --now netdata
