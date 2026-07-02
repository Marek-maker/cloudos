# CloudOS Photos Setup Script
# Usage: cloudos module add photos

photos_setup() {
  local module_dir="${CLOUDOS_ROOT}/modules/photos"
  local data_dir="${module_dir}/data"

  log_step "Setting up Photos module (Immich v3)"

  mkdir -p "${data_dir}/library" "${data_dir}/postgres"

  # Generate secure DB password if .env doesn't exist or has placeholder
  if [ ! -f "${module_dir}/.env" ] || grep -q "CHANGE_ME" "${module_dir}/.env" 2>/dev/null; then
    local db_pass
    db_pass=$(openssl rand -base64 24 2>/dev/null | tr -cd 'A-Za-z0-9' | head -c 24 || echo "immich_$(date +%s)")
    
    cat > "${module_dir}/.env" << EOF
# CloudOS — Photos Module (Immich) Configuration
UPLOAD_LOCATION=${module_dir}/data/library
DB_DATA_LOCATION=${module_dir}/data/postgres
IMMICH_VERSION=v3
IMMICH_PORT=2283
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
DB_PASSWORD=${db_pass}
TZ=Europe/Bratislava
EOF
    log_ok "Generated .env with secure password"
  fi

  # Check AI module dependency
  if [ ! -f "${CLOUDOS_ROOT}/modules/ai/docker-compose.yml" ]; then
    log_warn "AI module not installed. Immich ML tagging needs AI module for Hermes integration."
    log_info "Run: cloudos module add ai"
  fi

  # Check if GPU available (ML acceleration)
  if [ "$(has_gpu)" = "nvidia" ]; then
    log_info "NVIDIA GPU detected — enabling GPU acceleration for ML"
    log_info "To enable, uncomment the deploy section in docker-compose.yml"
  elif [ "$(has_gpu)" = "intel" ]; then
    log_info "Intel GPU detected — use -openvino ML image tag for acceleration"
  fi

  log_step "Starting Immich..."
  (cd "${module_dir}" && docker compose up -d 2>&1 | tail -5)

  log_info "Waiting for Immich to be ready..."
  local retries=0
  until curl -sf http://localhost:2283/.well-known/health >/dev/null 2>&1 || [ $retries -ge 12 ]; do
    sleep 5
    retries=$((retries + 1))
  done

  if curl -sf http://localhost:2283/.well-known/health >/dev/null 2>&1; then
    log_ok "Immich is running on http://localhost:2283"
    log_info "First visit: create admin account"
    log_info "After setup: configure OIDC in Immich Admin → Settings → Authentication"
  else
    log_warn "Immich may still be starting. Check: docker compose -f ${module_dir}/docker-compose.yml logs"
  fi

  log_ok "Photos module added!"
}
