#!/usr/bin/env bash
set -euo pipefail

# 17-cloudflared.sh
# General-purpose Ubuntu server helper to install and configure a Cloudflare Tunnel.
# - Designed for Ubuntu servers (apt/systemd)
# - Creates a tunnel, writes config, optionally creates DNS routes and installs systemd
# - Supports adding multiple ingress mappings via repeated -s flags (host:port)

PROG=$(basename "$0")
TUNNEL_NAME="ubuntu-tunnel"
CRED_DIR="$HOME/.cloudflared"
DOMAIN=""
ROUTE_DNS=false
INSTALL_SYSTEMD=false
INSTALL_CLOUDFLARED=false
DOCKER_RUN=false
FORCE_NO_PROMPT=false
INGRESS=()

# If script is run under sudo, prefer the original invoking user's home for cloudflared
# so we find the origin cert (cert.pem) that 'cloudflared login' created.
if [[ "${SUDO_USER:-}" != "" && "$EUID" -eq 0 ]]; then
  SUDO_HOME=$(eval echo "~${SUDO_USER}")
  if [[ -d "$SUDO_HOME" ]]; then
    CRED_DIR="$SUDO_HOME/.cloudflared"
    echo "Note: running under sudo; using credential dir: $CRED_DIR"
  fi
fi

usage(){
  cat <<EOF
Usage: $PROG -d <domain> [options]

# 17-cloudflared.sh
# Minimal installer: add Cloudflare APT repository and install cloudflared on Debian/Ubuntu

PROG=$(basename "$0")
FORCE_NO_PROMPT=false

usage(){
  cat <<EOF
Usage: $PROG [options]

Options:
  -y            Non-interactive (assume yes for prompts)
  -h            Show this help
#!/usr/bin/env bash
set -euo pipefail

# 17-cloudflared.sh
# Minimal installer: add Cloudflare APT repository and install cloudflared on Debian/Ubuntu

PROG=$(basename "$0")
FORCE_NO_PROMPT=false

usage(){
  cat <<'EOF'
Usage: PROG [options]

Options:
  -y            Non-interactive (assume yes for prompts)
  -h            Show this help

This script will:
  - add Cloudflare's APT GPG key to /usr/share/keyrings
  - add the cloudflared APT source list
  - update apt and install the 'cloudflared' package

EOF
}

parse_args(){
  while [[ ${#@} -gt 0 ]]; do
    case "$1" in
      -y) FORCE_NO_PROMPT=true; shift;;
      -h|--help) usage; exit 0;;
      *) echo "Unknown arg: $1" >&2; usage; exit 2;;
    esac
  done
}

install_cloudflared_apt(){
  echo "Installing cloudflared from Cloudflare APT repo..."
  sudo apt update
  sudo apt install -y curl lsb-release

  # Download the Cloudflare repository GPG key and save to /usr/share/keyrings
  if [[ ! -f /usr/share/keyrings/cloudflare-archive-keyring.gpg ]]; then
    echo "Adding Cloudflare GPG key to /usr/share/keyrings/cloudflare-archive-keyring.gpg"
    curl -L https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null
  else
    echo "Cloudflare GPG key already present."
  fi

  # Add the cloudflared APT source list if not present
  if [[ ! -f /etc/apt/sources.list.d/cloudflared.list ]]; then
    echo "Adding Cloudflare APT source list"
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
  else
    echo "Cloudflare APT source list already exists."
  fi

  sudo apt update
  sudo apt install -y cloudflared
}

main(){
  parse_args "$@"

  if command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared is already installed: $(command -v cloudflared)"
    exit 0
  fi

  if [[ "$FORCE_NO_PROMPT" != true ]]; then
    read -r -p "Proceed to add Cloudflare APT repo and install cloudflared? [y/N]: " ans
    case "$ans" in
      [Yy]|[Yy][Ee][Ss]) ;;
      *) echo "Aborted."; exit 1;;
    esac
  fi

  install_cloudflared_apt
  echo "cloudflared install finished."
}

main "$@"
