#!/bin/bash
# Pi-hole v6.x - Full Maintenance PRO Script (v4.4)
# Version 4.4 - 2025-06-27
# By Tim & ChatGPT ^=^z^

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  This script must be run with sudo or as root."
  exit 1
fi

LOGFILE="/var/log/pihole_maintenance_$(date +%F).log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "===================================="
echo " ^=^z^ Pi-hole Full Maintenance PRO ^=^z^ "
echo "===================================="

echo "[1] System update (apt)..."
apt update && apt upgrade -y
echo " → System update completed."

echo "[2] Pi-hole self-update..."
pihole -up
echo " → Pi-hole update completed."

echo "[3] Update Gravity / Blocklists..."
pihole -g
echo " → Blocklists update completed."

echo "[4] Pi-hole status..."
pihole status

echo "[5] System cleanup (autoremove / autoclean)..."
apt autoremove -y
apt autoclean -y
echo " → System cleanup completed."

echo "[6] Backup Pi-hole configuration (v6.x)..."
backup_dir="/etc/pihole/backup_v6"
mkdir -p "$backup_dir"

# Use embedded SQLite via pihole-FTL
if command -v pihole-FTL >/dev/null 2>&1; then
  if [ -w "$backup_dir" ]; then
    pihole-FTL sqlite3 /etc/pihole/gravity.db "SELECT * FROM adlist;" > "$backup_dir/adlist.sql" 2>/dev/null || echo " ⚠️  Failed to write adlist.sql"
    pihole-FTL sqlite3 /etc/pihole/gravity.db "SELECT * FROM domainlist;" > "$backup_dir/domainlist.sql" 2>/dev/null || echo " ⚠️  Failed to write domainlist.sql"
    echo " → Backup saved to: $backup_dir"
  else
    echo " ⚠️  No write permission to $backup_dir – skipping backup."
  fi
else
  echo " ⚠️  pihole-FTL is not available – skipping backup."
fi

echo "[7] Reload Pi-hole DNS..."
pihole reloaddns
echo " → DNS reload completed."

echo "===================================="
echo " ^=^e HEALTH & TESTS ^=^e"
echo "===================================="

echo "[8] Ping test: 8.8.8.8 (Google DNS)"
ping -c 4 8.8.8.8

echo "[9] Ping test: 1.1.1.1 (Cloudflare DNS)"
ping -c 4 1.1.1.1

echo "[10] DNS test using dig (google.com)"
dig google.com @127.0.0.1

echo "[11] Port 53 status (should be open)"
ss -tuln | grep :53

if command -v pihole-FTL >/dev/null 2>&1; then
  if [ -r /etc/pihole/pihole-FTL.db ]; then
    echo "[12] Top 5 domains (from FTL)..."
    pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db "SELECT domain, COUNT(*) as count FROM queries GROUP BY domain ORDER BY count DESC LIMIT 5;" || echo " ⚠️  Failed to query top domains"

    echo "[13] Top 5 clients (from FTL)..."
    pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db "SELECT client, COUNT(*) as count FROM queries GROUP BY client ORDER BY count DESC LIMIT 5;" || echo " ⚠️  Failed to query clients"
  else
    echo " ⚠️  FTL database not readable – skipping FTL stats."
  fi
else
  echo " ⚠️  pihole-FTL not available – skipping FTL stats."
fi

echo "[14] FTL process stats..."
ps -C pihole-FTL -o pid,%cpu,%mem,cmd

echo "[15] System uptime and temperature..."
uptime
if command -v vcgencmd >/dev/null 2>&1; then
  vcgencmd measure_temp || echo " ⚠️  vcgencmd found but access failed (not a real Pi or /dev/vcio missing)"
else
  echo " ⚠️  vcgencmd not available – skipping temperature check."
fi

echo "===================================="
echo " ^=^z^ Maintenance completed ^=^z^"
echo " → Logfile saved: $LOGFILE"
echo "===================================="
