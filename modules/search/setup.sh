# CloudOS Search Setup Script
# Usage: cloudos module add search

search_setup() {
  local module_dir="${CLOUDOS_ROOT}/modules/search"

  log_step "Setting up Search module (SearXNG + Meilisearch)"

  if [ ! -f "${CLOUDOS_ROOT}/modules/auth/docker-compose.yml" ]; then
    log_warn "Auth module not installed. SearXNG will be on :4000 directly."
  fi

  SEARXNG_SECRET_KEY=*** rand -base64 48 2>/dev/null || echo "change_me_sx")
  MEILISEARCH_MASTER_KEY=*** rand -base64 32 2>/dev/null || echo "change_me_meili")

  cat > "${module_dir}/.env" << EOF
CLOUDOS_DOMAIN=${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}
SEARXNG_PORT=4000
SEARXNG_SECRET_KEY=${SEAR...EOF

  log_ok "Search module configured"

  # Configure SearXNG to use Meilisearch
  log_info "SearXNG will index documents via Meilisearch"
  log_info "Connect your apps: meilisearch:7700 (internal) or :7700 (host)"

  log_step "Starting Search module..."
  (cd "${module_dir}" && docker compose up -d 2>&1 | tail -5)

  log_ok "Search module running!"
  echo "  SearXNG:    http://search.${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}:4000"
  echo "  Meilisearch: http://${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}:7700"
  echo ""
}
