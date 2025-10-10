<div align="center">

# 🛰️ Pi-hole Maintenance PRO MAX
**Automatisiertes Pi-hole v6 Wartungsskript**

[![Build](https://img.shields.io/github/actions/workflow/status/TimInTech/pihole-maintenance-pro/ci-sanity.yml?branch=main)](https://github.com/TimInTech/pihole-maintenance-pro/actions)
[![License](https://img.shields.io/github/license/TimInTech/pihole-maintenance-pro)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Kaffee%20spendieren-Unterst%C3%BCtzen-ffdd00?logo=buymeacoffee&logoColor=000&labelColor=fff)](https://buymeacoffee.com/timintech)

<img src="https://skillicons.dev/icons?i=bash,linux" alt="Tech" />

**Sprachen:** 🇩🇪 Deutsch (diese Datei) • [🇬🇧 English](README.md)

</div>

---

## Was & Warum
Pi-hole v6 Wartung für Raspberry Pi OS (Bookworm/Trixie) mit Logging und Healthchecks.

## Features
- APT update/upgrade/autoremove/autoclean  
- Pi-hole Update (`-up`), Gravity (`-g`), `reloaddns`  
- Healthchecks: Port 53, `dig`, GitHub-Erreichbarkeit  
- Optional: Tailscale-Info, FTL-Toplisten via `sqlite3`  
- Logs: `/var/log/pihole_maintenance_pro_<timestamp>.log`

## Schnellstart
**Installer:**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

<!-- UNINSTALL:BEGIN -->
## Update / Überschreiben (sichere Re-Installation)

Zieht die aktuelle Version und überschreibt die vorhandene:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

## Uninstall (saubere Entfernung)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/uninstall.sh)"
```

> Beide Befehle sind idempotent: *Update* ersetzt die installierte Datei; *Uninstall* entfernt Script, Logs, Temp-Daten und den Cron-Eintrag.
<!-- UNINSTALL:END -->

### Flags

- `--no-apt` – APT-Schritte (update/upgrade/autoremove/autoclean) überspringen.
- `--no-upgrade` – **kein** `pihole -up`.
- `--no-gravity` – `pihole -g` (Blocklisten/Gravity) überspringen.
- `--no-dnsreload` – `pihole reloaddns` überspringen.
- `--backup` – Backup vor Pi-hole-Operationen unter `/var/backups/pihole/`.
- `--json` – JSON-Ausgabe statt farbiger Zusammenfassung.

**Manuell:**

```bash
cd ~
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
chmod +x pihole_maintenance_pro.sh
sudo install -m 0755 pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
```

**Interaktiv:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh
```

**Mit Flags:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

**Cron (So 04:00):**

```cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1
```

 > Trixie/Cron nutzt reduzierten PATH. Skript autodetektiert `pihole`, voller PATH in Cron vermeidet Probleme.

## Troubleshooting

* `sqlite3` für Top-Listen:

  ```bash
  sudo apt update && sudo apt install -y sqlite3
  ```
* Locale-Warnungen:

  ```bash
  echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
  sudo locale-gen && sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
  ```
* Hinweis `linux-image-rpi-v8` auf Pi 3B: ignorierbar.

## Lizenz

MIT. Siehe [LICENSE](LICENSE).

*Zuletzt aktualisiert: 2025-10-10 • Version: 5.3.2*

## Support
Wenn dir dieses Projekt hilft, kannst du es hier unterstützen:
[buymeacoffee.com/timintech](https://buymeacoffee.com/timintech)
