<div align="center">

# 🛰️ Pi-hole Maintenance PRO MAX
**Automated Pi-hole v6 Maintenance Script**

[![Build](https://img.shields.io/github/actions/workflow/status/TimInTech/pihole-maintenance-pro/ci-sanity.yml?branch=main)](https://github.com/TimInTech/pihole-maintenance-pro/actions)
[![License](https://img.shields.io/github/license/TimInTech/pihole-maintenance-pro)](LICENSE)

<img src="https://skillicons.dev/icons?i=bash,linux" alt="Tech" />

**Languages:** 🇬🇧 English (this file) • [🇩🇪 Deutsch](README.de.md)

</div>

---

## What & Why

Automated Pi-hole v6 maintenance script for Raspberry Pi OS (Bookworm) with comprehensive logging and health monitoring.

## Features

- APT Update/Upgrade/Autoremove/Autoclean
- Pi-hole Update (`pihole -up`), Gravity (`pihole -g`), `reloaddns`  
- Healthchecks: Port 53, `dig`-Tests, GitHub-Reachability
- Optional: Tailscale-Status (if available)
- FTL-Toplisten via `sqlite3` (if available)
- Log files: `/var/log/pihole_maintenance_pro_<timestamp>.log`

## Quickstart

**Installer (from main branch):**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

**Manual Installation:**

```bash
cd ~
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
chmod +x pihole_maintenance_pro.sh
sudo install -m 0755 pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
```

**Interactive Usage:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh
```

**Usage with Flags:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

**Cron Example (Sunday 04:00):**

```cron
0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1
```

## Configuration/Flags

- `--no-apt`: Skip APT package management
- `--no-upgrade`: Skip Pi-hole upgrade check
- `--no-gravity`: Skip gravity update
- `--no-dnsreload`: Skip DNS reload

## Healthchecks

- Port 53 connectivity test
- DNS resolution tests via `dig`
- GitHub reachability check
- Optional Tailscale status monitoring

## Troubleshooting

1. **rfkill-Hinweis / Wi-Fi Country Code:**

   ```bash
   sudo raspi-config nonint do_wifi_country DE
   sudo rfkill block wifi   # optional
   ```

2. **sqlite3 installation (for Top Lists):**

   ```bash
   sudo apt update && sudo apt install -y sqlite3
   ls -lh /etc/pihole/pihole-FTL.db
   ```

3. **FTL Database Permission Issues:**

   ```bash
   # Read as root
   sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
   # Or add user to pihole group
   sudo usermod -aG pihole $USER
   newgrp pihole
   ```

4. **Locale Warnings during APT operations:**

   ```bash
   echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
   sudo locale-gen
   sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
   ```

5. **Note: `linux-image-rpi-v8` on Pi 3B (ARMv7):**
   > Ignorable warning. Package will not be installed.

6. **GitHub Reachability Issues:**
   > Check network/DNS and retry execution.

7. **Manual Installation (if installer fails):**

   ```bash
   chmod +x ~/pihole_maintenance_pro.sh
   sudo install -m 0755 ~/pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
   ```

8. **Top Domains on-demand:**

   ```bash
   sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db \
   "SELECT domain, COUNT(*) AS hits FROM queries GROUP BY domain ORDER BY hits DESC LIMIT 10;"
   ```

## Logs

Log files are saved with timestamp pattern: `/var/log/pihole_maintenance_pro_<timestamp>.log`

## Security/Disclaimer

Use this script at your own risk. Always review scripts before execution and ensure you have proper backups.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

**Current Version: v5.3.1**

- New installer (`scripts/install.sh`)
- Updated documentation for Pi-hole 6.x compatibility
- Enhanced troubleshooting guide for common issues
- Improved logging and error handling

---

*Last updated: 2025-10-04*
