#!/usr/bin/env bash
# Utility functions for CloudOS

# Check if a command exists
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Check if Docker is running
docker_running() {
  has_cmd docker && docker info >/dev/null 2>&1
}

# Check if a port is in use
port_in_use() {
  if has_cmd ss; then
    ss -tlnp "sport = :$1" 2>/dev/null | grep -q LISTEN
  elif has_cmd netstat; then
    netstat -an 2>/dev/null | grep -qE ":$1 .*LISTEN"
  else
    return 1
  fi
}

# Get OS type
get_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux";;
    Darwin*) echo "macos";;
    MINGW*|MSYS*) echo "windows";;
    *)       echo "unknown";;
  esac
}

# Get architecture
get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64";;
    aarch64|arm64) echo "arm64";;
    armv7l)        echo "armv7";;
    *)             echo "$(uname -m)";;
  esac
}

# Detect package manager
get_pkg_manager() {
  has_cmd apt-get && echo "apt"
  has_cmd dnf && echo "dnf"
  has_cmd pacman && echo "pacman"
  has_cmd brew && echo "brew"
  has_cmd winget && echo "winget"
}

# Check if running in a container
is_container() {
  [ -f /.dockerenv ] && return 0
  grep -qE 'docker|lxc|containerd' /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

# Get total RAM in MB
get_ram_mb() {
  if has_cmd free; then
    free -m | awk '/^Mem:/ {print $2}'
  elif [ -f /proc/meminfo ]; then
    awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo
  else
    # Windows fallback — try wmic
    has_cmd wmic && wmic memorychip get capacity 2>/dev/null | awk 'NR>1 {s+=$1} END {printf "%d", s/1024/1024}' || echo "0"
  fi
}

# Check for GPU
has_gpu() {
  has_cmd nvidia-smi && nvidia-smi -L >/dev/null 2>&1 && echo "nvidia" && return 0
  [ -d /proc/dri ] && ls /proc/dri/*/name 2>/dev/null | head -1 | grep -qi "intel" && echo "intel" && return 0
  echo "none"
}

# Get GPU info
get_gpu_info() {
  local gpu_type
  gpu_type=$(has_gpu)
  case "$gpu_type" in
    nvidia)
      nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1
      ;;
    intel|none)
      echo "none"
      ;;
  esac
}

# Get disk info
get_disk_info() {
  local path="${1:-/}"
  if has_cmd df; then
    df -h "$path" 2>/dev/null | awk 'NR==2 {print $2, $4, $1}'
  else
    echo "unknown"
  fi
}

# Template renderer — replaces {{VAR}} with environment values
render_template() {
  local input="$1"
  local output="${2:-/dev/stdout}"
  
  if [ -f "$input" ]; then
    content=$(cat "$input")
  else
    content="$input"
  fi
  
  # Replace {{VARIABLE_NAME}} with env var values
  while echo "$content" | grep -q '{{[A-Z_]*}}'; do
    var=$(echo "$content" | sed -n 's/.*{{\([A-Z_]*\)}}.*/\1/p' | head -1)
    val=$(eval echo "\${$var:-}")
    content=$(echo "$content" | sed "s|{{${var}}}|${val}|g")
  done
  
  echo "$content" > "$output"
}

# Safe YAML parser (simple key-value)
parse_yaml() {
  local file="$1"
  local prefix="${2:-}"
  while IFS=': ' read -r key value; do
    [ -z "$key" ] && continue
    [[ "$key" =~ ^# ]] && continue
    key="${prefix}${key//-/_}"
    value="${value//\"/}"
    value="${value# }"
    eval "$key=\"$value\""
  done < "$file"
}
