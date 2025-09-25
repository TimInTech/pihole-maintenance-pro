#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp -d)"
RAW_BASE="https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main"
curl -fsSL "$RAW_BASE/pihole_maintenance_pro.sh" -o "$TMP/pihole_maintenance_pro.sh"
sudo install -m 0755 "$TMP/pihole_maintenance_pro.sh" /usr/local/bin/pihole_maintenance_pro.sh
echo "Cron (So 04:00): 0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1"
echo "Troubleshooting: rfkill, sqlite3, FTL-DB-Rechte, Locale → README"
