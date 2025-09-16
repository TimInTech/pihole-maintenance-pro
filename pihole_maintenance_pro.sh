#!/usr/bin/env bash
# ============================================================================
# Pi-hole v6.x – Full Maintenance PRO MAX
# Version: 5.2.0 (2025-07-10)
# Authors: TimITech
#
# What’s new vs 5.1.2
#  - Fix backup block quoting (removed stray backslash + comment in heredoc)
#  - Stronger, faster backup (short, safe stop of FTL; tar with excludes)
#  - Clearer live progress: spinner shows last log line and PID; writes only to TTY
#  - Robust logging: all steps mirrored to /var/log + per-step logs in /tmp
#  - Safer Pi-hole v6 commands (reloaddns / reloadlists usage left intact)
#  - More diagnostics (ports, dig tests, top domains/clients via sqlite3)
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

# --------------------------- Paths & globals --------------------------------
TMPDIR="$(mktemp -d -t pihole_maint_XXXX)"
LOGFILE="/var/log/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
trap 'rm -rf "$TMPDIR"; [[ -t 1 ]] && echo -e "${YELLOW}Temporary logs removed: $TMPDIR${NC}" || true' EXIT

# All stdout/stderr to logfile AND console
exec > >(tee -a "$LOGFILE") 2>&1

declare -A STATUS        # step -> status
declare -A STEP_LOGFILE  # step -> step logfile

# --------------------------- Utils -----------------------------------------
strip_ansi() { sed -r $'s/\x1B\[[0-9;]*[a-zA-Z]//g' | tr -d '\r'; }

echo_hdr() {
  [[ -t 1 ]] && clear || true
  echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${MAGENTA}║${NC}   🛰️  ${BOLD}PI-HOLE MAINTENANCE PRO MAX${NC}${MAGENTA}  -  TimInTech  (${CYAN}v5.2.0${MAGENTA})  ║${NC}"
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

  if [[ "$display_only" == "true" ]]; then
    if bash -lc "$cmd" 2>&1 | tee /dev/tty | strip_ansi >"$step_log"; then
      echo -e "${CHECK} Success"; STATUS["$n"]="${GREEN}✔ OK${NC}"
    else
      echo -e "${WARN} Warning"; STATUS["$n"]="${YELLOW}⚠ WARN${NC}"; [[ -s "$step_log" ]] && tail -n 20 "$step_log"
      [[ "$critical" == "true" ]] && echo -e "${RED}[ERROR] Kritischer Fehler – Abbruch${NC}" && exit 1
    fi; return 0
  fi

  bash -lc "$cmd" 2>&1 | strip_ansi >"$step_log" &
  local pid=$!

  (
    local out="/dev/tty"; [[ ! -t 1 || ! -w $out ]] && out="/dev/null"
    local spin='⠋⠙⠸⠴⠦⠇'; local i=0
    while kill -0 "$pid" 2>/dev/null; do
      local last=""; [[ -f "$step_log" ]] && last="$(tail -n1 "$step_log" | cut -c1-80)"
      printf '\r%s%s%s %s[PID:%s]%s %s' "$CYAN" "${last}" "$NC" "$BLUE" "$pid" "$NC" "${spin:i++%${#spin}:1}" >"$out" 2>/dev/null || true
      sleep 0.25
    done
    printf '\r' >"$out" 2>/dev/null || true
  ) &

  if wait "$pid"; then
    echo -e "\n${CHECK} Success"; STATUS["$n"]="${GREEN}✔ OK${NC}"
  else
    local ec=$?; echo -e "\n${FAIL} Error (code: $ec)"; STATUS["$n"]="${RED}✖ FAIL${NC}"; [[ -f "$step_log" ]] && tail -n 50 "$step_log"
    [[ "$critical" == "true" ]] && echo -e "${RED}[ERROR] Kritischer Fehler in Step ${n}${NC}" && exit $ec
  fi
}

# Helper: wait for service active
wait_active() {
  local unit="$1"; local timeout="${2:-15}"; local t=0
  while (( t < timeout )); do
    systemctl is-active --quiet "$unit" && return 0
    sleep 1; ((t++))
  done
  return 1
}

# Helper: show summary
summary() {
  echo -e "\n${MAGENTA}════════ SUMMARY ════════${NC}"
  for k in "${!STATUS[@]}"; do
    printf '  %-4s %b\n' "#${k}" "${STATUS[$k]}"
  done
  echo -e "Log: ${CYAN}$LOGFILE${NC}"
  echo -e "Step logs: ${CYAN}$TMPDIR${NC} (werden beim Exit gelöscht)"
}

# Detect databases
FTL_DB=""; for c in \
  "/etc/pihole/pihole-FTL.db" \
  "/run/pihole-FTL.db" \
  "/var/lib/pihole/pihole-FTL.db"; do [[ -f "$c" ]] && FTL_DB="$c" && break; done
GRAVITY_DB="/etc/pihole/gravity.db"

# --------------------------- Run -------------------------------------------
echo_hdr

echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ SYSTEM UPDATE ▀▀▀▀▀▀▀▀▀▀▀█${NC}"
run_step 01 "🔄" "APT: update & upgrade" "apt update && apt -y upgrade" true
run_step 02 "🧹" "APT: autoremove & autoclean" "apt -y autoremove && apt -y autoclean"

# ARMv8 Paket Hinweis auf ARMv7 Systemen
if dpkg --print-architecture | grep -q '^armhf$'; then
  if apt list --upgradable 2>/dev/null | grep -q '^linux-image-rpi-v8'; then
    echo -e "${YELLOW}Hinweis:${NC} 'linux-image-rpi-v8' ist 64‑bit (ARMv8). Auf Pi 3B (ARMv7) ignorierbar."
  fi
fi

echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ PI-HOLE MAINTENANCE ▀▀▀▀▀▀▀▀▀▀▀█${NC}"
run_step 03 "🔎" "Pi-hole Version" "pihole -v" false true
run_step 04 "🆙" "Pi-hole self-update" "pihole -up"  
run_step 05 "📋" "Update Gravity / Blocklists" "pihole -g"

# --------------------------- Backup ----------------------------------------
BACKUP_TS="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="/var/backups/pihole_backup_${BACKUP_TS}"

run_step 06 "💾" "Backup Pi-hole (short FTL stop + tar)" $'\
  set -e; \
  echo "Backup dir: '""$BACKUP_DIR""'"; \
  mkdir -p "$BACKUP_DIR"; \
  svc=pihole-FTL.service; controlled=0; \
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files --type=service | awk "{print \$1}" | grep -Fxq "$svc"; then \
    if systemctl is-active --quiet "$svc"; then \
      echo "Stopping $svc ..."; systemctl stop "$svc"; controlled=1; fi; \
  fi; \
  echo "Creating tarball (/etc/pihole → $BACKUP_DIR/pihole_backup.tar.gz) ..."; \
  tar -C /etc -czf "$BACKUP_DIR/pihole_backup.tar.gz" \
      --warning=no-file-changed \
      --exclude="pihole-FTL.db-wal" \
      --exclude="pihole-FTL.db-shm" \
      --exclude="*.sock" \
      pihole; \
  echo "Tarball OK."; \
  if [[ $controlled -eq 1 ]]; then \
    echo "Starting $svc ..."; systemctl start "$svc"; \
    echo "Waiting service active ..."; systemctl is-active --quiet "$svc" || sleep 1; \
    for i in {1..15}; do systemctl is-active --quiet "$svc" && break; sleep 1; done; \
  fi; \
  echo "Backup done: $BACKUP_DIR"'

# --------------------------- DNS reload & health ----------------------------
run_step 07 "🔁" "Reload DNS (reloaddns)" "pihole reloaddns"

run_step 08 "🧪" "Health: port 53 listeners" $'\
  ss -lntup | awk \''/\:53\s/ {print}'\'' || true' true true

run_step 09 "🌐" "DNS test with dig (google.com)" $'\
  dig +short google.com @127.0.0.1 || true' false true

# --------------------------- Diagnostics (top) ------------------------------
if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$FTL_DB" ]]; then
  run_step 10 "📈" "Top 5 Domains (FTL)" $'\
    sqlite3 -readonly "$FTL_DB" "SELECT domain, COUNT(1) c FROM queries GROUP BY domain ORDER BY c DESC LIMIT 5;" || true' false true
  run_step 11 "👥" "Top 5 Clients (FTL)" $'\
    sqlite3 -readonly "$FTL_DB" "SELECT client, COUNT(1) c FROM queries GROUP BY client ORDER BY c DESC LIMIT 5;" || true' false true
else
  echo -e "${YELLOW}sqlite3 oder FTL DB nicht gefunden – Überspringe Top-Listen.${NC}"
fi

# --------------------------- Summary ---------------------------------------
summary

echo -e "${GREEN}Done.${NC}"
