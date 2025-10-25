# Anleitung DE – Pi-hole Maintenance PRO MAX (v5.3.2)

Nutzung:
  sudo /usr/local/bin/pihole_maintenance_pro.sh
  sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload

Installation:
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"

Cron:
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  */30 * * * * /usr/local/bin/pihole_api_healthcheck.sh >> /var/log/pihole_healthcheck.log 2>&1
  30 3 * * * /usr/local/bin/pihole_maintenance_pro.sh >> /var/log/pihole_maintenance_pro.log 2>&1

Hinweis:
  Trixie/Cron nutzt reduzierten PATH. Mit vollem PATH laufen beide Skripte zuverlässig.

Troubleshooting kurz:
- rfkill → do_wifi_country DE; optional rfkill block wifi
- sqlite3 → apt install sqlite3
- FTL-DB Rechte → sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
- Locale → locale-gen; update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8

Pi-hole v6 API:
  - Keine setupVars.conf mehr
  - Konfiguration in /etc/pihole/pihole.toml
  - API unter /api, nicht /api.php
  - Authentifizierung per Basic Auth (cli + /etc/pihole/cli_pw)
  - Beispiel: tools/pihole_api_healthcheck.sh
  - Unbound nicht erforderlich
