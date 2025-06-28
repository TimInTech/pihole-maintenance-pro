# Pi-hole Maintenance PRO (v4.4)

This script is designed to simplify regular maintenance tasks for **Pi-hole v6.x** installations. It covers system and Pi-hole updates, blocklist refresh, service checks, optional backups, and logging – tailored for Raspberry Pi OS (Bookworm) and Debian-based systems.

---

## ✅ Features

- System package update via `apt`
- Pi-hole self-update via `pihole -up`
- Gravity database rebuild (blocklist update)
- Optional FTL stats overview & health checks
- Backup of `adlist` and `domainlist` using Pi-hole v6.x schema
- Uses **embedded** SQLite engine via `pihole-FTL sqlite3`
- Auto-logging to `/var/log/pihole_maintenance_<date>.log`
- Safe for Cron automation

---

## 🔧 Usage

Run the script with `sudo` or as root:

```bash
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh && \
chmod +x pihole_maintenance_pro.sh && \
sudo ./pihole_maintenance_pro.sh
```

---

## 📁 Backups

If `pihole-FTL sqlite3` is available, two backup files will be saved to:

```
/etc/pihole/backup_v6/adlist.sql
/etc/pihole/backup_v6/domainlist.sql
```

Backups will be skipped if write permissions are missing.

---

## 🧪 Tested on

- Raspberry Pi 3 Model B / 3B+
- Raspberry Pi OS (Bookworm, 64-bit)
- Pi-hole v6.1.1 (Core), FTL 6.2.1, Web 6.2.1

---

## 💡 Notes

- The script **does not require external SQLite binaries**.
- No Docker, no Unbound – minimal, clean environment.
- Log file is created automatically under `/var/log/`.

---

## ⚠️ Disclaimer

Use at your own risk. Always review any maintenance scripts before running them on production systems.

---

## 📎 GitHub

[https://github.com/TimInTech/pihole-maintenance-pro](https://github.com/TimInTech/pihole-maintenance-pro)
