# Anleitung DE – Pi-hole Maintenance PRO MAX (v5.3.2)

## Nutzung

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

## Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

## Cron

```cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/30 * * * * /usr/local/bin/pihole_api_healthcheck.sh >> /var/log/pihole_healthcheck.log 2>&1
30 3 * * * /usr/local/bin/pihole_maintenance_pro.sh >> /var/log/pihole_maintenance_pro.log 2>&1
```

> Hinweis: Cron nutzt oft einen reduzierten PATH. Der vollständige PATH stellt sicher, dass beide Skripte korrekt laufen.

## Troubleshooting (kurz)

- rfkill → `do_wifi_country DE`; optional `rfkill block wifi`
- sqlite3 installieren: `apt install -y sqlite3`
- FTL-DB Rechte testen:

  ```bash
  sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
  ```

- Locale setzen:

  ```bash
  echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
  sudo locale-gen && sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
  ```

## Pi-hole v6 API

- Keine `setupVars.conf` mehr
- Konfiguration in `/etc/pihole/pihole.toml`
- API unter `/api` (nicht `/api.php`)
- Authentifizierung via Session: `POST /api/auth` → `sid`, danach Header `X-FTL-SID`
- Healthcheck nutzt `PIHOLE_API_URL` und optional `PIHOLE_PASSWORD` für Login
- Unbound ist optional
