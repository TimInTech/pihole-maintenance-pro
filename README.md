# Pi-hole Maintenance PRO MAX (v5.3.1)

Wartungsskript für **Pi-hole 6.x** auf Raspberry Pi OS (Bookworm). Schritte mit Logging nach `/var/log/`.  
Kein Unbound vorausgesetzt. PADD kompatibel.

## Features
- APT Update/Upgrade/Autoremove/Autoclean
- Pi-hole Update (`pihole -up`), Gravity (`pihole -g`), `reloaddns`
- Healthchecks: Port 53, `dig`-Tests, GitHub-Reachability
- Optional: Tailscale-Status
- FTL-Toplisten via `sqlite3` (wenn vorhanden)
- Log-Datei: `/var/log/pihole_maintenance_pro_<timestamp>.log`

## Installation
**Variante A: Installer**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

**Variante B: Manuell**
```bash
cd ~
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
chmod +x pihole_maintenance_pro.sh
sudo install -m 0755 pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
```

## Nutzung
**Interaktiv**
```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh
```

**Beispiele (Flags)**
```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

**Cron (So 04:00)**
```cron
0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1
```

## Troubleshooting (praxisbewährt)
1) **rfkill-Hinweis**
```bash
sudo raspi-config nonint do_wifi_country DE
sudo rfkill block wifi   # optional
```

2) **sqlite3 fehlt / Toplisten übersprungen**
```bash
sudo apt update && sudo apt install -y sqlite3
ls -lh /etc/pihole/pihole-FTL.db
```

3) **FTL-DB „unable to open … pihole-FTL.db“**
```bash
# als root lesen
sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
# oder Benutzer zur Gruppe pihole
sudo usermod -aG pihole $USER
newgrp pihole
```

4) **Locale-Warnungen bei APT**
```bash
echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
sudo locale-gen
sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
```

5) **Hinweis `linux-image-rpi-v8` auf Pi 3B (ARMv7)**
> Ignorierbar. Paket wird nicht installiert.

6) **GitHub-Reachability**
> Netzwerk/DNS prüfen und erneut ausführen.

7) **Installer 404 (Altzustände)**
```bash
chmod +x ~/pihole_maintenance_pro.sh
sudo install -m 0755 ~/pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
```

8) **Top-Domains on-demand**
```bash
sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db \
"SELECT domain, COUNT(*) AS hits FROM queries GROUP BY domain ORDER BY hits DESC LIMIT 10;"
```

## Skript-Hinweise (robust)
- SQL nur, wenn `sqlite3` vorhanden **und** `/etc/pihole/pihole-FTL.db` lesbar.
- rfkill-Meldungen vermeiden: Ländercode setzen, optional WLAN blockieren.

## Changelog
**v5.3.1**
- Neuer Installer (`scripts/install.sh`)
- README/Anleitung: rfkill, sqlite3, FTL-DB-Rechte, Locale
- Klarere Hinweise für Pi-hole 6.x

_Disclaimer: Nutzung auf eigene Verantwortung._

<- Updated all documentation for new GitHub repository touch: 2025-10-04T15:28:04+02:00 -->
