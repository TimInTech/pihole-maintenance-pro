#!/usr/bin/env bash
# ============================================================================
# Pi-hole Maintenance PRO - Utility Functions Library
# Version: 5.3.2
# ============================================================================

# Arrays used across modules (declared in main script)
# shellcheck disable=SC2034  # Variables exported/used by main script

# Color and symbol definitions
init_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
  else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    BOLD=""
    NC=""
  fi
  CHECK="${GREEN}✔${NC}"
  WARN="${YELLOW}⚠${NC}"
  FAIL="${RED}✖${NC}"
}

# Strip ANSI escape sequences from input
strip_ansi() {
  sed -r $'s/\x1B\[[0-9;]*[a-zA-Z]//g' | tr -d '\r'
}

# Print header banner
echo_hdr() {
  if [[ -t 1 ]]; then clear; fi
  echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${MAGENTA}║${NC}   🛰️  ${BOLD}PI-HOLE MAINTENANCE PRO MAX${NC}${MAGENTA}  -  TimInTech  (${CYAN}v5.3.2${MAGENTA})  ║${NC}"
  echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════════════════╣${NC}"
  if "$PIHOLE_BIN" -v > /dev/null 2>&1; then
    PH_VER="$("$PIHOLE_BIN" -v 2> /dev/null || true)"
    echo -e "${MAGENTA}║${NC} Version: ${CYAN}${PH_VER:-unbekannt}${NC}"
  else
    echo -e "${MAGENTA}║${NC} ${YELLOW}Pi-hole CLI nicht gefunden${NC}"
  fi
  echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Extract relevant data from step output
extract_step_data() {
  local step_num="$1" output="$2"
  # shellcheck disable=SC2034,SC2154  # STEP_DATA used/assigned in main script
  # shellcheck disable=SC2080  # Case patterns with leading zeros are string matches, not octal
  case "$step_num" in
    00) STEP_DATA[00_ip]=$(echo "$output" | grep -oE '192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+' | head -1) ;;
    03) STEP_DATA[03_version]=$(echo "$output" | grep "Core version" | awk '{print $4}') ;;
    07) STEP_DATA[07_listeners]=$(echo "$output" | wc -l) ;;
    08) STEP_DATA[08_response]=$(echo "$output" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) ;;
    09) STEP_DATA[09_response]=$(echo "$output" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) ;;
    10) STEP_DATA[10_github]=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) ;;
  esac
}

# Get human-readable step description
get_step_description() {
  case "$1" in
    01) echo "📦 APT Updates" ;;
    04) echo "🆙 Pi-hole Update" ;;
    05) echo "📋 Gravity Update" ;;
    06) echo "🔁 DNS Reload" ;;
    *) echo "Step $1" ;;
  esac
}
