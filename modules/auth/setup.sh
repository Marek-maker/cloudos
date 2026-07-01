# CloudOS Auth Setup Script
# Usage: cloudos module add auth

auth_setup() {
  local module_dir="${CLOUDOS_ROOT}/modules/auth"
  local data_dir="${module_dir}/data"

  log_step "Setting up Auth module (Authentik + Caddy)"

  mkdir -p "${data_dir}/caddy" "${data_dir}/authentik"

  AUTHENTIK_DB_PASSWORD=$(openssl rand -base64 32 2>/dev/null || echo "change_me_db")
  AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 2>/dev/null || echo "change_me_secret")

  cat > "${module_dir}/.env" << EOF
AUTHENTIK_DB_PASSWORD=${AUTHENTIK_DB_PASSWORD}
AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}
CLOUDOS_ADMIN_EMAIL=admin@cloudos.local
CLOUDOS_ADMIN_PASSWORD=cloudos
CLOUDOS_DOMAIN=${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}
EOF

  cat > "${data_dir}/caddy/Caddyfile" << CADDY
{
  email admin@cloudos.local
}

auth.${CLOUDOS_TAILSCALE_HOSTNAME:-localhost} {
  reverse_proxy authentik-server:9000
}

health.${CLOUDOS_TAILSCALE_HOSTNAME:-localhost} {
  respond "OK" 200
}
CADDY

  docker network inspect cloudos >/dev/null 2>&1 || docker network create cloudos

  log_ok "Auth module configured"
  log_info "Default login: admin@cloudos.local / cloudos"
  log_info "CHANGE PASSWORD after first login!"

  log_step "Starting Auth module..."
  (cd "${module_dir}" && docker compose up -d 2>&1 | tail -5)

  log_ok "Auth module running!"
  echo "  Authentik: http://auth.${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}"
}
