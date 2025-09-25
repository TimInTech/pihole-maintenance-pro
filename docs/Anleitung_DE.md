# Anleitung (DE): Pi-hole Maintenance PRO MAX (v5.3.1)

## Nutzung
  sudo /usr/local/bin/pihole_maintenance_pro.sh
  sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload

## Installation
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"

## Cron
  0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1

- Logging aller Schritte in `/var/log/`

## 📁 Backup


`/var/backups/pihole_backup_<timestamp>/`

Enthalten sind:

- `pihole_backup.tar.gz` – komprimierter Snapshot von `/etc/pihole`


## 🔧 Ausführung

```bash
bash ~/pihole_maintenance_pro.sh
```

## 🔁 Automatisch via Cronjob

```cron
0 4 * * 0 bash /home/pi/pihole_maintenance_pro.sh
```

## 📝 Logfile

Wird automatisch mit Zeitstempel erstellt:
`/var/log/pihole_maintenance_pro_YYYY-MM-DD_HH-MM-SS.log`

Letzte Prüfung: 2025-08-04
