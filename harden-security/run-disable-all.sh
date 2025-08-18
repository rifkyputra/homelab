#!/bin/bash
# Run all disable scripts in numeric order
set -euo pipefail
require_root(){ if [[ $EUID -ne 0 ]]; then echo "Run as root" >&2; exit 1; fi }
require_root
for f in $(ls -1 *.disable.sh 2>/dev/null | sort); do
  echo "==> Running $f"
  bash "$f"
done
echo "All disable scripts executed. Check /var/log/harden-security/harden.log for details."
