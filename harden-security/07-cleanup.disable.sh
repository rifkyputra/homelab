#!/bin/bash
# 07-cleanup.disable.sh - cannot undo autoremove; log for operator
set -euo pipefail
. ./lib/harden-lib.sh
require_root
log "07-cleanup.disable: autoremove cannot be safely undone"
log "07-cleanup.disable: consider reinstalling packages manually if needed"
