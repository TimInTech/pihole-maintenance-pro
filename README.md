# 🛰️ Pi-hole Maintenance PRO MAX

**Automated Pi-hole v6 Maintenance Script**

[![Build](https://img.shields.io/github/actions/workflow/status/TimInTech/pihole-maintenance-pro/ci-sanity.yml?branch=main)](https://github.com/TimInTech/pihole-maintenance-pro/actions)
[![License](https://img.shields.io/github/license/TimInTech/pihole-maintenance-pro)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-Donate-ffdd00?logo=buymeacoffee&logoColor=000&labelColor=fff)](https://buymeacoffee.com/timintech)

<img src="https://skillicons.dev/icons?i=bash,linux" alt="Tech" />

**Languages:** 🇬🇧 English (this file) • [🇩🇪 Deutsch](README.de.md)

---

## What & Why

Automated Pi-hole v6 maintenance script for Raspberry Pi OS (Bookworm/Trixie) with logging and health checks.

## Features

- APT update/upgrade/autoremove/autoclean
- Pi-hole update (`-up`), gravity (`-g`), optional FTL restart (`--restart-ftl`)
- Health checks: port 53, `dig`, GitHub reachability
- Optional Tailscale info, FTL toplists via `sqlite3`
- Performance dashboard & intelligent end-of-run summary
- Automatic local backup prior to Pi-hole changes
- Installer drops a weekly cron (`0 4 * * 0`) out of the box (idempotent)
- Logs in `/var/log/pihole_maintenance_pro_<timestamp>.log`

## Quickstart

**Installer:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

<!-- UNINSTALL:BEGIN -->
## Update / Overwrite (safe re-install)

Use this to pull and overwrite with the latest release:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

## Uninstall (clean removal)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/uninstall.sh)"
```

> These commands are idempotent: *Update* always replaces the installed script; *Uninstall* removes the script, logs, temp data, and the cron entry.
<!-- UNINSTALL:END -->

### Flags

- `--no-apt` – skips APT steps (update/upgrade/autoremove/autoclean)
- `--no-upgrade` – does **not** run `pihole -up`
- `--no-gravity` – skips `pihole -g` (blocklists/Gravity update)
- `--no-dnsreload` – deprecated in v6 (no-op)
- `--restart-ftl` – restart pihole-FTL at the end (v6: only if needed)
- `--backup` – creates a backup before Pi-hole ops under `/var/backups/pihole/`
- `--json` – outputs machine-readable JSON instead of the colored TUI

**Manual installation:**

```bash
cd ~
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
chmod +x pihole_maintenance_pro.sh
sudo install -m 0755 pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
```

**Interactive usage:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh
```

**With flags:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

## Real Pi-hole v6 sample run

Captured on a Raspberry Pi with Pi-hole Core 6.1.4, Web 6.2.1, FTL 6.2.3 — this is the live dashboard + summary rendered by the current release:

```bash
╔═══════════════ PERFORMANCE DASHBOARD ═══════════════╗
║ 🚀 Load: 1.81     💾 RAM: 23%    🌡  Temp: 50°C    🗄  Disk: 9% ║
╚═══════════════════════════════════════════════════════╝

════════ INTELLIGENTE ZUSAMMENFASSUNG ════════
  #00  🌍 Network    IP: 192.168.178.21                 ✔ OK
  #03  🛡  Pi-hole    v6.1.4                         ✔ OK
  #07  🔍 Health     4 listeners                        ✔ OK
  #08  🌐 DNS Ext    172.217.16.78                      ✔ OK
  #09  🏠 DNS Local  127.0.0.1                          ✔ OK
  #12  📊 FTL Query  24h: 141222 queries, 1% blocked    ✔ OK
  #13  👥 FTL Client 25 active clients                  ✔ OK
```

> **Output note (v5.3.2 refresh):** per-step live lines now use a unified, timestamped
> format (`[HH:MM:SS] OK|WARN|ERR …`) instead of `✔ Erfolg`/`⚠ Warnung`. The end-of-run
> dashboard and summary shown above are unchanged. `SIGINT`/`SIGTERM` (Ctrl-C) now render the
> summary and clean up the temp dir exactly once. All flags, JSON output and steps are identical.

The same production run confirms:

- Backups are created before Pi-hole maintenance kicks in (e.g. `/etc/pihole/backup_20251025_100315`, `/etc/pihole/backup_20251025_100337`)
- The installer provisions the recommended cron automatically: `0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1`
- Security (Steps 20–26) and health checks (Steps 07–10) run green end-to-end

**Recommended cron jobs:**

```cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/30 * * * * /usr/local/bin/pihole_api_healthcheck.sh >> /var/log/pihole_healthcheck.log 2>&1
30 3 * * * /usr/local/bin/pihole_maintenance_pro.sh >> /var/log/pihole_maintenance_pro.log 2>&1
```

> Trixie/cron runs with a reduced PATH. Using a full PATH ensures both scripts run reliably. The installer now sets the weekly cron idempotently.

## Pi-hole v6 API notes

- `setupVars.conf` is gone
- Config lives in `/etc/pihole/pihole.toml`
- API is served at `/api` instead of `/api.php`
- Authentication uses session tokens: `POST /api/auth` returns `sid`, pass via header `X-FTL-SID`
- The healthcheck script (`tools/pihole_api_healthcheck.sh`) can hit endpoints when `PIHOLE_API_URL` is set; set `PIHOLE_PASSWORD` to enable session login
- Unbound is optional

## Troubleshooting

- `sqlite3` toplists:

  ```bash
  sudo apt update && sudo apt install -y sqlite3
  ```

* Locale warnings:

  ```bash
  echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
  sudo locale-gen && sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
  ```

* Pi 3B note about `linux-image-rpi-v8`: ignorable on ARMv7.

## License

MIT. See [LICENSE](LICENSE).

*Last updated: 2025-10-25 • Version: 5.3.2*

## Support

If this project helps you, you can support it here:
[buymeacoffee.com/timintech](https://buymeacoffee.com/timintech)
