#!/usr/bin/env bash
# ============================================================================
# Pi-hole v6.x – Full Maintenance PRO MAX  (NO-BACKUP EDITION)
# Version: 5.3.1 (2025-10-05)
# Authors: TimInTech
# ----------------------------------------------------------------------------
# Changelog v5.3.1 (2025-10-05) - Major Enhancement Release
#  • NEW: Intelligent Summary mit echten Daten statt nur "OK"
#  • NEW: Performance Dashboard (CPU Load, RAM, Disk, Temperatur)
#  • NEW: Smart Data Collection (IP, DNS-Zeiten, FTL-Statistiken)
#  • NEW: Intelligente Warnungen und automatische Empfehlungen
#  • NEW: JSON Output Mode (--json) für Monitoring-Integration
#  • NEW: 24h Query-Analytics aus FTL-Datenbank
#  • Enhanced: Erweiterte Step-Reports mit kontextuellen Informationen
#  • Enhanced: Robuste Datenextraktion und Performance-Bewertung
#
# Changelog v5.3.0 (vs 5.2.0)
#  • Entfernt: kompletter Backup/FTL-Stop-Block (häufige Hänger → rausgenommen)
#  • Neues, klares Step-Framework mit Spinner + Live-Output (TTY‑sicher)
#  • Optional-Flags: --no-apt, --no-upgrade, --no-gravity, --no-dnsreload
#  • Extra-Diagnostik: Port‑53‑Check, dig‑Tests, GitHub‑Reachability, Tailscale‑Info
#  • Saubere Logs: /var/log/pihole_maintenance_pro_<timestamp>.log (+ per‑Step)
#  • 100% Pi‑hole v6‑kompatible Kommandos (pihole -up, -g, reloaddns)
# ============================================================================
set -euo pipefail
IFS=$'\n\t'

# --------------------------- Colors & symbols -------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; BOLD=""; NC=""
fi
CHECK="${GREEN}✔${NC}"; WARN="${YELLOW}⚠${NC}"; FAIL="${RED}✖${NC}"

# --------------------------- Root check ------------------------------------
if [[ ${EUID} -ne 0 ]]; then
  echo -e "${RED}[ERROR]${NC} Bitte mit sudo oder als root ausführen." >&2
  exit 1
fi

# --------------------------- Args ------------------------------------------
DO_APT=1; DO_UPGRADE=1; DO_GRAVITY=1; DO_DNSRELOAD=1; JSON_OUTPUT=0
while (( "$#" )); do
  case "${1}" in
    --no-apt) DO_APT=0 ; shift ;;
    --no-upgrade) DO_UPGRADE=0 ; shift ;;
    --no-gravity) DO_GRAVITY=0 ; shift ;;
    --no-dnsreload) DO_DNSRELOAD=0 ; shift ;;
    --json) JSON_OUTPUT=1 ; shift ;;
    -h|--help)
      cat <<EOF
Usage: sudo ./pihole_maintenance_pro.sh [options]
  --no-apt         Skip apt update/upgrade/autoremove
  --no-upgrade     Skip "pihole -up"
  --no-gravity     Skip "pihole -g"
  --no-dnsreload   Skip "pihole reloaddns"
  --json           Output results in JSON format
EOF
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# --------------------------- Paths & globals --------------------------------
TMPDIR="$(mktemp -d -t pihole_maint_XXXX)"
# Prefer /var/log but fallback to $TMPDIR if not writable (avoid silent failures)
LOGDIR="/var/log"
if [[ -d "$LOGDIR" && -w "$LOGDIR" ]]; then
  LOGFILE="$LOGDIR/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
else
  LOGFILE="$TMPDIR/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
  echo -e "${YELLOW}Hinweis:${NC} /var/log nicht verfügbar oder nicht beschreibbar, Log wird nach $TMPDIR geschrieben."
fi

# Minimal cleanup trap until a fuller trap (with summary) is set later
trap 'rm -rf "$TMPDIR" 2>/dev/null || true' EXIT

# All stdout/stderr to logfile AND console (tee may fail if LOGFILE dir missing; handled above)
exec > >(tee -a "$LOGFILE") 2>&1

declare -A STATUS        # step -> status
declare -A STEP_LOGFILE  # step -> step logfile

# Enhanced data collection for intelligent summary
declare -A STEP_DATA
declare -A PERFORMANCE_DATA

# --------------------------- Utils -----------------------------------------
strip_ansi() { sed -r $'s/\x1B\[[0-9;]*[a-zA-Z]//g' | tr -d '\r'; }

echo_hdr() {
  # TTY-sicheres Clear (SC2015 vermeiden)
  if [[ -t 1 ]]; then
    clear
  fi
  echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${MAGENTA}║${NC}   🛰️  ${BOLD}PI-HOLE MAINTENANCE PRO MAX${NC}${MAGENTA}  -  TimInTech  (${CYAN}v5.3.1${MAGENTA})  ║${NC}"
  echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════════════════╣${NC}"
  if command -v pihole >/dev/null 2>&1; then
    PH_VER="$(pihole -v 2>/dev/null || true)"
    echo -e "${MAGENTA}║${NC} Version: ${CYAN}${PH_VER:-unbekannt}${NC}"
  else
    echo -e "${MAGENTA}║${NC} ${YELLOW}Pi-hole CLI nicht gefunden${NC}"
  fi
  echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════╝${NC}"
}

run_step() {
  # $1 num, $2 icon, $3 title, $4 cmd, $5 critical(true/false), $6 display_only(true/false)
  local n="$1"; local icon="$2"; local title="$3"; local cmd="$4"; local critical="${5:-false}"; local display_only="${6:-false}"
  local step_log="$TMPDIR/step_${n}.log"; STEP_LOGFILE["$n"]="$step_log"

  echo -e "\n${BLUE}╔═[Step ${n}]${NC}"
  echo -e "${BLUE}║ ${icon} ${title}${NC}"
  echo -en "${BLUE}╚═>${NC} "

  # determine output device for live display (safe if no TTY)
  local out="/dev/null"
  if [[ -t 1 ]]; then
    # /dev/tty may not be writable in some containerized environments; fallback to stdout
    if [[ -w /dev/tty ]]; then out="/dev/tty"; else out="/dev/stdout"; fi
  fi

  if [[ "$display_only" == "true" ]]; then
    # show live output when possible, but always capture to step_log (no ANSI sequences)
    if bash -lc "$cmd" 2>&1 | tee -a "$out" | strip_ansi >"$step_log"; then
      echo -e "${CHECK} Success"; STATUS["$n"]="${GREEN}✔ OK${NC}"
      # Collect data from successful display_only steps
      [[ -f "$step_log" ]] && extract_step_data "$n" "$(cat "$step_log")"
    else
      echo -e "${WARN} Warning"; STATUS["$n"]="${YELLOW}⚠ WARN${NC}"; [[ -s "$step_log" ]] && tail -n 20 "$step_log"
      [[ "$critical" == "true" ]] && echo -e "${RED}[ERROR] Kritischer Fehler – Abbruch${NC}" && exit 1
    fi; return 0
  fi

  # backgrounded execution with spinner and last-line preview
  bash -lc "$cmd" 2>&1 | strip_ansi >"$step_log" &
  local pid=$!

  (
    # Spinner als Array (sicher mit Multibyte‑Glyphen)
    local spin_chars=( '⠋' '⠙' '⠸' '⠴' '⠦' '⠇' )
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
      local last="" ch idx
      [[ -f "$step_log" ]] && last="$(tail -n1 "$step_log" | cut -c1-80)"
      idx=$(( i % ${#spin_chars[@]} ))
      ch="${spin_chars[$idx]}"
      i=$(( i + 1 ))
      printf '\r%s%s%s %s[PID:%s]%s %s' "$CYAN" "${last}" "$NC" "$BLUE" "$pid" "$NC" "$ch" >"$out" 2>/dev/null || true
      sleep 0.25
    done
    printf '\r' >"$out" 2>/dev/null || true
  ) &

  if wait "$pid"; then
    echo -e "\n${CHECK} Success"; STATUS["$n"]="${GREEN}✔ OK${NC}"
    # Collect data from successful steps
    [[ -f "$step_log" ]] && extract_step_data "$n" "$(cat "$step_log")"
  else
    local ec=$?; echo -e "\n${FAIL} Error (code: $ec)"; STATUS["$n"]="${RED}✖ FAIL${NC}"; [[ -f "$step_log" ]] && tail -n 50 "$step_log"
    [[ "$critical" == "true" ]] && echo -e "${RED}[ERROR] Kritischer Fehler in Step ${n}${NC}" && exit $ec
  fi
}

# Performance data collection functions
collect_system_info() {
  PERFORMANCE_DATA[load]=$(uptime | awk -F'load average: ' '{print $2}' | cut -d',' -f1 | xargs)
  PERFORMANCE_DATA[memory]=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}' 2>/dev/null || echo "N/A")
  PERFORMANCE_DATA[disk]=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  [[ -f /sys/class/thermal/thermal_zone0/temp ]] && PERFORMANCE_DATA[temp]=$(($(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)/1000)) || PERFORMANCE_DATA[temp]="N/A"
}

# Enhanced data extraction from step outputs
extract_step_data() {
  local step_num="$1" output="$2"
  case "$step_num" in
    00) # Network context
      STEP_DATA[00_ip]=$(echo "$output" | grep -oE '192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+' | head -1)
      ;;
    03) # Pi-hole version
      STEP_DATA[03_version]=$(echo "$output" | grep "Core version" | awk '{print $4}')
      ;;
    07) # Port 53 listeners
      STEP_DATA[07_listeners]=$(echo "$output" | wc -l)
      ;;
    08) # External DNS test
      STEP_DATA[08_response]=$(echo "$output" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
      ;;
    09) # Local DNS test
      STEP_DATA[09_response]=$(echo "$output" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
      ;;
    10) # GitHub reachability
      STEP_DATA[10_github]=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
      ;;
  esac
}

# Intelligent summary with real data
summary() {
  # Collect performance data
  collect_system_info
  
  echo
  echo -e "${CYAN}╔═══════════════ PERFORMANCE DASHBOARD ═══════════════╗${NC}"
  printf "${CYAN}║${NC} 🚀 Load: %-8s 💾 RAM: %s%%    🌡️  Temp: %s°C    🗄️  Disk: %s%% ${CYAN}║${NC}\n" \
    "${PERFORMANCE_DATA[load]:-"N/A"}" \
    "${PERFORMANCE_DATA[memory]:-"N/A"}" \
    "${PERFORMANCE_DATA[temp]:-"N/A"}" \
    "${PERFORMANCE_DATA[disk]:-"N/A"}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
  
  echo
  echo -e "${MAGENTA}════════ INTELLIGENT SUMMARY ════════${NC}"
  
  # Enhanced step reporting with collected data
  for k in $(printf '%s\n' "${!STATUS[@]}" | sort -n); do
    local status_icon="${STATUS[$k]}"
    local step_info=""
    
    case "$k" in
      00) step_info="🌍 Network    ${STEP_DATA[00_ip]:+"IP: ${STEP_DATA[00_ip]}"}" ;;
      03) step_info="🛡️  Pi-hole    ${STEP_DATA[03_version]:+"v${STEP_DATA[03_version]}"}" ;;
      07) step_info="🔍 Health     ${STEP_DATA[07_listeners]:+"${STEP_DATA[07_listeners]} listeners"}" ;;
      08) step_info="🌐 DNS Ext    ${STEP_DATA[08_response]:+"${STEP_DATA[08_response]}"}" ;;
      09) step_info="🏠 DNS Local  ${STEP_DATA[09_response]:+"${STEP_DATA[09_response]}"}" ;;
      10) step_info="📡 GitHub     ${STEP_DATA[10_github]:+"${STEP_DATA[10_github]}"}" ;;
      12) step_info="📊 FTL Query  $(get_query_summary)" ;;
      13) step_info="👥 FTL Client $(get_client_summary)" ;;
      *) step_info="$(get_step_description "$k")" ;;
    esac
    
    printf '  %-4s %-50s %s\n' "#${k}" "$step_info" "$status_icon"
  done
  
  # Performance warnings
  echo
  show_recommendations
  
  echo -e "Log: ${CYAN}$LOGFILE${NC}"
  echo -e "Step logs: ${CYAN}$TMPDIR${NC} (werden beim Exit gelöscht)"
}

# Get step descriptions for unmapped steps
get_step_description() {
  case "$1" in
    01) echo "📦 APT Updates" ;;
    04) echo "🆙 Pi-hole Update" ;;
    05) echo "📋 Gravity Update" ;;
    06) echo "🔁 DNS Reload" ;;
    *) echo "Step $1" ;;
  esac
}

# Extract query summary from FTL database
get_query_summary() {
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 >/dev/null 2>&1; then
    local total_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s', 'now', '-24 hours');" 2>/dev/null || echo "0")
    local blocked_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s', 'now', '-24 hours') AND status IN (1,4,5,6,7,8,9,10,11);" 2>/dev/null || echo "0")
    if [[ "$total_queries" -gt 0 ]]; then
      local blocked_percent=$(( blocked_queries * 100 / total_queries ))
      echo "24h: ${total_queries} queries, ${blocked_percent}% blocked"
    else
      echo "No recent data"
    fi
  else
    echo "DB not available"
  fi
}

# Extract client summary from FTL database  
get_client_summary() {
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 >/dev/null 2>&1; then
    local unique_clients=$(sqlite3 "$FTL_DB" "SELECT COUNT(DISTINCT client) FROM queries WHERE timestamp > strftime('%s', 'now', '-24 hours');" 2>/dev/null || echo "0")
    echo "${unique_clients} active clients"
  else
    echo "DB not available"
  fi
}

# Smart recommendations based on collected data
show_recommendations() {
  local warnings=()
  local recommendations=()
  
  # Performance warnings
  if [[ "${PERFORMANCE_DATA[memory]}" =~ ^[0-9]+$ ]] && (( PERFORMANCE_DATA[memory] > 85 )); then
    warnings+=("⚠️  High memory usage: ${PERFORMANCE_DATA[memory]}%")
    recommendations+=("💡 Consider restarting FTL service or increasing RAM")
  fi
  
  if [[ "${PERFORMANCE_DATA[disk]}" =~ ^[0-9]+$ ]] && (( PERFORMANCE_DATA[disk] > 85 )); then
    warnings+=("⚠️  Low disk space: ${PERFORMANCE_DATA[disk]}% used")
    recommendations+=("💡 Consider log rotation or cleanup: pihole -f")
  fi
  
  if [[ "${PERFORMANCE_DATA[temp]}" =~ ^[0-9]+$ ]] && (( PERFORMANCE_DATA[temp] > 70 )); then
    warnings+=("🌡️  High temperature: ${PERFORMANCE_DATA[temp]}°C")
    recommendations+=("💡 Check cooling and ventilation")
  fi
  
  # Network warnings
  if [[ "${STEP_DATA[07_listeners]}" =~ ^[0-9]+$ ]] && (( STEP_DATA[07_listeners] < 1 )); then
    warnings+=("🔥 CRITICAL: No DNS listeners on port 53")
    recommendations+=("🚨 Restart Pi-hole FTL: sudo systemctl restart pihole-FTL")
  fi
  
  # Display warnings and recommendations
  if (( ${#warnings[@]} > 0 )); then
    echo -e "\n${YELLOW}════════ WARNINGS ════════${NC}"
    printf '%s\n' "${warnings[@]}"
  fi
  
  if (( ${#recommendations[@]} > 0 )); then
    echo -e "\n${BLUE}════════ RECOMMENDATIONS ════════${NC}"
    printf '%s\n' "${recommendations[@]}"
  fi
}

# JSON output function for monitoring integration
output_json() {
  collect_system_info
  
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local total_steps=${#STATUS[@]}
  local successful_steps=0
  local failed_steps=0
  local warned_steps=0
  
  # Count step statuses
  for status in "${STATUS[@]}"; do
    if [[ "$status" == *"OK"* ]]; then
      ((successful_steps++))
    elif [[ "$status" == *"FAIL"* ]]; then
      ((failed_steps++))
    elif [[ "$status" == *"WARN"* ]]; then
      ((warned_steps++))
    fi
  done
  
  # Determine overall status
  local overall_status="healthy"
  if (( failed_steps > 0 )); then
    overall_status="critical"
  elif (( warned_steps > 0 )); then
    overall_status="warning"
  fi
  
  # Extract query stats
  local total_queries=0
  local blocked_queries=0
  local blocked_percentage=0
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 >/dev/null 2>&1; then
    total_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s', 'now', '-24 hours');" 2>/dev/null || echo "0")
    blocked_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s', 'now', '-24 hours') AND status IN (1,4,5,6,7,8,9,10,11);" 2>/dev/null || echo "0")
    if [[ "$total_queries" -gt 0 ]]; then
      blocked_percentage=$(awk "BEGIN {printf \"%.1f\", $blocked_queries/$total_queries*100}")
    fi
  fi
  
  # Build issues and recommendations arrays
  local issues=()
  local recommendations=()
  
  if [[ "${PERFORMANCE_DATA[memory]}" =~ ^[0-9]+$ ]] && (( PERFORMANCE_DATA[memory] > 85 )); then
    issues+=("high_memory")
    recommendations+=("restart_ftl")
  fi
  
  if [[ "${PERFORMANCE_DATA[disk]}" =~ ^[0-9]+$ ]] && (( PERFORMANCE_DATA[disk] > 85 )); then
    issues+=("low_disk_space")
    recommendations+=("log_rotation")
  fi
  
  if [[ "${STEP_DATA[07_listeners]}" =~ ^[0-9]+$ ]] && (( STEP_DATA[07_listeners] < 1 )); then
    issues+=("no_dns_listeners")
    recommendations+=("restart_pihole_ftl")
  fi
  
  # Generate JSON output
  cat <<EOF
{
  "timestamp": "$timestamp",
  "status": "$overall_status",
  "version": "5.3.1",
  "summary": {
    "total_steps": $total_steps,
    "successful_steps": $successful_steps,
    "failed_steps": $failed_steps,
    "warned_steps": $warned_steps,
    "total_queries_24h": $total_queries,
    "blocked_queries_24h": $blocked_queries,
    "blocked_percentage": $blocked_percentage,
    "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')]$( [[ ${#issues[@]} -gt 0 ]] && echo "," || echo "" )
    "recommendations": [$(printf '"%s",' "${recommendations[@]}" | sed 's/,$//')]
  },
  "performance": {
    "load_average": "${PERFORMANCE_DATA[load]:-"N/A"}",
    "memory_usage_percent": ${PERFORMANCE_DATA[memory]:-0},
    "disk_usage_percent": ${PERFORMANCE_DATA[disk]:-0},
    "temperature_celsius": "${PERFORMANCE_DATA[temp]:-"N/A"}"
  },
  "network": {
    "local_ip": "${STEP_DATA[00_ip]:-"N/A"}",
    "dns_listeners": ${STEP_DATA[07_listeners]:-0},
    "external_dns_response": "${STEP_DATA[08_response]:-"N/A"}",
    "local_dns_response": "${STEP_DATA[09_response]:-"N/A"}",
    "github_connectivity": "${STEP_DATA[10_github]:-"N/A"}"
  },
  "pihole": {
    "version": "${STEP_DATA[03_version]:-"N/A"}",
    "gravity_last_update": "$(stat -c %Y /etc/pihole/gravity.db 2>/dev/null || echo 0)"
  },
  "logs": {
    "main_log": "$LOGFILE",
    "step_logs": "$TMPDIR"
  }
}
EOF
}

# Detect databases (best-effort)
FTL_DB=""; for c in \
  "/etc/pihole/pihole-FTL.db" \
  "/run/pihole-FTL.db" \
  "/var/lib/pihole/pihole-FTL.db"; do [[ -f "$c" ]] && FTL_DB="$c" && break; done
GRAVITY_DB="/etc/pihole/gravity.db"

# Install a final trap that shows summary and cleans TMPDIR (overrides earlier simple trap)
trap 'rc=$?; echo ""; summary 2>/dev/null || true; rm -rf "$TMPDIR" 2>/dev/null || true; [[ $rc -ne 0 ]] && echo -e "${RED}Script ended with exit code $rc${NC}"; exit $rc' EXIT

# --------------------------- Run -------------------------------------------
echo_hdr

# 00 – Quick context
run_step 00 "🧭" "Kontext: Host & Netz" $'\
  echo "Host: $(hostname)"; \
  echo "Kernel: $(uname -r)"; \
  echo "Arch: $(dpkg --print-architecture)"; \
  ip -4 addr show scope global | awk "/inet /{print \$2, \"on\", \$NF}"; \
  echo "Default route:"; ip route show default || true; \
  echo "DNS servers (/etc/resolv.conf):"; grep -E "^nameserver" /etc/resolv.conf || true' false true

# 01 – APT update/upgrade/autoclean (optional)
if (( DO_APT == 1 )); then
  # run apt non-interactive to avoid prompts on unattended systems
  export DEBIAN_FRONTEND=noninteractive
  run_step 01 "🔄" "APT: update & upgrade" "apt update && apt -y upgrade" true
  run_step 02 "🧹" "APT: autoremove & autoclean" "apt -y autoremove && apt -y autoclean"
  if dpkg --print-architecture | grep -q '^armhf$'; then
    if apt list --upgradable 2>/dev/null | grep -q '^linux-image-rpi-v8'; then
      echo -e "${YELLOW}Hinweis:${NC} 'linux-image-rpi-v8' ist 64‑bit (ARMv8). Auf Pi 3B (ARMv7) ignorierbar."
    fi
  fi
else
  echo -e "${YELLOW}APT‑Schritte übersprungen (--no-apt).${NC}"
fi

# 03 – Pi-hole Version & Updates
run_step 03 "🔎" "Pi-hole Version" "pihole -v" false true
if (( DO_UPGRADE == 1 )); then
  run_step 04 "🆙" "Pi-hole self-update" "pihole -up"
else
  echo -e "${YELLOW}Pi-hole Upgrade übersprungen (--no-upgrade).${NC}"
fi

# 05 – Gravity
if (( DO_GRAVITY == 1 )); then
  run_step 05 "📋" "Update Gravity / Blocklists" "pihole -g"
else
  echo -e "${YELLOW}Gravity-Update übersprungen (--no-gravity).${NC}"
fi

# 06 – DNS reload
if (( DO_DNSRELOAD == 1 )); then
  run_step 06 "🔁" "Reload DNS (reloaddns)" "pihole reloaddns"
else
  echo -e "${YELLOW}DNS-Reload übersprungen (--no-dnsreload).${NC}"
fi

# 07 – Health: Port 53 & basic dig
run_step 07 "🧪" "Health: Port 53 listeners" "ss -lntup | awk '/:53[[:space:]]/ {print}' || true" false true
run_step 08 "🌐" "DNS Test: google.com @127.0.0.1" $'dig +time=2 +tries=1 +short google.com @127.0.0.1 || true' false true
run_step 09 "🏠" "DNS Test: pi.hole @127.0.0.1" $'dig +time=2 +tries=1 +short pi.hole @127.0.0.1 || true' false true

# 10 – GitHub Reachability (häufiges Problem bei Updates/Wget)
run_step 10 "🐙" "GitHub Reachability" $'\
  dig +time=2 +tries=1 +short raw.githubusercontent.com @127.0.0.1 || true; \
  echo "curl -I https://raw.githubusercontent.com (IPv4)"; \
  curl -4 -sI https://raw.githubusercontent.com | head -n 1 || true' false true

# 11 – Tailscale (nur anzeigen, falls vorhanden)
if command -v tailscale >/dev/null 2>&1; then
  run_step 11 "🧩" "Tailscale Status (Kurz)" $'\
    echo -n "TS IPv4: "; tailscale ip -4 2>/dev/null || true; \
    echo -n "TS IPv6: "; tailscale ip -6 2>/dev/null || true; \
    tailscale status --peers=false 2>/dev/null || tailscale status 2>/dev/null || true' false true
fi

# 12 – FTL Toplists (falls DB da)
if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$FTL_DB" ]]; then
  run_step 12 "📈" "Top 5 Domains (FTL)" $'\
    sqlite3 -readonly "$FTL_DB" "SELECT domain, COUNT(1) c FROM queries GROUP BY domain ORDER BY c DESC LIMIT 5;" || true' false true
  run_step 13 "👥" "Top 5 Clients (FTL)" $'\
    sqlite3 -readonly "$FTL_DB" "SELECT client, COUNT(1) c FROM queries GROUP BY client ORDER BY c DESC LIMIT 5;" || true' false true
else
  echo -e "${YELLOW}sqlite3 oder FTL DB nicht gefunden – Überspringe Top-Listen.${NC}"
fi

# 14 – Abschluss
if [[ "$JSON_OUTPUT" == "1" ]]; then
  output_json
else
  summary
fi

echo -e "${GREEN}Done.${NC}"

# 🧪 Optionaler Repo-Selftest (nur bei RUN_SELFTEST=1)
if [[ "${RUN_SELFTEST:-0}" == "1" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEST_SCRIPT="${SCRIPT_DIR}/scripts/test-repo.sh"
  if [[ -f "$TEST_SCRIPT" ]]; then
    echo "Führe Repository-Selftest aus..."
    # Kein sudo, keine produktiven Pi-hole Calls im Dev-Kontext
    bash "$TEST_SCRIPT" || echo "Selftest fehlgeschlagen"
  else
    echo "Selftest übersprungen (scripts/test-repo.sh nicht gefunden)"
  fi
fi
