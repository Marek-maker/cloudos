# Colors for pretty output
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  GRAY='\033[0;90m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; GRAY=''; BOLD=''; NC=''
fi

log_info()  { echo -e "${BLUE}ℹ${NC} $*"; }
log_ok()    { echo -e "${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_step()  { echo -e "\n${BOLD}${CYAN}==>${NC} ${BOLD}$*${NC}"; }
log_debug() { [ -n "$CLOUDOS_DEBUG" ] && echo -e "${GRAY}DEBUG:${NC} $*"; }
log_header() {
  echo -e "${BOLD}${MAGENTA}"
  echo "  ╔══════════════════════════════════════╗"
  printf "  ║  %-38s║\n" "$*"
  echo "  ╚══════════════════════════════════════╝"
  echo -e "${NC}"
}
