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

usage(){
  cat <<EOF
Usage: $PROG -d <domain> [options]

Options:
  -d DOMAIN             Cloudflare-managed domain (example.com) - required
  -n NAME               Tunnel name (default: $TUNNEL_NAME)
  -s host:port          Add ingress mapping (repeatable). Example: -s grafana:3000 -> grafana.<domain>
  --install-cloudflared Install cloudflared package (apt) on Ubuntu
  --route-dns           Create DNS route(s) for each added host (requires cloudflared login)
  --install-systemd     Install and start cloudflared as a systemd service (requires sudo)
  --docker-run          Print a docker run example instead of installing systemd
  -y                    Non-interactive (assume yes for prompts)
  -h                    Show this help

If no -s flags are provided, a default mapping for pgadmin will be created:
  pgadmin.<domain> -> localhost:5050

This script will:
  - optionally install cloudflared
  - run 'cloudflared tunnel create' to create a tunnel
  - write a config.yml to $CRED_DIR/config.yml
  - optionally create DNS routes and install systemd

EOF
}

parse_args(){
  while [[ ${#@} -gt 0 ]]; do
    case "$1" in
      -d) DOMAIN="$2"; shift 2;;
      -n) TUNNEL_NAME="$2"; shift 2;;
      -s) INGRESS+=("$2"); shift 2;;
      --install-cloudflared) INSTALL_CLOUDFLARED=true; shift;;
      --route-dns) ROUTE_DNS=true; shift;;
      --install-systemd) INSTALL_SYSTEMD=true; shift;;
      --docker-run) DOCKER_RUN=true; shift;;
      -y) FORCE_NO_PROMPT=true; shift;;
      -h|--help) usage; exit 0;;
      *) echo "Unknown arg: $1" >&2; usage; exit 2;;
    esac
  done
}

prompt_yes(){
  if [[ "$FORCE_NO_PROMPT" == true ]]; then
    return 0
  fi
  read -r -p "$1 [y/N]: " ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0;;
    *) return 1;;
  esac
}

check_ubuntu(){
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID_LIKE" != *"debian"* ]]; then
      echo "Warning: this script targets Ubuntu/Debian but detected: $ID" >&2
    fi
  fi
}

install_cloudflared_apt(){
  echo "Installing cloudflared from Cloudflare APT repo..."
  # follow Cloudflare's recommended apt install steps
  sudo apt update
  sudo apt install -y curl gnupg lsb-release
  curl -fsSL https://pkg.cloudflare.com/pubkey.gpg | sudo gpg --dearmour -o /usr/share/keyrings/cloudflare-main-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main-archive-keyring.gpg] https://pkg.cloudflare.com/ $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/cloudflare-client.list > /dev/null
  sudo apt update
  sudo apt install -y cloudflared
}

check_cloudflared(){
  if ! command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared not found on PATH"
    if [[ "$INSTALL_CLOUDFLARED" == true ]]; then
      install_cloudflared_apt
    else
      echo "Run this script with --install-cloudflared to install automatically, or install manually."
      exit 3
    fi
  fi
}

create_tunnel(){
  mkdir -p "$CRED_DIR"
  echo "Ensuring tunnel exists: $TUNNEL_NAME (credentials dir: $CRED_DIR)"

  # Try to detect an existing tunnel via `cloudflared tunnel list` and reuse it
  if cloudflared tunnel list >/dev/null 2>&1; then
    existing_id=$(cloudflared tunnel list 2>/dev/null | awk -v name="$TUNNEL_NAME" '$0 ~ name {print $1; exit}') || true
    if [[ -n "$existing_id" ]]; then
      TUNNEL_ID="$existing_id"
      if [[ -f "$CRED_DIR/$TUNNEL_ID.json" ]]; then
        CRED_FILE="$CRED_DIR/$TUNNEL_ID.json"
        echo "Found existing tunnel named '$TUNNEL_NAME' with ID $TUNNEL_ID; reusing credentials: $CRED_FILE"
        return 0
      else
        echo "Found existing tunnel ID $TUNNEL_ID but credential file $CRED_DIR/$TUNNEL_ID.json not present; will try to create credentials." >&2
      fi
    fi
  fi

  echo "Creating tunnel: $TUNNEL_NAME"
  # This will open a browser on first run (cloudflared login) if not logged in
  cloudflared tunnel create "$TUNNEL_NAME"

  # pick latest credentials file
  local cred_file
  cred_file=$(ls -1t "$CRED_DIR"/*.json 2>/dev/null || true)
  if [[ -z "$cred_file" ]]; then
    echo "Unable to find credentials JSON in $CRED_DIR after create." >&2
    exit 4
  fi
  CRED_FILE=$(echo "$cred_file" | head -n1)
  TUNNEL_ID=$(basename "$CRED_FILE" .json)
  echo "Tunnel ID: $TUNNEL_ID (credentials: $CRED_FILE)"
}

write_config(){
  mkdir -p "$CRED_DIR"
  CONFIG_PATH="$CRED_DIR/config.yml"
  echo "Writing config to $CONFIG_PATH"
  {
    echo "tunnel: $TUNNEL_ID"
    echo "credentials-file: $CRED_FILE"
    echo
    echo "ingress:"
    if [[ ${#INGRESS[@]} -eq 0 ]]; then
      echo "  - hostname: pgadmin.$DOMAIN"
      echo "    service: http://127.0.0.1:5050"
    else
      for entry in "${INGRESS[@]}"; do
        # entry format: name:port or name/path:port (we support name only or name:port)
        hostpart=${entry%%:*}
        portpart=${entry#*:}
        if [[ "$hostpart" == "$portpart" ]]; then
          portpart=80
        fi
        echo "  - hostname: $hostpart.$DOMAIN"
        echo "    service: http://127.0.0.1:$portpart"
      done
    fi
    echo "  - service: http_status:404"
  } > "$CONFIG_PATH"
  echo "Wrote config with ${#INGRESS[@]:-1} ingress entries."
}

create_dns_routes(){
  echo "Creating DNS routes for the tunnel..."
  if [[ ${#INGRESS[@]} -eq 0 ]]; then
    if ! cloudflared tunnel route dns "$TUNNEL_NAME" "pgadmin.$DOMAIN"; then
      echo "Warning: creating DNS route for pgadmin.$DOMAIN failed (may already exist). Continuing."
    fi
  else
    for entry in "${INGRESS[@]}"; do
      hostpart=${entry%%:*}
      if ! cloudflared tunnel route dns "$TUNNEL_NAME" "$hostpart.$DOMAIN"; then
        echo "Warning: creating DNS route for $hostpart.$DOMAIN failed (may already exist). Continuing."
      fi
    done
  fi
}

install_systemd_service(){
  echo "Installing systemd service via 'cloudflared service install' (requires sudo)."
  # If a unit already exists, skip installation to avoid errors.
  if systemctl list-unit-files | grep -q '^cloudflared.service'; then
    echo "cloudflared.service already present; skipping 'service install'."
    # Try to start/enable if not active
    if ! systemctl is-enabled --quiet cloudflared; then
      sudo systemctl enable --now cloudflared || true
      echo "Attempted to enable/start existing cloudflared.service"
    fi
    return 0
  fi

  if ! sudo cloudflared service install; then
    echo "systemd install failed; you may need to run 'cloudflared service install' manually." >&2
    return 1
  fi
  echo "cloudflared service installed and started via systemd."
}

print_docker_example(){
  echo "Docker run example (mount credentials directory):"
  echo
  echo "  docker run -d --name cloudflared \\
    -v \"$CRED_DIR\":/etc/cloudflared \\
    cloudflare/cloudflared:latest tunnel run $TUNNEL_NAME"
}

main(){
  parse_args "$@"
  if [[ -z "$DOMAIN" ]]; then
    echo "Error: domain (-d) is required." >&2; usage; exit 2
  fi
  check_ubuntu
  check_cloudflared
  create_tunnel
  write_config

  if [[ "$ROUTE_DNS" == true ]]; then
    create_dns_routes
  fi

  if [[ "$INSTALL_SYSTEMD" == true ]]; then
    if prompt_yes "Install and start cloudflared systemd service now?"; then
      install_systemd_service
    else
      echo "Skipped systemd service installation."
    fi
  elif [[ "$DOCKER_RUN" == true ]]; then
    print_docker_example
  else
    echo "To run the tunnel now without systemd, run:"
    echo "  cloudflared tunnel --config $CRED_DIR/config.yml run $TUNNEL_NAME"
  fi

  echo "Cloudflare Tunnel setup complete. Config/credentials: $CRED_DIR"
}

main "$@"
