#!/usr/bin/env bash
# ============================================================================
# Pi-hole Maintenance PRO MAX – Uninstall Script
# Removes all traces of the maintenance script so you can reinstall cleanly
# ============================================================================
set -euo pipefail
IFS=$'\n\t'

echo "🗑️  Removing Pi-hole Maintenance PRO MAX..."

# 1. Remove main script in /usr/local/bin
if [[ -f /usr/local/bin/pihole_maintenance_pro.sh ]]; then
  sudo rm -f /usr/local/bin/pihole_maintenance_pro.sh
  echo "✔ Removed: /usr/local/bin/pihole_maintenance_pro.sh"
fi

# 2. Remove logs and temporary files
sudo rm -f /var/log/pihole_maintenance_pro_*.log 2>/dev/null || true
sudo rm -rf /tmp/pihole_maint_* 2>/dev/null || true
echo "✔ Logs removed"

# 3. Clean up cronjob
if crontab -l 2>/dev/null | grep -q "pihole_maintenance_pro.sh"; then
  (crontab -l | grep -v "pihole_maintenance_pro.sh") | crontab -
  echo "✔ Cronjob removed"
else
  echo "ℹ No cronjob found"
fi

# 4. Remove backups (optional)
if [[ -d /var/backups/pihole ]]; then
  sudo rm -rf /var/backups/pihole/
  echo "✔ Removed backups: /var/backups/pihole/"
fi

echo "✅ Uninstallation complete. System is clean."
