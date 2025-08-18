#!/bin/bash
# 01-update.disable.sh - best-effort undo for update (cannot downgrade safely)
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "01-update.disable: nothing to undo (upgrades are not safely reverted). See backups for configs."
exit 0
