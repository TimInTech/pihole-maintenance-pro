# Pi-hole Maintenance PRO MAX (v5.1.2)

This script provides a comprehensive maintenance routine for **Pi-hole v6.x** installations. It offers colorised output, detailed logging, and an interactive step-based workflow.

---

## ✅ Features

- Step-by-step workflow with status summary
- Colored output with symbols and progress indicators
- System package update and cleanup via `apt`
- Pi-hole self-update and Gravity blocklist refresh

- DNS reload and basic network diagnostics (ping, dig, port check)
- Statistics for top domains and clients
- Raspberry Pi health info (uptime, temperature, resource usage)
- Auto-logging to `/var/log/pihole_maintenance_pro_<timestamp>.log`
- Safe for Cron automation

---

## 📜 Changelog

### v5.1.2
- **New backup destination**: `/var/backups/pihole_backup_<timestamp>/` stores each run in its own directory
- **Split backup flow**: separate steps for tarball, Gravity `adlist` dump, and FTL schema export with clearer progress output
- **FTL schema dump** now included alongside the Gravity backup for easier inspection

### v5.0


---

## 🔧 Usage

Run the script with `sudo` or as root:

```bash
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh && \
chmod +x pihole_maintenance_pro.sh && \
sudo ./pihole_maintenance_pro.sh
```


---






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

