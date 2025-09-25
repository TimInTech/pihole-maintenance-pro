# Pi-hole Maintenance PRO MAX (v5.3.1)

Wartungsskript für Pi-hole v6.x auf Raspberry Pi OS (Bookworm). Ausgabe mit Farben, klare Steps, Logging nach /var/log/.

## Features
- APT Update, Upgrade, Autoremove/Autoclean
- Pi-hole Self-Update (pihole -up), Gravity (pihole -g), reloaddns
- Healthchecks: Port 53, dig-Tests, GitHub-Reachability
- Optionalanzeige: Tailscale-Status (falls installiert)
- FTL-Toplisten via sqlite3 (falls vorhanden)
- Log-Dateien: /var/log/pihole_maintenance_pro_<timestamp>.log

Getestet: Raspberry Pi 3B (armhf), Pi-hole 6.x (Core/Web/FTL)

## Installation

Variante A: Installer-Skript
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"

Variante B: Manuell
  cd ~
  wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
  chmod +x pihole_maintenance_pro.sh
  sudo install -m 0755 pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh

## Nutzung
Interaktiv
  sudo /usr/local/bin/pihole_maintenance_pro.sh

Flags (Beispiele)
  sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload

Cron (So 04:00)
  0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1

## Troubleshooting

1) Meldung: Wi-Fi is currently blocked by rfkill. Use raspi-config to set the country before use.
   Ursache: WLAN-Ländercode fehlt. Fix:
     sudo raspi-config nonint do_wifi_country DE
   Optional WLAN deaktiviert lassen:
     sudo rfkill block wifi

2) sqlite3 fehlt oder Toplisten werden übersprungen
   Installation:
     sudo apt update && sudo apt install -y sqlite3
   FTL-DB vorhanden?
     ls -lh /etc/pihole/pihole-FTL.db

3) Error: unable to open database … pihole-FTL.db
   Ursache: Leserechte (Datei ist 0640 und Gruppe pihole).
   Als root lesen:
     sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
   Oder Benutzer zur Gruppe pihole:
     sudo usermod -aG pihole $USER
     newgrp pihole

4) Locale-Warnungen bei APT (LANG/LC_*)
   Aktivieren:
     echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
     sudo locale-gen
     sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8

5) 64-bit Kernel-Package auf armhf (linux-image-rpi-v8)
   Auf Pi 3B (ARMv7) ignorierbar. Es wird nicht installiert.

6) GitHub-Reachability
   Das Skript prüft DNS und HTTP. Bei Ausfall: später erneut ausführen oder DNS prüfen.






---

🧪 Tested on

Raspberry Pi 3 Model B / 3B+

Raspberry Pi OS (Bookworm, 64-bit)

Pi-hole v6.1.1 (Core), FTL 6.2.1, Web 6.2.1



---

⚠️ Disclaimer

Use at your own risk. Always review any maintenance scripts before running them on production systems.


---

📎 GitHub

https://github.com/TimInTech/pihole-maintenance-pro

Disclaimer: Nutzung auf eigene Verantwortung.
