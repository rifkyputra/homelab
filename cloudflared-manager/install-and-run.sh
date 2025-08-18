#!/usr/bin/env bash
# Install dependencies into a virtualenv (in .venv) and run the cloudflared_manager.py CLI
# Usage: ./install-and-run.sh [--help] [args...]
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VENV="$HERE/.venv"
REQS="$HERE/requirements.txt"
PYTHON=${PYTHON:-python3}

# create venv if missing
if [ ! -d "$VENV" ]; then
  echo "Creating virtualenv in $VENV"
  $PYTHON -m venv "$VENV"
fi

# activate and install
# shellcheck disable=SC1090
source "$VENV/bin/activate"

if [ -f "$REQS" ]; then
  echo "Installing requirements from $REQS"
  pip install --upgrade pip
  pip install -r "$REQS"
fi

# run the CLI with passed arguments
exec "$VENV/bin/python" "$HERE/cloudflared_manager.py" "$@"
