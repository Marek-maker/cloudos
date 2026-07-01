# CloudOS AI Setup Script
# Usage: cloudos module add ai

ai_setup() {
  local module_dir="${CLOUDOS_ROOT}/modules/ai"

  log_step "Setting up AI module (Ollama + Open WebUI + Hermes Supervisor)"

  mkdir -p "${module_dir}/data/ollama/config"

  WEBUI_SECRET_KEY=*** rand -base64 32 2>/dev/null || echo "change_me_webui")

  if [ "$(has_gpu)" = "nvidia" ]; then
    log_ok "NVIDIA GPU detected — GPU acceleration enabled"
  else
    log_warn "No GPU detected — LLM will run on CPU (slower, bigger models may not fit)"
    log_info "Consider: llama3.2:3b (2GB RAM) or phi3:3.8b (3GB RAM)"
  fi

  # Detect best model for available RAM
  local recommended_model="llama3.2:3b"
  if [ "${CLOUDOS_RAM_MB:-8192}" -ge 32768 ]; then
    recommended_model="llama3.1:8b"
  elif [ "${CLOUDOS_RAM_MB:-8192}" -ge 16384 ]; then
    recommended_model="llama3.2:3b"
  fi

  cat > "${module_dir}/.env" << EOF
CLOUDOS_DOMAIN=${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}
OPENWEBUI_PORT=3000
WEBUI_SECRET_KEY=***  log_ok "AI module configured"

  # Start Ollama first (model download takes time)
  log_step "Starting Ollama..."
  (cd "${module_dir}" && docker compose up -d ollama 2>&1 | tail -3)

  # Wait for Ollama to be ready
  log_info "Waiting for Ollama to start..."
  for i in $(seq 1 30); do
    sleep 2
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
      log_ok "Ollama ready"
      break
    fi
    if [ "$i" -eq 30 ]; then
      log_warn "Ollama not ready after 60s — check logs: docker logs cloudos-ollama"
    fi
  done

  # Pull recommended model
  log_info "Pulling ${recommended_model} (this may take a few minutes)..."
  docker exec cloudos-ollama ollama pull "${recommended_model}" 2>&1 | tail -3
  log_ok "Model ${recommended_model} ready"

  # Start remaining services
  log_step "Starting Open WebUI..."
  (cd "${module_dir}" && docker compose up -d open-webui 2>&1 | tail -3)

  log_ok "AI module running!"
  echo ""
  echo "  Chat UI:   http://chat.${CLOUDOS_TAILSCALE_HOSTNAME:-localhost}:3000"
  echo "  Ollama API: http://localhost:11434"
  echo "  Model:     ${recommended_model}"
  echo "  GPU:       ${CLOUDOS_GPU:-none}"
  echo ""
}
