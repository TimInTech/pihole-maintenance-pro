# 🇩🇪 Anleitung: Pi-hole Maintenance PRO MAX

Dieses Skript dient der vollständigen Pflege und Wartung eines Pi-hole v6.x Systems auf einem Raspberry Pi. Es bietet farbige Ausgabe, detailliertes Logging und eine strukturierte Schritt-für-Schritt-Ausführung.

## 🧰 Funktionen

- Systemupdate via `apt` inklusive Autoclean/Autoremove
- Pi-hole Core Update & Gravity Aktualisierung
- DNS neu laden
- Healthchecks (Ping, dig, Port 53, FTL)
- Statistiken zu Top-Domains und -Clients
- Ressourcen- und Temperaturanzeige des Raspberry Pi
- SQLite-Backup der `adlist` & des FTL-Schemas
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

Wird automatisch mit Zeitstempel erstellt:
`/var/log/pihole_maintenance_pro_YYYY-MM-DD_HH-MM-SS.log`

Letzte Prüfung: 2025-08-04
