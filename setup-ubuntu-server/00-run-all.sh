#!/usr/bin/env bash
# Wrapper retained for backward compatibility: delegates to selfhost profile.
set -euo pipefail
exec "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/selfhost/00-run-all.sh"

