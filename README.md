# Pi-hole Maintenance PRO MAX (v5.0)

This script provides a comprehensive maintenance routine for **Pi-hole v6.x** installations. It offers colorised output, detailed logging, and an interactive step-based workflow.

---

## ✅ Features

- Step-by-step workflow with status summary
- Colored output with symbols and progress indicators
- System package update and cleanup via `apt`
- Pi-hole self-update and Gravity blocklist refresh
- Backup of `adlist` and `domainlist` using `pihole-FTL sqlite3`
- DNS reload and basic network diagnostics (ping, dig, port check)
- Statistics for top domains and clients
- Raspberry Pi health info (uptime, temperature, resource usage)
- Auto-logging to `/var/log/pihole_maintenance_pro_<timestamp>.log`
- Safe for Cron automation

---

## 📜 Changelog

### v5.0
- **Step-by-step flow** with colored status output  
- **Full logging** to `/var/log/pihole_maintenance_pro_<timestamp>.log`  
- **Native backups** via `pihole-FTL sqlite3` for `adlist` & `domainlist` (no external `sqlite3` dependency)  
- **Extra stats**: Top domains & top clients  
- **Extra Raspberry Pi health info**: uptime, temperature, resource usage  
- **Cron-ready**: OS/Pi-hole updates, gravity refresh, DNS reload, ping/dig/port checks  
- **Backup location**: `/etc/pihole/backup_v6/` (if possible)  
- **Upgrade**: Just replace the script with the latest from the repo – no setup needed  
- **Compatibility**: v5 is a drop-in replacement for v4 with improved UX/logging and integrated SQLite backup

---

## 🔧 Usage

Run the script with `sudo` or as root:

```bash
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh && \
chmod +x pihole_maintenance_pro.sh && \
sudo ./pihole_maintenance_pro.sh


---

📁 Backups

If pihole-FTL sqlite3 is available, two backup files will be saved to:

/etc/pihole/backup_v6/adlist.sql
/etc/pihole/backup_v6/domainlist.sql

Backups will be skipped if write permissions are missing.


---

🧪 Tested on

Raspberry Pi 3 Model B / 3B+

Raspberry Pi OS (Bookworm, 64-bit)

Pi-hole v6.1.1 (Core), FTL 6.2.1, Web 6.2.1



---

⚠️ Disclaimer

Use at your own risk. Always review any maintenance scripts before running them on production systems.


---

📎 GitHub

https://github.com/TimInTech/pihole-maintenance-pro

