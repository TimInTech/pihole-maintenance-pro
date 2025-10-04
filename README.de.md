<div align="center">

# 🛰️ Pi-hole Maintenance PRO MAX
**Automatisiertes Pi-hole v6 Wartungsskript**

[![Build](https://img.shields.io/github/actions/workflow/status/TimInTech/pihole-maintenance-pro/ci-sanity.yml?branch=main)](https://github.com/TimInTech/pihole-maintenance-pro/actions)
[![License](https://img.shields.io/github/license/TimInTech/pihole-maintenance-pro)](LICENSE)

<img src="https://skillicons.dev/icons?i=bash,linux" alt="Tech" />

**Languages:** ��🇪 Deutsch (diese Datei) • [🇬🇧 English](README.md)

</div>

---

## Was & Warum

Automatisiertes Pi-hole v6 Wartungsskript für Raspberry Pi OS (Bookworm) mit umfassendem Logging und Systemüberwachung.

## Features

- APT Update/Upgrade/Autoremove/Autoclean
- Pi-hole Update (`pihole -up`), Gravity (`pihole -g`), `reloaddns`  
- Systemprüfungen: Port 53, `dig`-Tests, GitHub-Verbindung
- Optional: Tailscale-Status (falls verfügbar)
- FTL-Toplisten via `sqlite3` (falls verfügbar)
- Detaillierte Logs: `/var/log/pihole_maintenance_pro_<timestamp>.log`

## Schnellstart

**Automatische Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

**Manuelle Installation:**

```bash
cd ~
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
chmod +x pihole_maintenance_pro.sh
sudo install -m 0755 pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
```

**Interaktive Verwendung:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh
```

**Verwendung mit Optionen:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

**Cron-Job (Sonntag 04:00):**

```cron
0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1
```

## Konfiguration/Flags

- `--no-apt`: APT-Paketmanagement überspringen
- `--no-upgrade`: Pi-hole Update-Prüfung überspringen
- `--no-gravity`: Gravity-Update überspringen
- `--no-dnsreload`: DNS-Reload überspringen

## Systemprüfungen

- Port 53 Konnektivitätstest
- DNS-Auflösung via `dig`
- GitHub-Erreichbarkeits-Check
- Optional: Tailscale Status-Überwachung

## Troubleshooting

1. **rfkill-Warnungen / Wi-Fi Country Code:**

   ```bash
   sudo raspi-config nonint do_wifi_country DE
   sudo rfkill block wifi   # optional
   ```

2. **sqlite3 Installation (für Top-Listen):**

   ```bash
   sudo apt update && sudo apt install -y sqlite3
   ls -lh /etc/pihole/pihole-FTL.db
   ```

3. **FTL-Datenbank Zugriffsfehler:**

   ```bash
   # Als root lesen
   sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
   # Oder Benutzer zur pihole-Gruppe hinzufügen
   sudo usermod -aG pihole $USER
   newgrp pihole
   ```

4. **Locale-Warnungen bei APT-Operationen:**

   ```bash
   echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
   sudo locale-gen
   sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
   ```

5. **Hinweis: `linux-image-rpi-v8` auf Pi 3B (ARMv7):**
   > Ignorierbare Warnung. Paket wird nicht installiert.

6. **GitHub-Erreichbarkeitsprobleme:**
   > Netzwerk/DNS prüfen und erneut ausführen.

7. **Manuelle Installation (falls Installer fehlschlägt):**

   ```bash
   chmod +x ~/pihole_maintenance_pro.sh
   sudo install -m 0755 ~/pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
   ```

8. **Top-Domains auf Abruf:**

   ```bash
   sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db \
   "SELECT domain, COUNT(*) AS hits FROM queries GROUP BY domain ORDER BY hits DESC LIMIT 10;"
   ```

## Logs

Log-Dateien werden mit Zeitstempel-Muster gespeichert: `/var/log/pihole_maintenance_pro_<timestamp>.log`

## Sicherheit/Haftungsausschluss

Verwendung dieses Skripts auf eigene Verantwortung. Prüfen Sie Skripte vor der Ausführung und stellen Sie sicher, dass Sie ordnungsgemäße Backups haben.

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe [LICENSE](LICENSE) Datei für Details.

## Changelog

**Aktuelle Version: v5.3.1**

- Neuer Installer (`scripts/install.sh`)
- Aktualisierte Dokumentation für Pi-hole 6.x Kompatibilität
- Erweiterte Troubleshooting-Anleitung für häufige Probleme
- Verbessertes Logging und Fehlerbehandlung

---

*Zuletzt aktualisiert: 2025-10-04*
