# 🇩🇪 Anleitung: Pi-hole Maintenance PRO

Dieses Skript dient der vollständigen Pflege und Wartung eines Pi-hole v6.x Systems auf einem Raspberry Pi.

## 🧰 Funktionen

- Systemupdate via `apt`
- Pi-hole Core Update
- Gravity / Blocklists aktualisieren
- DNS neu laden
- Healthchecks (Ping, dig, Port 53, FTL)
- SQLite-Backup der `adlist` & `domainlist`
- Logging aller Schritte in `/var/log/`

## 🔧 Ausführung

```bash
bash ~/pihole_maintenance_pro.sh
```

## 🔁 Automatisch via Cronjob

```cron
0 4 * * 0 bash /home/pi/pihole_maintenance_pro.sh
```

## 📝 Logfile

Wird automatisch täglich erstellt:  
`/var/log/pihole_maintenance_YYYY-MM-DD.log`

Letzte Prüfung: 2025-06-27
