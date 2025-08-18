#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "[14] Tailscale VPN setup"

TAILSCALE_ENABLE=${TAILSCALE_ENABLE:-false}
TAILSCALE_AUTHKEY=${TAILSCALE_AUTHKEY:-}
TAILSCALE_EXTRA_ARGS=${TAILSCALE_EXTRA_ARGS:-"--ssh"}

if [[ "$TAILSCALE_ENABLE" != "true" ]]; then
  log "TAILSCALE_ENABLE not true; skipping installation. Set TAILSCALE_ENABLE=true in config.env to enable."
  exit 0
fi

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh || { log_error "Tailscale install failed"; exit 1; }
else
  log "Tailscale already installed"
fi

systemctl enable --now tailscaled || true

if ! tailscale status >/dev/null 2>&1; then
  if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
    log "Bringing Tailscale up (auth key)"
    if ! tailscale up --authkey "$TAILSCALE_AUTHKEY" $TAILSCALE_EXTRA_ARGS; then
      log_error "tailscale up failed"
      exit 1
    fi
  else
    log "No TAILSCALE_AUTHKEY provided; run manually: tailscale up $TAILSCALE_EXTRA_ARGS"
  fi
else
  log "Tailscale already connected"
fi

tailscale status || true
log_success "Tailscale setup complete"
