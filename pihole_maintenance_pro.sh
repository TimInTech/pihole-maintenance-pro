#!/usr/bin/env bash
# Pi-hole v6.x - Full Maintenance PRO MAX (v5.1.2)
# Version 5.1.2 - 2025-09-16
# By Tim & ChatGPT ^=^z^
#
# Fixes:
# - Improve backup step to avoid hangs (use tar directly into /var/backups, exclude WAL/SHM/sockets)
# - Print clear progress messages during backup so you see what is currently executed
# - Spinner: fix spin_chars quoting and ensure spinner writes only to TTY
# - Small logging/robustness tweaks
#
set -euo pipefail
IFS=$'\n\t'

# Farben und Symbole
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color
CHECK="${GREEN}✔${NC}"
WARN="${YELLOW}⚠${NC}"
FAIL="${RED}✖${NC}"
ARROW="${BLUE}➜${NC}"

# Temporärer Ordner für Step-Logs
TMPDIR="$(mktemp -d -t pihole_maint_XXXX)"
trap 'rm -rf "$TMPDIR"; echo -e "${YELLOW}Temporary logs removed: $TMPDIR${NC}"' EXIT

# Globale Logdatei (wird später initialisiert, sobald Timestamp verfügbar)
LOGFILE=""

# Statusvariablen
declare -A STATUS        # Schritt -> status string
declare -A STEP_PID      # Schritt -> PID (falls Hintergrund)
declare -A STEP_LOGFILE  # Schritt -> per-step logfile

# Utility: strip ANSI escape sequences (works without perl)
strip_ansi() {
    # usage: some_command | strip_ansi > file
    sed -r $'s/\\x1B\\[[0-9;]*[a-zA-Z]//g' | tr -d '\r'
}

# Logging-Funktionen (sowohl stdout als auch Gesamtlog)
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    [ -n "${LOGFILE:-}" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    [ -n "${LOGFILE:-}" ] && echo "[INFO] $1" >> "$LOGFILE"
}
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    [ -n "${LOGFILE:-}" ] && echo "[WARNING] $1" >> "$LOGFILE"
}
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    [ -n "${LOGFILE:-}" ] && echo "[ERROR] $1" >> "$LOGFILE"
}

# Als root ausführen
if [[ $EUID -ne 0 ]]; then
  error "Dieses Skript muss mit sudo oder als root ausgeführt werden."
  exit 1
fi

# Initialisiere das Hauptlogfile mit Timestamp
LOGFILE="/var/log/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
# Leite stdout/stderr in das logfile (und gleichzeitig auf Konsole)
exec > >(tee -a "$LOGFILE") 2>&1

# Header-Funktion (verbesserte grafische Darstellung)
print_header() {
    clear
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}   🛰️  ${BOLD}PI-HOLE MAINTENANCE PRO MAX${NC}${MAGENTA}  -  TimInTech  (${CYAN}v5.1.2${MAGENTA})  ║${NC}"
    echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════════════════╣${NC}"
    # Zeige Pi-hole Version falls vorhanden
    if command -v pihole >/dev/null 2>&1; then
        PH_VER="$(pihole -v 2>/dev/null || true)"
        echo -e "${MAGENTA}║${NC} Version: ${CYAN}${PH_VER:-unbekannt}${NC}"
    else
        echo -e "${MAGENTA}║${NC} ${YELLOW}Pi-hole CLI nicht gefunden${NC}"
    fi
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Spinner für laufende Tasks - schreibt ausschließlich auf das TTY (wenn vorhanden)
spinner() {
    local pid=$1
    local prefix="${2:-}"
    local spin_chars="|/-\\"
    local i=0
    # If we have a TTY, write spinner there to avoid polluting logs
    local out="/dev/tty"
    if [[ ! -t 1 || ! -w $out ]]; then
        out="/dev/null"
    fi
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        # Print prefix + state + spinner char
        printf "\r${prefix} %s %s" "${CYAN}running${NC}" "${spin_chars:i:1}" >"$out" 2>/dev/null || true
        sleep 0.15
    done
    printf "\r" >"$out" 2>/dev/null || true
}

# Eine Step-Funktion, die den Befehl asynchron ausführt und live anzeigt.
# Parameter:
#  $1 - step_num (z.B. "01")
#  $2 - symbol (z.B. "🔄")
#  $3 - description (String)
#  $4 - command (String) - wird in 'bash -lc' ausgeführt
#  $5 - critical (true/false) - ob bei Fehler abort
#  $6 - display_only (true/false) - nur anzeigen, nicht "hintergrund"
run_step() {
    local step_num="$1"
    local symbol="$2"
    local description="$3"
    local cmd="$4"
    local critical="${5:-false}"
    local display_only="${6:-false}"

    local step_log="$TMPDIR/step_${step_num}.log"
    STEP_LOGFILE["$step_num"]="$step_log"

    echo -e "\n${BLUE}╔═[Step ${step_num}]${NC}"
    echo -e "${BLUE}║ ${symbol} ${description}${NC}"
    echo -en "${BLUE}╚═>${NC} "

    # Wenn nur Anzeige (z.B. status commands), führe synchron aus und show output (strip colors to per-step logfile)
    if [[ "${display_only}" == "true" ]]; then
        # Run command and both show on console and write a cleaned copy to step log
        # Use a subshell to preserve exit code
        if bash -lc "$cmd" 2>&1 | tee /dev/tty | strip_ansi > "$step_log"; then
            echo -e "${CHECK} Success"
            STATUS["$step_num"]="${GREEN}✔ OK${NC}"
        else
            echo -e "${WARN} Warning"
            STATUS["$step_num"]="${YELLOW}⚠ WARN${NC}"
            [ -s "$step_log" ] && echo -e "${YELLOW}--- Output ---${NC}" && tail -n 20 "$step_log"
            if [[ "${critical}" == "true" ]]; then
                error "Critical error - script aborted!"
                exit 1
            fi
        fi
        return 0
    fi

    # Starte den Befehl im Hintergrund und schreibe stdout/stderr in logfile (ANSI-codes entfernt)
    # Wir verwenden bash -lc um komplexe Kommandos/Mehrzeiler zu unterstützen.
    # Ensure the command's own output goes to the step log only (cleaned).
    bash -lc "$cmd" 2>&1 | strip_ansi > "$step_log" &
    local pid=$!
    STEP_PID["$step_num"]=$pid

    # Zeige Spinner während der Prozess läuft; alle 0.6s update: letzte Zeile der Logdatei
    (
        # Hintergrundüberwachung (nicht blockierend für outer)
        local out="/dev/tty"
        if [[ ! -t 1 || ! -w $out ]]; then
            out="/dev/null"
        fi
        while kill -0 "$pid" 2>/dev/null; do
            if [ -f "$step_log" ]; then
                last_line="$(tail -n 1 "$step_log" 2>/dev/null || true)"
                # strip any stray ANSI sequences (should already be stripped) and limit length
                last_line_clean="$(printf "%s" "$last_line" | sed -r $'s/\\x1B\\[[0-9;]*[a-zA-Z]//g' | cut -c1-80)"
                printf "\r${CYAN}%s${NC} %s" "${last_line_clean}" "${BLUE}[PID:${pid}]${NC}" >"$out" 2>/dev/null || true
            else
                printf "\r${BLUE}[PID:${pid}] ${CYAN}running...${NC}" >"$out" 2>/dev/null || true
            fi
            sleep 0.6
        done
        # Clear the spinner line on finish
        printf "\r" >"$out" 2>/dev/null || true
    ) &

    # Warte auf Beendigung und erfasse Exit-Code
    if wait "$pid"; then
        echo -e "\n${CHECK} Success"
        STATUS["$step_num"]="${GREEN}✔ OK${NC}"
    else
        exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            echo -e "\n${WARN} Warning"
            STATUS["$step_num"]="${YELLOW}⚠ WARN${NC}"
        else
            echo -e "\n${FAIL} Error (code: $exit_code)"
            STATUS["$step_num"]="${RED}✖ FAIL${NC}"
            echo -e "${RED}--- Last 50 lines of step ${step_num} log ---${NC}"
            [ -f "$step_log" ] && tail -n 50 "$step_log"
            if [[ "${critical}" == "true" ]]; then
                error "Critical error in step ${step_num} - script aborted!"
                exit 1
            fi
        fi
    fi
}

# Utility: prüfe Verfügbarkeit von sqlite3 und setze passende Befehle
SQLITE_BIN="$(command -v sqlite3 || true)"
if [[ -z "$SQLITE_BIN" ]]; then
    warning "sqlite3 nicht gefunden. Einige DB-Abfragen werden fehlschlagen."
fi

# Utility: Abfrage/Fallback für pihole-FTL DB Pfad (verschiedene Installationen)
FTL_DB="/etc/pihole/pihole-FTL.db"
GRAVITY_DB="/etc/pihole/gravity.db"
if [[ ! -f "$FTL_DB" && -f "/etc/pihole/pihole-FTL.db" ]]; then
    FTL_DB="/etc/pihole/pihole-FTL.db"
fi

# ========== Hauptprogramm ==========

print_header
log "Started at: $(date)"
info "Logfile: $LOGFILE"
info "Tempdir for step logs: $TMPDIR"

# ========== Systemaktualisierung ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ SYSTEM UPDATE ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

run_step "01" "🔄" "APT package update" \
    "apt update && apt upgrade -y" true

run_step "02" "🧹" "System cleanup" \
    "apt autoremove -y && apt autoclean -y"

# ========== Pi-hole Wartung ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ PI-HOLE MAINTENANCE ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

# Pi-hole Version und empfohlene Kommando-Optionen prüfen
run_step "03" "🔎" "Detect Pi-hole version" \
    "pihole -v || echo 'pihole CLI not installed or failed to report version'" false true

run_step "04" "🆙" "Pi-hole self-update" \
    "pihole -up"

run_step "05" "📋" "Update Gravity / Blocklists" \
    "pihole -g"

# Backup: improved backup sequence (no hanging, clear progress messages)
run_step "06" "💾" "Backup Pi-hole configuration (gravity + pihole dir)" \
    "backup_dir=\"/var/backups/pihole_backup_$(date +%Y-%m-%d_%H-%M-%S)\"; \
     mkdir -p \"\$backup_dir\"; \
     echo 'Backup directory:' \"\$backup_dir\"; \
     echo '1) Creating tarball of /etc/pihole (excluding WAL/SHM/sockets)...'; \
     tar -C /etc -czf \"\$backup_dir/pihole_backup.tar.gz\" --warning=no-file-changed --exclude='pihole-FTL.db-wal' --exclude='pihole-FTL.db-shm' --exclude='*.sock' pihole || { echo 'Tar archive failed' >&2; exit 2; }; \
     echo 'Tarball created: ' \"\$backup_dir/pihole_backup.tar.gz\"; \
     echo '2) Exporting gravity adlist (if sqlite3 & gravity.db available)...'; \
     if command -v sqlite3 >/dev/null 2>&1 && [ -f \"$GRAVITY_DB\" ]; then sqlite3 \"$GRAVITY_DB\" \".dump adlist\" > \"\$backup_dir/adlist.sql\" 2>/dev/null || echo 'Gravity adlist dump failed'; else echo 'sqlite3 or gravity.db missing'; fi; \
     echo '3) Exporting FTL schema (if sqlite3 & pihole-FTL.db available)...'; \
     if command -v sqlite3 >/dev/null 2>&1 && [ -f \"$FTL_DB\" ]; then sqlite3 \"$FTL_DB\" \".schema\" > \"\$backup_dir/ftl_schema.sql\" 2>/dev/null || echo 'FTL schema dump failed'; else echo 'sqlite3 or ftl db missing'; fi; \
     echo 'Backup completed successfully. Files in:' \"\$backup_dir\"; \
     ls -lh \"\$backup_dir\" || true" true

run_step "07" "🔄" "Reload Pi-hole DNS" \
    "pihole reloaddns"

# ========== Systemdiagnose ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ SYSTEM DIAGNOSTICS ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

run_step "08" "📡" "Pi-hole status (service checks)" \
    "pihole status; systemctl is-active pihole-FTL.service || systemctl status pihole-FTL.service" false true

run_step "09" "📊" "Network connectivity tests" \
    "echo 'Ping 8.8.8.8 (Google):'; ping -c 2 -W 2 8.8.8.8; \
     echo 'Ping 1.1.1.1 (Cloudflare):'; ping -c 2 -W 2 1.1.1.1; \
     echo 'DNS resolution (google.com via localhost):'; dig google.com @127.0.0.1 +short" false true

run_step "10" "🔒" "Port 53 status (DNS) + sockets" \
    "ss -tuln | grep ':53' || netstat -tuln | grep ':53' || echo 'No DNS port 53 listeners detected'" false true

# ========== Pi-hole Statistiken ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ PI-HOLE STATISTICS ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

# Falls sqlite3 verfügbar ist, führe fokussierte Abfragen asynchron aus
if command -v sqlite3 >/dev/null 2>&1 && [ -f "$FTL_DB" ]; then
    run_step "11" "🌐" "Top 5 domains (from FTL DB)" \
        "sqlite3 \"$FTL_DB\" \"SELECT domain, COUNT(*) as count FROM queries GROUP BY domain ORDER BY count DESC LIMIT 5;\" || echo 'FTL DB query failed'" false true

    run_step "12" "👤" "Top 5 clients (from FTL DB)" \
        "sqlite3 \"$FTL_DB\" \"SELECT client, COUNT(*) as count FROM queries GROUP BY client ORDER BY count DESC LIMIT 5;\" || echo 'FTL DB query failed'" false true
else
    run_step "11" "🌐" "Top 5 domains (FTL DB not available)" \
        "echo 'FTL DB not available or sqlite3 missing'" false true
    run_step "12" "👤" "Top 5 clients (FTL DB not available)" \
        "echo 'FTL DB not available or sqlite3 missing'" false true
fi

run_step "13" "⚙️" "FTL process stats" \
    "ps -C pihole-FTL -o pid,%cpu,%mem,cmd || ps aux | egrep 'pihole-FTL|pihole-FTL' || echo 'FTL process not found'" false true

# ========== Raspberry Pi Gesundheit ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ RASPBERRY PI HEALTH ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

run_step "14" "⏱️" "System uptime" \
    "uptime -p" false true

run_step "15" "🌡️" "CPU temperature" \
    "if command -v vcgencmd >/dev/null 2>&1; then \
         vcgencmd measure_temp || true; \
     else \
         echo 'vcgencmd nicht verfügbar'; \
     fi" false true

run_step "16" "📈" "Resource usage (CPU/Memory/Disk)" \
    "echo 'Top CPU processes:'; ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 10; \
     echo 'Memory usage:'; free -h; \
     echo 'Disk usage:'; df -h /" false true

# ========== Abschlussbericht: laufende Prozesse & Fehlerübersicht ==========
echo -e "${MAGENTA}\n╔════════════════════════════════════════╗"
echo -e "║          📊 MAINTENANCE REPORT           ║"
echo -e "╠════════╦═════════════════════════════╣"
echo -e "║ ${CYAN}STEP${NC}   ║ ${GREEN}STATUS${NC}                  ║"
echo -e "╠════════╬═════════════════════════════╣"

# Sortiere Schritte numerisch und gebe Status aus
sorted_steps=($(printf '%s\n' "${!STATUS[@]}" | sort -n))
for step in "${sorted_steps[@]}"; do
    printf "║ ${BLUE}%-6s${NC} ║ %-20s ║\n" "$step" "${STATUS[$step]}"
done

echo -e "╚════════╩═════════════════════════════╝"

# Zusätzliche Übersicht: aktuell laufende relevante Prozesse
echo -e "${MAGENTA}\n╔════════════════════════════════════════╗"
echo -e "║        🔎 Running Pi-hole Processes      ║"
echo -e "╠════════════════════════════════════════╣${NC}"
ps aux | egrep -i 'pihole|pihole-FTL|dnsmasq|unbound|dnscrypt|dnsproxy' | sed -n '1,20p' || echo "No matching processes found"
echo -e "${MAGENTA}╚════════════════════════════════════════╝${NC}"

# Fehlerprüfungs-Übersicht: Zeige Schritte, die WARN/FAIL haben und gib Log-Auszüge
echo -e "${MAGENTA}\n╔════════════════════════════════════════╗"
echo -e "║        ⚠ Issues / Error Summary         ║"
echo -e "╠════════════════════════════════════════╣${NC}"
has_issues=false
for step in "${sorted_steps[@]}"; do
    status="${STATUS[$step]}"
    if echo "$status" | grep -E "WARN|FAIL|FAIL" >/dev/null 2>&1; then
        has_issues=true
        echo -e "${YELLOW}Step ${step}: ${status}${NC}"
        logfile="${STEP_LOGFILE[$step]:-}"
        if [[ -n "$logfile" && -f "$logfile" ]]; then
            echo -e "${CYAN}--- Last 40 lines of step ${step} log ---${NC}"
            tail -n 40 "$logfile"
        fi
        echo
    fi
done

if [[ "$has_issues" == "false" ]]; then
    echo -e "${GREEN}No warnings or errors detected in steps.${NC}"
fi

log "Maintenance completed at: $(date)"
info "Full log saved: $LOGFILE"
echo -e "${GREEN}\n✅ PI-HOLE MAINTENANCE PRO MAX SUCCESSFULLY COMPLETED ✅${NC}"

# ================= Helpful suggestions / future features =================
cat <<'SUGGESTIONS'

Suggested improvements & Pi-hole related updates to consider:
- Add optional "dry-run" mode for disruptive operations (updates/reloads).
- Add an argument parser (getopts) to allow selective step execution (e.g. --skip-backup).
- Integrate systemd notify / journald for service-status checks.
- Add built-in rotation of /var/backups/pihole_backup_*.tar.gz (prune older than X days).
- For Pi-hole v6+ consider:
  - Using 'pihole -a' admin commands for certs / web admin checks.
  - Monitoring FTL schema changes: if queries table column names differ, adapt SQL.
- Add optional Slack/Matrix/Email notification on critical failures.
- Consider a non-root mode where only allowed operations are performed (via sudo for specific commands).
- Add integrity checks for gravity.db and pihole-FTL.db (vacuum / integrity_check via sqlite3).
SUGGESTIONS

# Script Ende
exit 0
