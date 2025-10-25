#!/usr/bin/env bash
# Version 1.0 – FTL-Datenbank Reparatur (2025-09-25)
# Prüft die Tabelle "queries" und rekonstruiert die DB bei Fehlern.

set -euo pipefail

DB_PATH="/etc/pihole/pihole-FTL.db"
BACKUP_PATH="/etc/pihole/pihole-FTL.db.bak.$(date +%F_%H-%M-%S)"

echo "ℹ Prüfe FTL-Datenbank: $DB_PATH ..."
if [ ! -f "$DB_PATH" ]; then
  echo "✗ DB nicht gefunden. Starte FTL neu, um die DB zu erzeugen."
  sudo systemctl restart pihole-FTL
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "✗ sqlite3 fehlt. Installiere mit: sudo apt update && sudo apt install -y sqlite3" >&2
  exit 2
fi

echo "✔ DB gefunden. Prüfe Tabellenstruktur ..."
if ! sudo sqlite3 -readonly "$DB_PATH" "SELECT count(*) FROM queries LIMIT 1;" >/dev/null 2>&1; then
  echo "✗ Tabelle queries fehlt/beschädigt."
  echo "➜ Backup: $BACKUP_PATH"
  sudo cp "$DB_PATH" "$BACKUP_PATH"
  echo "➜ Entferne defekte DB und starte FTL neu ..."
  sudo rm -f "$DB_PATH"
  sudo systemctl restart pihole-FTL
  echo "✔ FTL neu gestartet. Verifiziere DB erneut ..."
  if sudo sqlite3 -readonly "$DB_PATH" "SELECT count(*) FROM queries LIMIT 1;" >/dev/null 2>&1; then
    echo "✔ Tabelle queries vorhanden. Reparatur erfolgreich."
  else
    echo "⚠ Tabelle weiterhin fehlend. Prüfe Pi-hole-Version und /var/log/pihole-FTL.log." >&2
    exit 3
  fi
else
  echo "✔ Tabelle queries vorhanden. Keine Reparatur nötig."
fi

echo "✔ FTL-Datenbank-Check abgeschlossen."
