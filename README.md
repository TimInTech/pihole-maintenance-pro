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
- Pi-hole update (`-up`), gravity (`-g`), `reloaddns`  
- Health checks: port 53, `dig`, GitHub reachability  
- Optional Tailscale info, FTL toplists via `sqlite3`  
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
- `--no-dnsreload` – skips `pihole reloaddns`  
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

**Recommended cron jobs:**

```cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/30 * * * * /usr/local/bin/pihole_api_healthcheck.sh >> /var/log/pihole_healthcheck.log 2>&1
30 3 * * * /usr/local/bin/pihole_maintenance_pro.sh >> /var/log/pihole_maintenance_pro.log 2>&1
```

> Trixie/Cron uses a reduced PATH. Defining the full PATH keeps both scripts working reliably.

## Pi-hole v6 API notes

- No `setupVars.conf` anymore
- Configuration lives in `/etc/pihole/pihole.toml`
- API is served from `/api`, not `/api.php`
- Authentication uses HTTP Basic Auth (`cli` user + `/etc/pihole/cli_pw`)
- Example tooling: `tools/pihole_api_healthcheck.sh`
- `unbound` is not required

## Troubleshooting

* `sqlite3` toplists:

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

*Last updated: 2025-10-10 • Version: 5.3.2*

## Support
If this project helps you, you can support it here:
[buymeacoffee.com/timintech](https://buymeacoffee.com/timintech)
