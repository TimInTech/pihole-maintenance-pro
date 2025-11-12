#!/usr/bin/env bash
set -euo pipefail
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "This installer requires root. Re-run with sudo." >&2
  exit 1
fi
TMP="$(mktemp -d)"
RAW_BASE="https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main"
SRC="$RAW_BASE/pihole_maintenance_pro.sh"
OUT="/usr/local/bin/pihole_maintenance_pro.sh"
if ! curl -fsSL "$SRC" -o "$TMP/pihole_maintenance_pro.sh"; then
  echo "✗ Download fehlgeschlagen: $SRC" >&2
  exit 1
fi
install -m 0755 "$TMP/pihole_maintenance_pro.sh" "$OUT"

# Healthcheck-Tool bereitstellen (robust, mit Fallback)
HC_URL="$RAW_BASE/tools/pihole_api_healthcheck.sh"
HC_TMP="$TMP/pihole_api_healthcheck.sh"
HC_OUT="/usr/local/bin/pihole_api_healthcheck.sh"
if curl -fsSL "$HC_URL" -o "$HC_TMP" || curl -fsSL "$HC_URL" -o "$HC_TMP"; then
  install -m 0755 "$HC_TMP" "$HC_OUT"
  echo "Installed: $HC_OUT"
else
  # Lokaler Fallback, falls Repo geklont ausgeführt wird
  if [[ -r "$(dirname "$0")/../tools/pihole_api_healthcheck.sh" ]]; then
    install -m 0755 "$(dirname "$0")/../tools/pihole_api_healthcheck.sh" "$HC_OUT"
    echo "Installed from local repo: $HC_OUT"
  else
    echo "WARN: Healthcheck konnte nicht installiert werden (curl fehlgeschlagen, kein lokaler Fallback)." >&2
  fi
fi
# Wöchentlicher Cron, idempotent
(
  crontab -l 2> /dev/null | grep -v 'pihole_maintenance_pro.sh'
  echo "0 4 * * 0 /usr/local/bin/pihole_maintenance_pro.sh >>/var/log/pihole_maint_cron.log 2>&1"
) | crontab -
echo "Cron installed: Sundays 04:00"
echo "Troubleshooting: rfkill, sqlite3, FTL-DB-Rechte, Locale → README"
