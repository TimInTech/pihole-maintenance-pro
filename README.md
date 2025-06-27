# Pi-hole Maintenance PRO

A full-featured, production-ready maintenance script for **Pi-hole v6.x**  
Designed for Raspberry Pi environments running **Bookworm**, no Unbound required.

## ✅ Features

- APT + Pi-hole core update
- Gravity + Blocklist refresh
- DNS reload
- Health checks (Ping, DIG, DNS port, FTL stats)
- Auto-backup (SQLite dump of adlist/domainlist)
- Full logging per run

## 🖥️ Compatibility

- Pi-hole Core v6.x
- Raspberry Pi OS (Bookworm)
- No Unbound required
- Cronjob-ready

## 📦 Quick Install

```bash
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
chmod +x pihole_maintenance_pro.sh
./pihole_maintenance_pro.sh
```

> 💡 Add it to your crontab for weekly auto-maintenance.

## 📚 Documentation

- [🇩🇪 German Guide (Anleitung_DE.md)](docs/Anleitung_DE.md)
