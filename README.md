# Pi-hole Maintenance PRO MAX (v5.3.1)

Wartungsskript für Pi-hole 6.x auf Raspberry Pi OS (Bookworm). Schritte mit Logging nach /var/log/.

## Features
- APT Update/Upgrade/Autoremove
- Pi-hole Update (pihole -up), Gravity (pihole -g), reloaddns
- Healthchecks: Port 53, dig-Tests, GitHub-Reachability
- Optional: Tailscale-Status, FTL-Toplisten via sqlite3

## Installation
Variante A:
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
Variante B:
  cd ~
  wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
  chmod +x pihole_maintenance_pro.sh
  sudo install -m 0755 pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh

## Nutzung
  sudo /usr/local/bin/pihole_maintenance_pro.sh
  sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
Cron:
  0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1

## Troubleshooting
1) rfkill-Hinweis:
   sudo raspi-config nonint do_wifi_country DE
   optional: sudo rfkill block wifi
2) sqlite3 fehlt:
   sudo apt update && sudo apt install -y sqlite3
3) FTL-DB „unable to open“:
   sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
   # oder Nutzer zur Gruppe pihole:
   sudo usermod -aG pihole $USER && newgrp pihole
4) Locale-Warnungen:
   echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
   sudo locale-gen && sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
5) linux-image-rpi-v8 auf Pi 3B: Hinweis ignorierbar.

Changelog v5.3.1: Neuer Installer, README/Anleitung überarbeitet, klarere Hinweise.
