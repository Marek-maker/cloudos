#!/usr/bin/env bash
# Environment detection engine for CloudOS
# Usage: source lib/detect.sh && detect_all

detect_os() {
  CLOUDOS_OS=$(get_os)
  CLOUDOS_ARCH=$(get_arch)
  log_info "OS: ${CLOUDOS_OS} (${CLOUDOS_ARCH})"
}

detect_docker() {
  if has_cmd docker && docker info >/dev/null 2>&1; then
    CLOUDOS_DOCKER="yes"
    CLOUDOS_DOCKER_COMPOSE=$(has_cmd docker-compose && echo "standalone" || (has_cmd docker && docker compose version >/dev/null 2>&1 && echo "plugin") || echo "none")
    CLOUDOS_DOCKER_VERSION=$(docker --version 2>/dev/null | sed 's/Docker version //' | awk '{print $1}')
    log_ok "Docker: ${CLOUDOS_DOCKER_VERSION} (${CLOUDOS_DOCKER_COMPOSE})"
  else
    CLOUDOS_DOCKER="no"
    log_warn "Docker not running. Run 'cloudos setup docker' to install."
  fi
}

detect_resources() {
  CLOUDOS_RAM_MB=$(get_ram_mb)
  CLOUDOS_RAM_GB=$((CLOUDOS_RAM_MB / 1024))
  CLOUDOS_DISK=$(get_disk_info /)
  
  local gpu_type
  gpu_type=$(has_gpu)
  if [ "$gpu_type" != "none" ]; then
    CLOUDOS_GPU=$(get_gpu_info)
    log_ok "GPU: ${CLOUDOS_GPU}"
  else
    CLOUDOS_GPU="none"
    log_info "GPU: not detected"
  fi
  
  log_info "RAM: ${CLOUDOS_RAM_GB}GB | Disk: ${CLOUDOS_DISK}"
}

detect_tailscale() {
  if has_cmd tailscale; then
    if tailscale status 2>/dev/null | head -1 | grep -qiE "tailscale|direct|active|linux|windows"; then
      CLOUDOS_TAILSCALE="yes"
      CLOUDOS_TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
      CLOUDOS_TAILSCALE_HOSTNAME=$(tailscale status 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
      log_ok "Tailscale: ${CLOUDOS_TAILSCALE_IP} (${CLOUDOS_TAILSCALE_HOSTNAME})"
      return
    fi
    # Fallback: just check if tailscale ip returns something
    if tailscale ip -4 2>/dev/null | grep -q '^100\.'; then
      CLOUDOS_TAILSCALE="yes"
      CLOUDOS_TAILSCALE_IP=$(tailscale ip -4 2>/dev/null)
      CLOUDOS_TAILSCALE_HOSTNAME=$(tailscale status 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
      log_ok "Tailscale: ${CLOUDOS_TAILSCALE_IP} (${CLOUDOS_TAILSCALE_HOSTNAME})"
      return
    fi
  fi
  # Windows fallback — check registry or common paths
  if [ "$(get_os)" = "windows" ] && [ -f "/c/Program Files/Tailscale/tailscale.exe" ]; then
    CLOUDOS_TAILSCALE="yes"
    CLOUDOS_TAILSCALE_IP=$(/c/Program\ Files/Tailscale/tailscale.exe ip -4 2>/dev/null || echo "installed")
    CLOUDOS_TAILSCALE_HOSTNAME=$(/c/Program\ Files/Tailscale/tailscale.exe status 2>/dev/null | head -1 | awk '{print $2}' || echo "windows")
    log_ok "Tailscale: ${CLOUDOS_TAILSCALE_IP} (${CLOUDOS_TAILSCALE_HOSTNAME})"
  else
    CLOUDOS_TAILSCALE="no"
    log_info "Tailscale: not detected"
  fi
}

detect_network() {
  CLOUDOS_GATEWAY=""
  CLOUDOS_NAT="yes"
  
  if has_cmd ip; then
    CLOUDOS_GATEWAY=$(ip route | awk '/default/ {print $3}' 2>/dev/null)
  fi
  
  if [ -z "$CLOUDOS_GATEWAY" ]; then
    # Windows route print
    CLOUDOS_GATEWAY=$(netstat -rn 2>/dev/null | awk '/0.0.0.0/ {print $3}' | head -1)
  fi
  
  if [ -z "$CLOUDOS_GATEWAY" ]; then
    # From arp table
    CLOUDOS_GATEWAY=$(arp -a 2>/dev/null | head -5 | awk '{print $1}' | head -1)
  fi
  
  log_info "Gateway: ${CLOUDOS_GATEWAY:-unknown} | NAT: ${CLOUDOS_NAT}"
}

detect_existing_services() {
  CLOUDOS_SERVICES=""
  
  # Common self-hosted ports
  local -A service_ports=(
    [8069]="odoo"
    [8123]="homeassistant"
    [8096]="jellyfin"
    [8384]="syncthing"
    [22000]="syncthing-tcp"
    [9000]="portainer"
    [8080]="http-alt"
    [3000]="grafana"
    [9090]="prometheus"
    [5432]="postgresql"
    [3306]="mysql"
    [6379]="redis"
  )
  
  for port in "${!service_ports[@]}"; do
    if port_in_use "$port"; then
      CLOUDOS_SERVICES="${CLOUDOS_SERVICES}${service_ports[$port]}:${port} "
      log_ok "${service_ports[$port]} detected on port ${port}"
    fi
  done
  
  if [ -z "$CLOUDOS_SERVICES" ]; then
    log_info "No existing self-hosted services detected"
  fi
}

detect_all() {
  log_header "CloudOS — Environment Detection"
  
  detect_os
  detect_resources
  detect_docker
  detect_tailscale
  detect_network
  detect_existing_services
  
  log_step "Detection complete"
  
  # Summary
  echo -e "\n${BOLD}System Summary:${NC}"
  echo "  OS:        ${CLOUDOS_OS} (${CLOUDOS_ARCH})"
  echo "  RAM:       ${CLOUDOS_RAM_GB}GB"
  echo "  GPU:       ${CLOUDOS_GPU:-none}"
  echo "  Disk:      ${CLOUDOS_DISK:-unknown}"
  echo "  Docker:    ${CLOUDOS_DOCKER}"
  echo "  Tailscale: ${CLOUDOS_TAILSCALE}"
  echo "  NAT:       ${CLOUDOS_NAT}"
  
  if [ -n "$CLOUDOS_SERVICES" ]; then
    echo "  Services:  ${CLOUDOS_SERVICES}"
  fi
}

# Export for cloudos CLI
export CLOUDOS_OS CLOUDOS_ARCH CLOUDOS_DOCKER CLOUDOS_RAM_MB CLOUDOS_RAM_GB
export CLOUDOS_GPU CLOUDOS_DISK CLOUDOS_TAILSCALE CLOUDOS_TAILSCALE_IP
export CLOUDOS_GATEWAY CLOUDOS_NAT CLOUDOS_SERVICES CLOUDOS_LOCAL_IPS
