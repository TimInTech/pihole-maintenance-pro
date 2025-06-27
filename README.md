# Pi-hole Maintenance PRO

A full-featured, production-ready maintenance script for **Pi-hole v6.x**  
Compatible with Raspberry Pi (Bookworm), VMs and containers. No Unbound required.

## ✅ Features

- APT + Pi-hole core update
- Gravity + Blocklist refresh
- DNS reload
- Health checks (Ping, DIG, DNS port, FTL stats)
- Auto-backup (SQLite dump of adlist/domainlist)
- Full logging per run
- Optional tools gracefully handled (e.g. sqlite3, vcgencmd)

## 🖥️ Compatibility

- Pi-hole Core v6.x
- Raspberry Pi OS (Bookworm), Debian 12, Containers
- No Unbound required
- Works in minimal setups and VMs

## 📦 Quick Install

```bash
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
chmod +x pihole_maintenance_pro.sh
./pihole_maintenance_pro.sh
```

> 💡 Add it to your crontab for weekly auto-maintenance.

## 📄 Log Output

Saved to `/var/log/pihole_maintenance_YYYY-MM-DD.log`
