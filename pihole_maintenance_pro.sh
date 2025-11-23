#!/usr/bin/env bash
# ============================================================================
# Pi-hole v6.x – Full Maintenance PRO MAX  (NO-BACKUP EDITION)
# Version: 5.3.2 (2025-10-10)
# Authors: TimInTech
# ----------------------------------------------------------------------------
# v5.3.2
#  • FIX: Robuste Autodetektion der 'pihole' CLI + Wrapper 'ph'
#  • Doku: Cron-PATH Hinweis (README*), damit v6 auf Trixie unter cron läuft
#  • Cleanup: Doppelte BACKUP_DIR-Zuweisung entfernt
#
# v5.3.1
#  • Intelligent Summary, Performance Dashboard, JSON-Output, FTL-Analytics
# v5.3.0
#  • Neues Step-Framework, optionale Flags, Healthchecks, saubere Logs
# ============================================================================
set -euo pipefail
IFS=$'\n\t'

# Voller PATH für cron/Nicht-Login-Shells (früh setzen)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# --------------------------- Load library modules ---------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source library modules if available (fall back to inline definitions)
if [[ -d "$LIB_DIR" ]]; then
  # shellcheck source=lib/utils.sh
  [[ -f "$LIB_DIR/utils.sh" ]] && source "$LIB_DIR/utils.sh"
  # shellcheck source=lib/system.sh
  [[ -f "$LIB_DIR/system.sh" ]] && source "$LIB_DIR/system.sh"
  # shellcheck source=lib/pihole.sh
  [[ -f "$LIB_DIR/pihole.sh" ]] && source "$LIB_DIR/pihole.sh"
  # shellcheck source=lib/output.sh
  [[ -f "$LIB_DIR/output.sh" ]] && source "$LIB_DIR/output.sh"
  # shellcheck source=lib/steps.sh
  [[ -f "$LIB_DIR/steps.sh" ]] && source "$LIB_DIR/steps.sh"
fi

# --------------------------- Colors & symbols -------------------------------
# Initialize colors (from utils.sh or inline)
if declare -f init_colors > /dev/null 2>&1; then
  init_colors
else
  # Fallback inline color definitions
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
fi

# --------------------------- Root check ------------------------------------
# Für sicheren lokalen Selftest (RUN_SELFTEST=1) ohne Root erlauben
if [[ ${EUID} -ne 0 ]]; then
  if [[ "${RUN_SELFTEST:-0}" == "1" ]]; then
    echo -e "${YELLOW}Hinweis:${NC} RUN_SELFTEST=1 erkannt – Root-Check übersprungen (APT/Upgrade/Gravity sollten via --no-* Flags deaktiviert sein)."
  else
    echo -e "${RED}[ERROR]${NC} Bitte mit sudo oder als root ausführen." >&2
    exit 1
  fi
fi

# --------------------------- Args ------------------------------------------
DO_APT=1
DO_UPGRADE=1
DO_GRAVITY=1
# shellcheck disable=SC2034  # legacy flag (kept for help text compatibility)
DO_DNSRELOAD=1 # no-op on v6, retained for help text compatibility
JSON_OUTPUT=0
DO_BACKUP=0
RESTART_FTL=0
while (("$#")); do
  case "$1" in
    --no-apt)
      DO_APT=0
      shift
      ;;
    --no-upgrade)
      DO_UPGRADE=0
      shift
      ;;
    --no-gravity)
      DO_GRAVITY=0
      shift
      ;;
    --no-dnsreload)
      # shellcheck disable=SC2034  # legacy flag retained for help text compatibility
      DO_DNSRELOAD=0
      shift
      ;;
    --restart-ftl)
      RESTART_FTL=1
      shift
      ;;
    --backup)
      DO_BACKUP=1
      shift
      ;;
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    -h | --help)
      cat << 'EOF'
Usage: sudo ./pihole_maintenance_pro.sh [options]
  --no-apt         Skip apt update/upgrade/autoremove
  --no-upgrade     Skip "pihole -up"
  --no-gravity     Skip "pihole -g"
  --no-dnsreload   Skip "pihole reloaddns"
  --restart-ftl    Restart pihole-FTL at the end (v6: only if needed)
  --json           Output results in JSON format
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

# --------------------------- PATH + pihole wrapper --------------------------
# 'pihole' binär finden
PIHOLE_BIN="$(command -v pihole || true)"
if [[ -z "$PIHOLE_BIN" ]]; then
  for d in /usr/local/bin /usr/local/sbin /usr/bin /usr/sbin /bin /sbin; do
    if [[ -x "$d/pihole" ]]; then
      PIHOLE_BIN="$d/pihole"
      break
    fi
  done
fi
if [[ -z "$PIHOLE_BIN" ]]; then
  if [[ -n "${CI:-}" ]]; then
    echo "Warnung: pihole CLI nicht im CI vorhanden. Test wird übersprungen."
    exit 0
  else
    echo -e "${RED}[ERROR]${NC} 'pihole' CLI nicht gefunden. PATH=$PATH" >&2
    echo "Auf Pi-hole-Host ausführen oder CLI installieren." >&2
    exit 127
  fi
fi
# Einheitlicher Wrapper
ph() { "$PIHOLE_BIN" "$@"; }
export PIHOLE_BIN
export -f ph

# --------------------------- Paths & globals --------------------------------
TMPDIR="$(mktemp -d -t pihole_maint_XXXX)"
LOGDIR="/var/log"
if [[ -d "$LOGDIR" && -w "$LOGDIR" ]]; then
  LOGFILE="$LOGDIR/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
else
  LOGFILE="$TMPDIR/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
  echo -e "${YELLOW}Hinweis:${NC} /var/log nicht beschreibbar, Log nach $TMPDIR."
fi

trap 'rm -rf "$TMPDIR" 2>/dev/null || true' EXIT
exec > >(tee -a "$LOGFILE") 2>&1

# shellcheck disable=SC2034
declare -A STATUS STEP_LOGFILE STEP_DATA PERFORMANCE_DATA

# --------------------------- Utils -----------------------------------------
# Utility functions loaded from lib/utils.sh or defined inline above

# Detect databases (best-effort)
FTL_DB="$(detect_ftl_db 2>/dev/null || true)"
# (gravity DB path is queried lazily when needed)

# shellcheck disable=SC2317  # trap callback is invoked by bash
on_exit() {
  local rc="$1"
  echo ""
  if [[ "$JSON_OUTPUT" == "1" ]]; then
    output_json 2> /dev/null || true
  else
    summary 2> /dev/null || true
  fi
  rm -rf "$TMPDIR" 2> /dev/null || true
  [[ $rc -ne 0 ]] && echo -e "${RED}Script ended with exit code $rc${NC}"
  exit "$rc"
}
trap 'on_exit $?' EXIT

# --------------------------- Run -------------------------------------------
echo_hdr

# 00 – Quick context (robuste Quoting, kein $2/$NF in Bash expandieren)
run_step 00 "🧭" "Kontext: Host & Netz" "\
  echo \"Host: $(hostname)\"; \
  echo \"Kernel: $(uname -r)\"; \
  echo \"Arch: $(dpkg --print-architecture)\"; \
  ip -4 addr show scope global | awk '/inet /{print \$2, \"on\", \$NF}'; \
  echo \"Default route:\"; ip route show default || true; \
  echo \"DNS servers (/etc/resolv.conf):\"; grep -E '^nameserver' /etc/resolv.conf || true" false true

# 01 – APT
if ((DO_APT == 1)); then
  export DEBIAN_FRONTEND=noninteractive
  run_step 01 "🔄" "APT: update & upgrade" "apt update && apt -y upgrade" true
  run_step 02 "🧹" "APT: autoremove & autoclean" "apt -y autoremove && apt -y autoclean"
  if dpkg --print-architecture | grep -q '^armhf$'; then
    if apt list --upgradable 2> /dev/null | grep -q '^linux-image-rpi-v8'; then
      echo -e "${YELLOW}Hinweis:${NC} 'linux-image-rpi-v8' ist 64-bit (ARMv8). Auf Pi 3B (ARMv7) ignorierbar."
    fi
  fi
else
  echo -e "${YELLOW}APT-Schritte übersprungen (--no-apt).${NC}"
fi

# 02 – Security Checks (optional display)
run_step 20 "🔒" "Security: Offene Ports" "ss -tuln | grep -E '(:22|:80|:443|:53|:8080|:8888)' || true" false true
run_step 21 "🛡️" "Security: SSH Login Attempts" "lastb -i | head -n 10 || true" false true
# 22 – awk-Programm strikt in Single-Quotes, damit $2 nicht von Bash expandiert
run_step 22 "🔑" "Security: Schwache Passwörter (shadow)" "awk -F: '(\$2==\"\"||\$2==\"*\"||\$2==\"!\") {print \$1}' /etc/shadow || true" false true
run_step 23 "🕸️" "Security: Pi-hole Admin Interface" "ss -tuln | grep ':80' | grep 'LISTEN' && grep -q 'webserver' /etc/pihole/pihole.toml && echo 'Admin interface active (detected via pihole.toml)' || echo 'Admin interface not detected'" false true
run_step 24 "🧑‍💻" "Security: Sudo-Konfiguration" "grep -E 'NOPASSWD|ALL' /etc/sudoers /etc/sudoers.d/* 2>/dev/null || echo 'Sudo-Konfiguration OK'" false true
run_step 25 "🔐" "Security: SSH-Konfiguration" "grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config || true" false true
run_step 26 "📦" "Security: Ausstehende Updates" "apt list --upgradable 2>/dev/null | grep -v 'Listing' || echo 'Keine Updates verfügbar'" false true
command -v chkrootkit > /dev/null 2>&1 && run_step 27 "🦠" "Security: chkrootkit" "chkrootkit || true" false true
command -v rkhunter > /dev/null 2>&1 && run_step 28 "🦠" "Security: rkhunter" "rkhunter --check --sk --nocolors || true" false true
command -v clamscan > /dev/null 2>&1 && run_step 29 "🦠" "Security: clamav" "clamscan -r /etc/pihole || true" false true

# Logfile-Monitoring
PIHOLE_LOG="/var/log/pihole.log"
if [[ -f "$PIHOLE_LOG" ]]; then
  LOGSIZE=$(stat -c %s "$PIHOLE_LOG" 2> /dev/null || echo 0)
  ((LOGSIZE > 1073741824)) && echo -e "${YELLOW}WARNUNG: pihole.log > 1GB! Empfehlung: logrotate aktivieren.${NC}"
fi

# Backup-Integration (optional)
if ((DO_BACKUP == 1)); then
  BACKUP_DIR="/var/backups/pihole/$(date +%Y%m%d_%H%M%S)"
  MAX_BACKUPS=5
  mkdir -p "$BACKUP_DIR"
  cp -a /etc/pihole/gravity.db "$BACKUP_DIR" 2> /dev/null || true
  cp -a /etc/pihole/pihole-FTL.db "$BACKUP_DIR" 2> /dev/null || true
  cp -a /etc/pihole/pihole.toml "$BACKUP_DIR" 2> /dev/null || true
  cp -a /etc/pihole/hosts/*.list "$BACKUP_DIR" 2> /dev/null || true
  echo "Backup gespeichert: $BACKUP_DIR"
  find /var/backups/pihole/ -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | awk '{print $2}' | head -n -$MAX_BACKUPS | xargs -r rm -rf
fi

# 03 – Pi-hole Version & Updates
run_step 03 "🔎" "Pi-hole Version" "\"$PIHOLE_BIN\" -v" false true
if ((DO_UPGRADE == 1)); then
  backup_pihole
  run_step 04 "🆙" "Pi-hole self-update" "\"$PIHOLE_BIN\" -up"
else
  echo -e "${YELLOW}Pi-hole Upgrade übersprungen (--no-upgrade).${NC}"
fi

# 05 – Gravity
if ((DO_GRAVITY == 1)); then
  backup_pihole
  run_step 05 "📋" "Update Gravity / Blocklists" "\"$PIHOLE_BIN\" -g"
else
  echo -e "${YELLOW}Gravity-Update übersprungen (--no-gravity).${NC}"
fi

# 06 – optionaler FTL-Restart (v6: nur bei Bedarf)
if ((RESTART_FTL == 1)); then
  run_step 06 "🔁" "Restart FTL (v6: nur bei Bedarf)" "systemctl restart pihole-FTL"
fi

# 07 – Health
run_step 07 "🧪" "Health: Port 53 listeners" "ss -lntup | awk '/:53[[:space:]]/ {print}' || true" false true
run_step 08 "🌐" "DNS Test: google.com @127.0.0.1" $'dig +time=2 +tries=1 +short google.com @127.0.0.1 || true' false true
run_step 09 "🏠" "DNS Test: pi.hole @127.0.0.1" $'dig +time=2 +tries=1 +short pi.hole @127.0.0.1 || true' false true

# 10 – GitHub Reachability
run_step 10 "🐙" "GitHub Reachability" $'\
  dig +time=2 +tries=1 +short raw.githubusercontent.com @127.0.0.1 || true; \
  echo "curl -I https://raw.githubusercontent.com (IPv4)"; \
  curl -4 -sI https://raw.githubusercontent.com | head -n 1 || true' false true

# 11 – Tailscale (optional)
if command -v tailscale > /dev/null 2>&1; then
  run_step 11 "🧩" "Tailscale Status (Kurz)" $'\
    echo -n "TS IPv4: "; tailscale ip -4 2>/dev/null || true; \
    echo -n "TS IPv6: "; tailscale ip -6 2>/dev/null || true; \
    tailscale status --peers=false 2>/dev/null || tailscale status 2>/dev/null || true' false true
fi

# 12 – FTL Toplists
if command -v sqlite3 > /dev/null 2>&1 && [[ -f "$FTL_DB" ]]; then
  run_step 12 "📈" "Top 5 Domains (FTL)" $'sqlite3 -readonly "$FTL_DB" "SELECT domain, COUNT(1) c FROM queries GROUP BY domain ORDER BY c DESC LIMIT 5;" || true' false true
  run_step 13 "👥" "Top 5 Clients (FTL)" $'sqlite3 -readonly "$FTL_DB" "SELECT client, COUNT(1) c FROM queries GROUP BY client ORDER BY c DESC LIMIT 5;" || true' false true
else
  echo -e "${YELLOW}sqlite3 oder FTL DB nicht gefunden – Überspringe Top-Listen.${NC}"
fi

# 14 – Abschluss (Summary/JSON kommt aus EXIT-Trap)

# 🧪 Repo-Selftest
if [[ "${RUN_SELFTEST:-0}" == "1" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEST_SCRIPT="${SCRIPT_DIR}/scripts/test-repo.sh"
  if [[ -f "$TEST_SCRIPT" ]]; then
    echo "Führe Repository-Selftest aus..."
    bash "$TEST_SCRIPT" || echo "Selftest fehlgeschlagen"
  else
    echo "Selftest übersprungen (scripts/test-repo.sh nicht gefunden)"
  fi
fi
