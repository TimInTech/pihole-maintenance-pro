#!/usr/bin/env bash
# ============================================================================
# Pi-hole Maintenance PRO MAX – Uninstall Script
# Removes all traces of the maintenance script so you can reinstall cleanly
# ============================================================================
set -euo pipefail
IFS=$'\n\t'
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "This uninstaller requires root. Re-run with sudo." >&2
  exit 1
fi
PURGE=0
[[ "${1:-}" == "--purge" ]] && PURGE=1

echo "🗑️  Removing Pi-hole Maintenance PRO MAX..."

# 1. Remove main script and healthcheck in /usr/local/bin
if [[ -f /usr/local/bin/pihole_maintenance_pro.sh ]]; then
  rm -f /usr/local/bin/pihole_maintenance_pro.sh
  echo "✔ Removed: /usr/local/bin/pihole_maintenance_pro.sh"
fi
if [[ -f /usr/local/bin/pihole_api_healthcheck.sh ]]; then
  rm -f /usr/local/bin/pihole_api_healthcheck.sh
  echo "✔ Removed: /usr/local/bin/pihole_api_healthcheck.sh"
fi

# 2. Remove logs and temporary files
rm -f /var/log/pihole_maintenance_pro_*.log 2> /dev/null || true
rm -rf /tmp/pihole_maint_* 2> /dev/null || true
echo "✔ Logs removed"

# 3. Clean up cronjob
if crontab -l 2> /dev/null | grep -q "pihole_maintenance_pro.sh"; then
  (crontab -l | grep -v "pihole_maintenance_pro.sh") | crontab -
  echo "✔ Cronjob removed"
else
  echo "ℹ No cronjob found"
fi

# 4. Remove backups (only when --purge)
if ((PURGE)) && [[ -d /var/backups/pihole ]]; then
  rm -rf /var/backups/pihole/
  echo "✔ Removed backups: /var/backups/pihole/ (purge)"
else
  echo "ℹ Backups preserved (use --purge to remove)"
fi

echo "✅ Uninstallation complete."
