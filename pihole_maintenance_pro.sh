#!/bin/bash
# Pi-hole v6.x - Full Maintenance PRO MAX (v5.0)
# Version 5.0 - 2025-08-04
# By Tim & ChatGPT ^=^z^

# Farben und Symbole
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
CHECK="${GREEN}✔${NC}"
WARN="${YELLOW}⚠${NC}"
FAIL="${RED}✖${NC}"
ARROW="${BLUE}➜${NC}"

# Logging-Funktionen
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo -e "[INFO] $1" >> "$LOGFILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo -e "[WARNING] $1" >> "$LOGFILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo -e "[ERROR] $1" >> "$LOGFILE"
}

# Als root ausführen
if [[ $EUID -ne 0 ]]; then
  error "This script must be run with sudo or as root."
  exit 1
fi

LOGFILE="/var/log/pihole_maintenance_pro_$(date +%Y-%m-%d_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Statusvariablen
declare -A STATUS

# Header-Funktion
print_header() {
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════╗"
    echo -e "║   🛰️  PI-HOLE MAINTENANCE PRO MAX 🛰️        ║"
    echo -e "╚══════════════════════════════════════════════╝${NC}"
}

# Fortschrittsbalken
progress_bar() {
    local duration=${1}
    printf "${BLUE}${ARROW} Processing ["
    for ((i=0; i<duration; i++)); do
        printf "▰"
        sleep 0.3
    done
    printf "] 100%%${NC}\n"
}

# Funktion für konsistente Schrittausgabe
run_step() {
    local step_num=$1
    local symbol=$2
    local description=$3
    local cmd=$4
    local critical=${5:-false}
    local display=${6:-false}
    
    echo -e "\n${BLUE}╔═[Step $step_num]${NC}"
    echo -e "${BLUE}║ ${symbol} ${description}${NC}"
    echo -en "${BLUE}╚═>${NC} "
    
    if $display; then
        # Nur Anzeige, keine Ausführung
        eval "$cmd" || true
        STATUS["$step_num"]="${GREEN}✔ OK${NC}"
        return 0
    fi
    
    # Führe Befehl aus und fange Exit-Status ab
    if output=$(eval "$cmd" 2>&1); then
        echo -e "${CHECK} Success"
        STATUS["$step_num"]="${GREEN}✔ OK${NC}"
    else
        exit_code=$?
        if [ $exit_code -eq 1 ]; then
            echo -e "${WARN} Warning"
            STATUS["$step_num"]="${YELLOW}⚠ WARN${NC}"
        else
            echo -e "${FAIL} Error"
            STATUS["$step_num"]="${RED}✖ FAIL${NC}"
            if $critical; then
                error "Critical error - script aborted!"
                exit 1
            fi
        fi
        # Zeige Ausgabe nur bei Fehlern/Warnungen
        [ -n "$output" ] && echo "$output"
    fi
}

# ========== Hauptprogramm ==========

# System-Header anzeigen
clear
print_header
log "Started at: $(date)"
info "Logfile: $LOGFILE"

# ========== Systemaktualisierung ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ SYSTEM UPDATE ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

run_step "01" "🔄" "APT package update" \
    "apt update && apt upgrade -y" true

run_step "02" "🧹" "System cleanup" \
    "apt autoremove -y && apt autoclean -y"

# ========== Pi-hole Wartung ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ PI-HOLE MAINTENANCE ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

run_step "03" "🆙" "Pi-hole self-update" \
    "pihole -up"

run_step "04" "📋" "Update Gravity / Blocklists" \
    "pihole -g"

run_step "05" "💾" "Backup Pi-hole configuration" \
    "backup_dir=\"/etc/pihole/backup_v6\"; \
     mkdir -p \"\$backup_dir\"; \
     if [ -w \"\$backup_dir\" ]; then \
         pihole-FTL sqlite3 /etc/pihole/gravity.db \".dump adlist\" > \"\$backup_dir/adlist.sql\" 2>/dev/null; \
         pihole-FTL sqlite3 /etc/pihole/gravity.db \".dump domainlist\" > \"\$backup_dir/domainlist.sql\" 2>/dev/null; \
         echo \"Backup saved to: \$backup_dir\"; \
     else \
         echo 'No write permission to backup directory'; \
     fi"

run_step "06" "🔄" "Reload Pi-hole DNS" \
    "pihole reloaddns"

# ========== Systemdiagnose ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ SYSTEM DIAGNOSTICS ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

run_step "07" "📡" "Pi-hole status" \
    "pihole status" false true

run_step "08" "📊" "Network connectivity tests" \
    "echo 'Ping 8.8.8.8 (Google):'; ping -c 2 -W 2 8.8.8.8; \
     echo 'Ping 1.1.1.1 (Cloudflare):'; ping -c 2 -W 2 1.1.1.1; \
     echo 'DNS resolution (google.com):'; dig google.com @127.0.0.1 +short" false true
run_step "09" "🔒" "Port 53 status (DNS)" \
    "ss -tuln | grep ':53'" false true

# ========== Pi-hole Statistiken ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ PI-HOLE STATISTICS ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

run_step "10" "🌐" "Top 5 domains (from FTL)" \
    "pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db \
     'SELECT domain, COUNT(*) as count FROM queries GROUP BY domain ORDER BY count DESC LIMIT 5;' \
     || echo 'FTL database query failed'" false true

run_step "11" "👤" "Top 5 clients (from FTL)" \
    "pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db \
     'SELECT client, COUNT(*) as count FROM queries GROUP BY client ORDER BY count DESC LIMIT 5;' \
     || echo 'FTL database query failed'" false true

run_step "12" "⚙️" "FTL process stats" \
    "ps -C pihole-FTL -o pid,%cpu,%mem,cmd" false true

# ========== Raspberry Pi Gesundheit ==========
echo -e "${CYAN}\n█▀▀▀▀▀▀▀▀▀▀▀ RASPBERRY PI HEALTH ▀▀▀▀▀▀▀▀▀▀▀█${NC}"

run_step "13" "⏱️" "System uptime" \
    "uptime -p" false true

run_step "14" "🌡️" "CPU temperature" \
    "if command -v vcgencmd >/dev/null; then \
         temp=\$(vcgencmd measure_temp | cut -d= -f2); \
         echo \"Current temperature: \$temp\"; \
     else \
         echo 'vcgencmd not available'; \
     fi" false true

run_step "15" "📈" "Resource usage" \
    "echo 'CPU usage:'; top -bn1 | grep 'Cpu(s)'; \
     echo 'Memory usage:'; free -h; \
     echo 'Disk usage:'; df -h /" false true

# ========== Abschlussbericht ==========
echo -e "${MAGENTA}\n╔════════════════════════════════════════╗"
echo -e "║          📊 MAINTENANCE REPORT           ║"
echo -e "╠════════╦═════════════════════════════╣"
echo -e "║ ${CYAN}STEP${NC}   ║ ${GREEN}STATUS${NC}                  ║"
echo -e "╠════════╬═════════════════════════════╣"

# Sortiere Schritte numerisch
sorted_steps=($(printf '%s\n' "${!STATUS[@]}" | sort -n))

# Ausgabe der sortierten Schritte
for step in "${sorted_steps[@]}"; do
    printf "║ ${BLUE}%-6s${NC} ║ %-20s ║\n" "$step" "${STATUS[$step]}"
done

echo -e "╚════════╩═════════════════════════════╝"

log "Maintenance completed at: $(date)"
info "Full log saved: $LOGFILE"
echo -e "${GREEN}\n✅ PI-HOLE MAINTENANCE PRO MAX SUCCESSFULLY COMPLETED ✅${NC}"
