#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"; need_root

msg "Install Nginx and set site + reverse proxy"
aptq install nginx
systemctl enable --now nginx
mkdir -p /var/www/homelab
cat >/var/www/homelab/index.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>Homelab</title></head>
<body><h1>Welcome to your Homelab</h1><p>Nginx is up.</p></body></html>
EOF

cat >/etc/nginx/sites-available/homelab <<'EOF'
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;

  location = / { root /var/www/homelab; index index.html; }
  location = /health { return 200 "ok\n"; add_header Content-Type text/plain; }

  location /portainer/ {
    proxy_pass http://127.0.0.1:9000/;
    proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr;
  }
  location /code/ {
    proxy_pass http://127.0.0.1:8080/;
    proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr;
  }
  location /grafana/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr;
  }
}
EOF

ln -sf /etc/nginx/sites-available/homelab /etc/nginx/sites-enabled/homelab
rm -f /etc/nginx/sites-enabled/default || true
nginx -t && systemctl reload nginx

msg "Install certbot (skips issuance if no DOMAIN_NAME)"
aptq install certbot python3-certbot-nginx
if [[ -n "${DOMAIN_NAME}" && -n "${ADMIN_EMAIL:-}" ]]; then
  # Check if cert already exists & is valid >15 days
  if [[ -d "/etc/letsencrypt/live/${DOMAIN_NAME}" ]]; then
    if openssl x509 -checkend $((15*24*3600)) -noout -in "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" 2>/dev/null; then
      echo "Existing certificate for ${DOMAIN_NAME} valid >15 days; skipping issuance"
    else
      echo "Certificate nearing expiry; attempting renewal"
      certbot renew --dry-run || true
      certbot renew || true
    fi
  else
    certbot --nginx -d "${DOMAIN_NAME}" -m "${ADMIN_EMAIL}" --agree-tos --no-eff-email --redirect -n || \
      echo "Certbot initial issuance failed; check DNS, ports 80/443."
  fi
else
  echo "No domain provided; HTTPS not configured yet."
fi
