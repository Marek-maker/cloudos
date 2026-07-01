# CloudOS File Sync Setup Script
# Usage: cloudos module add filesync

filesync_setup() {
  local module_dir="${CLOUDOS_ROOT}/modules/filesync"

  log_step "Setting up File Sync module (Nextcloud + OnlyOffice)"

  if [ ! -f "${CLOUDOS_ROOT}/modules/auth/docker-compose.yml" ]; then
    log_warn "Auth module not installed. You'll need to configure OIDC manually."
  fi

  mkdir -p "${module_dir}/data"

  NEXTCLOUD_DB_PASSWORD=$(openssl rand -base64 32 2>/dev/null || echo "change_me_nc")
  ONLYOFFICE_JWT_SECRET=$(openssl rand -base64 32 2>/dev/null || echo "change_me_oo")

  cat > "${module_dir}/.env" << EOF
NEXTCLOUD_DB_PASSWORD=${NEXTCLOUD_DB_PASSWORD}
ONLYOFFICE_JWT_SECRET=${ONLYOFFICE_JWT_SECRET}
CLOUDOS_DOMAIN=${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}
EXTERNAL_DATA_DIR=${module_dir}/data
EOF

  log_ok "File Sync module configured"

  log_step "Starting File Sync module..."
  (cd "${module_dir}" && docker compose up -d 2>&1 | tail -5)

  log_ok "File Sync module running!"
  echo "  Nextcloud: http://nextcloud.${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}:8081"
}
