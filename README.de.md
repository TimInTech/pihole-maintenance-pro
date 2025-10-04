# Pi-hole Maintenance PRO MAX (v5.3.1)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

**🇩🇪 Deutsche Version | 🇬🇧 [English Version](README.md)**

Wartungsskript für **Pi-hole 6.x** auf Raspberry Pi OS (Bookworm). Vollständige Wartung mit Logging nach `/var/log/`.

## Features
- APT Update/Upgrade/Autoremove/Autoclean
- Pi-hole Update (`pihole -up`), Gravity (`pihole -g`), `reloaddns`
- Systemprüfungen: Port 53, `dig`-Tests, GitHub-Verbindung
- Optional: Tailscale-Status
- FTL-Toplisten via `sqlite3` (wenn verfügbar)
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

## Verwendung

**Interaktiv ausführen:**
```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh
```

**Mit Optionen:**
```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

**Cron-Job (Sonntag 04:00):**
```cron
0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1
```

## Konfiguration

Das Skript erkennt automatisch:
- Pi-hole 6.x Installation
- Verfügbare Tools (`sqlite3`, `dig`, `tailscale`)
- System-Services und Ports

## Troubleshooting

### Häufige Probleme

1. **rfkill-Warnungen**
```bash
sudo raspi-config nonint do_wifi_country DE
sudo rfkill block wifi   # optional
```

2. **sqlite3 fehlt**
```bash
sudo apt update && sudo apt install -y sqlite3
```

3. **FTL-Datenbank Zugriffsfehler**
```bash
sudo usermod -aG pihole $USER
newgrp pihole
```

4. **Locale-Warnungen**
```bash
sudo locale-gen de_DE.UTF-8
sudo update-locale LANG=de_DE.UTF-8
```

### Log-Analyse
```bash
# Aktuelle Logs anzeigen
sudo tail -f /var/log/pihole_maintenance_pro_*.log

# Letzte Ausführung prüfen
ls -lat /var/log/pihole_maintenance_pro_*.log | head -1
```

## Health Checks

Das Skript prüft automatisch:
- Port 53 (DNS) Verfügbarkeit
- DNS-Auflösung via `dig`
- GitHub-Konnektivität
- Pi-hole FTL Service-Status

## Lizenz

MIT License - siehe [LICENSE](LICENSE) Datei.

## Changelog

**v5.3.1** (2025-10-04)
- Verbesserter Installer (`scripts/install.sh`)
- Erweiterte Dokumentation und Troubleshooting
- Pi-hole 6.x Kompatibilität bestätigt

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

_Haftungsausschluss: Nutzung auf eigene Verantwortung._