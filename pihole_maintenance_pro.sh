#!/bin/bash
# Pi-hole v6.x - Full Maintenance PRO Script (V4.1)
# Version 4.1 - 2025-06-27
# By Tim & ChatGPT ^=^z^`

LOGFILE="/var/log/pihole_maintenance_$(date +%F).log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "===================================="
echo " ^=^z^` Pi-hole Full Maintenance PRO  ^=^z^`"
echo "===================================="

echo "[1] System update via apt..."
sudo apt update && sudo apt upgrade -y
echo " → System update abgeschlossen."

echo "[2] Pi-hole self-update..."
sudo pihole -up
echo " → Pi-hole update abgeschlossen."

echo "[3] Gravity / Blocklists aktualisieren..."
sudo pihole -g
echo " → Blocklists aktualisiert."

echo "[4] Pi-hole Statusabfrage..."
sudo pihole status

echo "[5] Cleanup (apt autoremove / autoclean)..."
sudo apt autoremove -y
sudo apt autoclean -y
echo " → System bereinigt."

echo "[6] Backup der Pi-hole Konfiguration (v6.x)..."
backup_dir="/etc/pihole/backup_v6"
mkdir -p "$backup_dir"
sqlite3 /etc/pihole/gravity.db "SELECT * FROM adlist;" > "$backup_dir/adlist.sql"
sqlite3 /etc/pihole/gravity.db "SELECT * FROM domainlist;" > "$backup_dir/domainlist.sql"
echo " → Backup gespeichert in: $backup_dir"

echo "[7] DNS neu laden..."
sudo pihole reloaddns
echo " → DNS Reload abgeschlossen."

echo "===================================="
echo " ^=^e HEALTH & TESTS ^=^e"
echo "===================================="

echo "[8] Ping Test: 8.8.8.8 (Google DNS)"
ping -c 4 8.8.8.8

echo "[9] Ping Test: 1.1.1.1 (Cloudflare DNS)"
ping -c 4 1.1.1.1

echo "[10] DNS Lookup über Pi-hole (dig google.com)"
dig google.com @127.0.0.1

echo "[11] Port 53 offen?"
ss -tuln | grep :53

echo "[12] Top 5 Domains (FTL)..."
sqlite3 /etc/pihole/pihole-FTL.db "SELECT domain, COUNT(*) as count FROM queries GROUP BY domain ORDER BY count DESC LIMIT 5;"

echo "[13] Aktive Clients (FTL)..."
sqlite3 /etc/pihole/pihole-FTL.db "SELECT client, COUNT(*) as count FROM queries GROUP BY client ORDER BY count DESC LIMIT 5;"

echo "[14] FTL Prozess Stats..."
ps -C pihole-FTL -o pid,%cpu,%mem,cmd

echo "[15] Systemstatus (Uptime / Temp)..."
uptime
vcgencmd measure_temp

echo "===================================="
echo " ^=^z^` Maintenance abgeschlossen ^=^z^`"
echo " → Logfile: $LOGFILE"
echo "===================================="
