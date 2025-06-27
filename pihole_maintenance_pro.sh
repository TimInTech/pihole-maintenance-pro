#!/bin/bash
# Pi-hole v6.x - Full Maintenance PRO Script (v4.2)
# Version 4.2 - 2025-06-27
# By Tim & ChatGPT ^=^z^

LOGFILE="/var/log/pihole_maintenance_$(date +%F).log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "===================================="
echo " ^=^z^ Pi-hole Full Maintenance PRO ^=^z^ "
echo "===================================="

### 1. Systemupdate
echo "[1] System update via apt..."
sudo apt update && sudo apt upgrade -y
echo " → System update abgeschlossen."

### 2. Pi-hole Update
echo "[2] Pi-hole self-update..."
sudo pihole -up
echo " → Pi-hole update abgeschlossen."

### 3. Gravity / Blocklists
echo "[3] Gravity / Blocklists aktualisieren..."
sudo pihole -g
echo " → Blocklists aktualisiert."

### 4. Pi-hole Status
echo "[4] Pi-hole Statusabfrage..."
sudo pihole status

### 5. Cleanup
echo "[5] Cleanup (apt autoremove / autoclean)..."
sudo apt autoremove -y
sudo apt autoclean -y
echo " → System bereinigt."

### 6. Backup Pi-hole Config
echo "[6] Backup der Pi-hole Konfiguration (v6.x)..."
backup_dir="/etc/pihole/backup_v6"
mkdir -p "$backup_dir"
if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 /etc/pihole/gravity.db "SELECT * FROM adlist;" > "$backup_dir/adlist.sql"
  sqlite3 /etc/pihole/gravity.db "SELECT * FROM domainlist;" > "$backup_dir/domainlist.sql"
  echo " → Backup erfolgreich gespeichert in: $backup_dir"
else
  echo " ⚠️  WARNUNG: sqlite3 ist nicht installiert – Backup übersprungen."
  echo "    → Installiere mit: sudo apt install sqlite3"
fi

### 7. DNS neu laden
echo "[7] DNS neu laden..."
sudo pihole reloaddns
echo " → DNS Reload abgeschlossen."

echo "===================================="
echo " ^=^e HEALTH & TESTS ^=^e"
echo "===================================="

### 8–9. Ping Tests
echo "[8] Ping Test: 8.8.8.8 (Google DNS)"
ping -c 4 8.8.8.8

echo "[9] Ping Test: 1.1.1.1 (Cloudflare DNS)"
ping -c 4 1.1.1.1

### 10. DNS Test
echo "[10] DNS Lookup über Pi-hole (dig google.com)"
dig google.com @127.0.0.1

### 11. Port Check
echo "[11] Port 53 offen?"
ss -tuln | grep :53

### 12–13. FTL Daten
if command -v sqlite3 >/dev/null 2>&1; then
  echo "[12] Top 5 Domains (FTL)..."
  sqlite3 /etc/pihole/pihole-FTL.db "SELECT domain, COUNT(*) as count FROM queries GROUP BY domain ORDER BY count DESC LIMIT 5;"

  echo "[13] Aktive Clients (FTL)..."
  sqlite3 /etc/pihole/pihole-FTL.db "SELECT client, COUNT(*) as count FROM queries GROUP BY client ORDER BY count DESC LIMIT 5;"
else
  echo " ⚠️  sqlite3 nicht verfügbar – FTL-Statistik übersprungen."
fi

### 14. FTL Prozess
echo "[14] FTL Prozess Stats..."
ps -C pihole-FTL -o pid,%cpu,%mem,cmd

### 15. Systemstatus
echo "[15] Systemstatus (Uptime / Temp)..."
uptime
if command -v vcgencmd >/dev/null 2>&1; then
  vcgencmd measure_temp || echo " ⚠️  vcgencmd vorhanden, aber Zugriff fehlgeschlagen (kein echter Pi oder /dev/vcio fehlt)"
else
  echo " ⚠️  vcgencmd nicht verfügbar – Temperaturmessung übersprungen."
fi

echo "===================================="
echo " ^=^z^ Maintenance abgeschlossen ^=^z^"
echo " → Logfile: $LOGFILE"
echo "===================================="
