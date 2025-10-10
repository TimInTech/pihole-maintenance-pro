# 🛰️ Pi-hole Maintenance PRO MAX
**Automated Pi-hole v6 Maintenance Script**

[![Build](https://img.shields.io/github/actions/workflow/status/TimInTech/pihole-maintenance-pro/ci-sanity.yml?branch=main)](https://github.com/TimInTech/pihole-maintenance-pro/actions)
[![License](https://img.shields.io/github/license/TimInTech/pihole-maintenance-pro)](LICENSE)

<img src="https://skillicons.dev/icons?i=bash,linux" alt="Tech" />

**Languages:** 🇬🇧 English (this file) • [🇩🇪 Deutsch](README.de.md)

</div>

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
````

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

**Cron example (Sunday 04:00):**

```cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1
```

> The script now auto-detects the `pihole` binary, but setting a full `PATH` in cron avoids distro-specific surprises.

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

