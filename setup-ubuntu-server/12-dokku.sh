#!/usr/bin/env bash
set -euo pipefail

# Load shared helpers + config
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"; need_root

msg "Dokku installer (Ubuntu 24.04) — running after apps-compose"

# ===== Settings =====
: "${DOKKU_TAG:=v0.36.0}"               # pin Dokku version/tag
SERVER_IP="$(echo "${STATIC_IP_CIDR}" | cut -d'/' -f1 || true)"
if [[ -z "${SERVER_IP}" ]]; then
  SERVER_IP="$(hostname -I | awk '{print $1}')"
fi
if [[ -n "${DOMAIN_NAME}" ]]; then
  DOKKU_DOMAIN="${DOMAIN_NAME}"
else
  DOKKU_DOMAIN="${SERVER_IP}.nip.io"     # zero-config wildcard for LAN
fi

if command -v dokku >/dev/null 2>&1; then
  INSTALLED_VER="$(dokku version 2>/dev/null | awk '{print $3}' || true)"
  if [[ -n "$INSTALLED_VER" ]]; then
    msg "Dokku already installed (version $INSTALLED_VER); skipping install"
  else
    msg "Dokku command exists but version detection failed; leaving installed state untouched"
  fi
else
  msg "Installing Dokku ${DOKKU_TAG}"
  WORKDIR="$(mktemp -d)"
  pushd "${WORKDIR}" >/dev/null
  wget -NP . "https://dokku.com/install/${DOKKU_TAG}/bootstrap.sh"
  DOKKU_TAG="${DOKKU_TAG}" bash bootstrap.sh
  popd >/dev/null
  rm -rf "${WORKDIR}"
fi

# Ensure our homelab site no longer claims default_server so Dokku vhosts win
if [[ -f /etc/nginx/sites-available/homelab ]]; then
  sed -i 's/listen 80 default_server;/listen 80;/g' /etc/nginx/sites-available/homelab || true
  sed -i 's/listen \[::\]:80 default_server;/listen \[::\]:80;/g' /etc/nginx/sites-available/homelab || true
fi

# Set global Dokku domain (nip.io if no real domain given)
dokku domains:set-global "${DOKKU_DOMAIN}"

# Add your SSH key to Dokku (so you can git push)
PUBKEY=""
for f in "${TARGET_HOME}/.ssh/id_ed25519.pub" "${TARGET_HOME}/.ssh/id_rsa.pub"; do
  [[ -f "$f" ]] && PUBKEY="$(cat "$f")" && break
done
if [[ -n "${PUBKEY}" ]]; then
  dokku ssh-keys:add "${TARGET_USER}" "${PUBKEY}" || true
else
  echo "NOTE: No public key for ${TARGET_USER}. Later, run:"
  echo "  dokku ssh-keys:add ${TARGET_USER} \"\$(cat /path/to/your.pub)\""
fi

# Open required ports (should already be allowed)
ufw allow 80/tcp  comment "Dokku HTTP"  || true
ufw allow 443/tcp comment "Dokku HTTPS" || true

# ===== Plugins: Let's Encrypt =====
# Install plugin + daily auto-renew cron
if ! dokku plugin:list 2>/dev/null | grep -q '^letsencrypt'; then
  sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git || true
else
  echo "Letsencrypt plugin already installed"
fi
sudo dokku letsencrypt:cron-job --add || true

# If admin email provided in config.env, set globally
if [[ -n "${ADMIN_EMAIL:-}" ]]; then
  dokku letsencrypt:set --global email "${ADMIN_EMAIL}" || true
  echo "Set global letsencrypt email to ${ADMIN_EMAIL}"
else
  echo "No ADMIN_EMAIL set in config.env; skipping global letsencrypt email."
fi

# ===== App templates =====
TPL_DIR="/opt/dokku-templates"
install -d -m 0755 "${TPL_DIR}"

# ---- Node (Procfile + Express) ----
install -d -m 0755 "${TPL_DIR}/node-basic"
cat >"${TPL_DIR}/node-basic/Procfile" <<'EOF'
web: node server.js
EOF
cat >"${TPL_DIR}/node-basic/package.json" <<'EOF'
{
  "name": "node-basic",
  "private": true,
  "type": "module",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.19.2" }
}
EOF
cat >"${TPL_DIR}/node-basic/server.js" <<'EOF'
import express from "express";
const app = express();
const PORT = process.env.PORT || 3000;
app.get("/", (_req, res) => res.send("Hello from node-basic on Dokku"));
app.listen(PORT, () => console.log(`Listening on ${PORT}`));
EOF
cat >"${TPL_DIR}/node-basic/README.md" <<EOF
Node template (Procfile buildpack). Deploy with:
  dokku apps:create node-basic
  dokku domains:add node-basic node-basic.${DOKKU_DOMAIN}
  # from your dev machine:
  #   git init && git add . && git commit -m init
  #   git remote add dokku dokku@${SERVER_IP}:node-basic
  #   git push dokku main
EOF

# ---- Go (Procfile + Dockerfile for predictable build) ----
install -d -m 0755 "${TPL_DIR}/go-basic"
cat >"${TPL_DIR}/go-basic/Procfile" <<'EOF'
web: ./server
EOF
cat >"${TPL_DIR}/go-basic/go.mod" <<'EOF'
module example.com/app
go 1.22
EOF
cat >"${TPL_DIR}/go-basic/main.go" <<'EOF'
package main
import (
  "fmt"
  "log"
  "net/http"
  "os"
)
func main() {
  port := os.Getenv("PORT")
  if port == "" { port = "3000" }
  http.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
    fmt.Fprintln(w, "Hello from go-basic on Dokku")
  })
  log.Println("Listening on :" + port)
  log.Fatal(http.ListenAndServe(":"+port, nil))
}
EOF
cat >"${TPL_DIR}/go-basic/Dockerfile" <<'EOF'
FROM golang:1.22 AS build
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o server ./main.go

FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/server /app/server
ENV PORT=3000
EXPOSE 3000
CMD ["/app/server"]
EOF
cat >"${TPL_DIR}/go-basic/README.md" <<EOF
Go template. Uses Dockerfile for portability. Deploy with:
  dokku apps:create go-basic
  dokku domains:add go-basic go-basic.${DOKKU_DOMAIN}
  # push from dev:
  #   git init && git add . && git commit -m init
  #   git remote add dokku dokku@${SERVER_IP}:go-basic
  #   git push dokku main
(Optional) Buildpack route exists, but Dockerfile is the simplest path on Dokku.
EOF

# ---- Bun (Procfile + Dockerfile using oven/bun) ----
install -d -m 0755 "${TPL_DIR}/bun-basic"
cat >"${TPL_DIR}/bun-basic/Procfile" <<'EOF'
web: bun run server.js
EOF
cat >"${TPL_DIR}/bun-basic/package.json" <<'EOF'
{
  "name": "bun-basic",
  "private": true,
  "scripts": { "start": "bun run server.js" }
}
EOF
cat >"${TPL_DIR}/bun-basic/server.js" <<'EOF'
const server = Bun.serve({
  port: process.env.PORT || 3000,
  fetch(_req) { return new Response("Hello from bun-basic on Dokku"); }
});
console.log(`Bun listening on ${server.port}`);
EOF
cat >"${TPL_DIR}/bun-basic/Dockerfile" <<'EOF'
FROM oven/bun:1
WORKDIR /app
COPY package.json ./
RUN true
COPY . .
ENV PORT=3000
EXPOSE 3000
CMD ["bun","run","server.js"]
EOF
cat >"${TPL_DIR}/bun-basic/README.md" <<EOF
Bun template. Uses Dockerfile (most reliable on Dokku today). Deploy with:
  dokku apps:create bun-basic
  dokku domains:add bun-basic bun-basic.${DOKKU_DOMAIN}
  # push from dev:
  #   git init && git add . && git commit -m init
  #   git remote add dokku dokku@${SERVER_IP}:bun-basic
  #   git push dokku main
(You can experiment with community Bun buildpacks if you prefer buildpacks.)
EOF

# Tighten perms for templates
chown -R "${TARGET_USER}:${TARGET_USER}" "${TPL_DIR}"

# Final sanity: reload nginx and ensure your compose stack is still happy
nginx -t && systemctl reload nginx
systemctl restart homelab-compose || true

msg "Dokku ready ✅"
cat <<INFO
Global dokku domain: ${DOKKU_DOMAIN}
Examples:
  dokku apps:create hello
  dokku domains:add hello hello.${DOKKU_DOMAIN}
  # on your dev machine:
  #   git remote add dokku dokku@${SERVER_IP}:hello
  #   git push dokku main

Let’s Encrypt:
  dokku letsencrypt:set --global email you@example.com
  dokku letsencrypt:enable <app>
  dokku letsencrypt:cron-job --add

Templates created in: ${TPL_DIR}
  node-basic/, go-basic/, bun-basic/

INFO
