# Pi-hole Maintenance PRO

A full-featured, production-ready maintenance script for **Pi-hole v6.x**  
Works on Raspberry Pi OS (Bookworm), Debian 12, VMs, containers, and headless systems.

## ✅ Features

- System updates (`apt`) and Pi-hole updates
- Gravity / Blocklist refresh
- DNS reload
- Health checks (`ping`, `dig`, port 53, FTL queries)
- Optional SQLite backup of adlist/domainlist
- Auto-logging to `/var/log/` per execution
- Compatible with minimal systems (sqlite3 and vcgencmd checks included)

## ⚠️ Requirements

- Must be run with `sudo` or as root
- Pi-hole v6.x installed
- Optional tools: `sqlite3`, `vcgencmd`

## 📦 Quick Install

```bash
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh && chmod +x pihole_maintenance_pro.sh && sudo ./pihole_maintenance_pro.sh
```

## 📄 Output

Logs are saved to:

```
/var/log/pihole_maintenance_YYYY-MM-DD.log
```

## 🔄 Cronjob Example

Run every Sunday at 4:00 AM:

```cron
0 4 * * 0 /home/pi/pihole_maintenance_pro.sh
```

## License

MIT
