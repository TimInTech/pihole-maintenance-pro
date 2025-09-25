# Anleitung DE – Pi-hole Maintenance PRO MAX (v5.3.1)

Nutzung:
  sudo /usr/local/bin/pihole_maintenance_pro.sh
  sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload

Installation:
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"

Cron:
  0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1

Troubleshooting kurz:
- rfkill → do_wifi_country DE; optional rfkill block wifi
- sqlite3 → apt install sqlite3
- FTL-DB Rechte → sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
- Locale → locale-gen; update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
