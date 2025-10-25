#!/usr/bin/env bash
# ============================================================================
# Pi-hole API Healthcheck (v6-ready)
# Collects local diagnostics and (optionally) queries the Pi-hole v6 JSON API.
# Usage examples:
#   bash tools/pihole_api_healthcheck.sh
#   bash tools/pihole_api_healthcheck.sh --json
#   PIHOLE_API_URL="http://localhost/api" bash tools/pihole_api_healthcheck.sh
# Note: Works without root, but sqlite3 + cli_pw access may require sudo.
# ============================================================================
set -euo pipefail
IFS=$'\n\t'

CLI_PW_PATH="/etc/pihole/cli_pw"
FTL_DB_PATH="/etc/pihole/pihole-FTL.db"

JSON_OUTPUT=0

usage() {
  cat <<'EOF'
Usage: pihole_api_healthcheck.sh [--json]

Collects local Pi-hole health metrics (CLI, FTL, DNS listeners, sqlite3 stats,
temperature, load, memory, disk). When PIHOLE_API_URL is set and the Pi-hole
CLI password is readable, performs authenticated Basic Auth requests (user
"cli") against the Pi-hole v6 API endpoints /stats/summary and /stats/top_clients.

Options:
  --json     Emit machine-readable JSON instead of human-readable text
  -h, --help Show this help message
EOF
}

while (($#)); do
  case "$1" in
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

timestamp="$(date --iso-8601=seconds)"

TMP_FILES=()
cleanup() {
  for f in "${TMP_FILES[@]:-}"; do
    [[ -n "$f" && -e "$f" ]] && rm -f "$f"
  done
}
trap cleanup EXIT

hostname_value="$(hostname 2>/dev/null || uname -n || echo 'unknown')"
hostname_value="${hostname_value%%$'\n'*}"

ipv4_address="unknown"
if command -v ip > /dev/null 2>&1; then
  while IFS= read -r addr; do
    ipv4_address="${addr%%/*}"
    [[ -n "$ipv4_address" ]] && break
  done < <(ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}' || true)
fi
if [[ "$ipv4_address" == "unknown" ]]; then
  if command -v hostname > /dev/null 2>&1; then
    addr_line="$(hostname -I 2>/dev/null || true)"
    if [[ -n "$addr_line" ]]; then
      ipv4_address="$(tr ' ' '\n' <<<"$addr_line" | grep -m1 -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)"
      [[ -z "$ipv4_address" ]] && ipv4_address="unknown"
    fi
  fi
fi
[[ -z "$ipv4_address" ]] && ipv4_address="unknown"

ftl_service_state="unknown"
ftl_active_state="null"
if command -v systemctl > /dev/null 2>&1; then
  ftl_output="$(systemctl is-active pihole-FTL 2>&1 || true)"
  ftl_service_state="$ftl_output"
  if [[ "$ftl_output" == "active" ]]; then
    ftl_active_state="true"
  elif [[ "$ftl_output" == "inactive" || "$ftl_output" == "failed" ]]; then
    ftl_active_state="false"
  fi
else
  ftl_service_state="systemctl not available"
fi

blocking_status="UNKNOWN"
pihole_status_output=""
if command -v pihole > /dev/null 2>&1; then
  pihole_status_output="$(pihole status 2>&1 || true)"
  if grep -qi 'enabled' <<<"$pihole_status_output"; then
    blocking_status="ENABLED"
  elif grep -qi 'disabled' <<<"$pihole_status_output"; then
    blocking_status="DISABLED"
  else
    blocking_status="UNKNOWN"
  fi
else
  blocking_status="pihole CLI not found"
fi

dns_udp_v4="null"
dns_tcp_v4="null"

check_socket() {
  local proto="$1" pattern="$2"
  if command -v ss > /dev/null 2>&1; then
    if ss "-${proto}"ln 2>/dev/null | grep -qE "$pattern"; then
      echo "true"
      return
    fi
    echo "false"
    return
  fi
  if command -v netstat > /dev/null 2>&1; then
    if netstat "-${proto}"ln 2>/dev/null | grep -qE "$pattern"; then
      echo "true"
      return
    fi
    echo "false"
    return
  fi
  echo "null"
}

udp_result="$(check_socket u '0\.0\.0\.0:53|127\.0\.0\.1:53')"
tcp_result="$(check_socket t '0\.0\.0\.0:53|127\.0\.0\.1:53')"
dns_udp_v4="$udp_result"
dns_tcp_v4="$tcp_result"

traffic_total_24h=""
traffic_blocked_24h=""
traffic_blocked_percent=""
traffic_note=""

top_clients_note=""
declare -a TOP_CLIENTS_LOCAL=()

if command -v sqlite3 > /dev/null 2>&1; then
  if [[ -r "$FTL_DB_PATH" ]]; then
    top_clients_raw="$(sqlite3 -readonly "$FTL_DB_PATH" "
      SELECT COALESCE(client,'unknown'), COUNT(*) AS total
      FROM queries
      WHERE timestamp >= strftime('%s','now','-86400 seconds')
      GROUP BY client
      ORDER BY total DESC
      LIMIT 5;
    " 2>/dev/null || true)"
    if [[ -n "$top_clients_raw" ]]; then
      while IFS='|' read -r client count; do
        [[ -z "$client" ]] && continue
        [[ -z "$count" ]] && continue
        TOP_CLIENTS_LOCAL+=("$client|$count")
      done <<<"$top_clients_raw"
    fi

    totals_raw="$(sqlite3 -readonly "$FTL_DB_PATH" "
      WITH recent AS (
        SELECT status FROM queries
        WHERE timestamp >= strftime('%s','now','-86400 seconds')
      )
      SELECT
        COUNT(*) AS total,
        SUM(
          CASE
            WHEN status IN (1,4,5,6,7,8,9,10,11,12,13,14,15) THEN 1
            ELSE 0
          END
        ) AS blocked
      FROM recent;
    " 2>/dev/null || true)"
    if [[ "$totals_raw" =~ ^([0-9]+)\|([0-9]+)$ ]]; then
      traffic_total_24h="${BASH_REMATCH[1]}"
      traffic_blocked_24h="${BASH_REMATCH[2]}"
      if [[ "$traffic_total_24h" != "0" ]]; then
        traffic_blocked_percent="$(awk -v b="$traffic_blocked_24h" -v t="$traffic_total_24h" 'BEGIN { if (t > 0) printf "%.1f", (b/t)*100 }')"
      else
        traffic_blocked_percent="0.0"
      fi
    else
      traffic_note="sqlite3 returned unexpected totals"
    fi
  else
    traffic_note="FTL database not readable (try sudo?)"
    top_clients_note="FTL database not readable (try sudo?)"
  fi
else
  traffic_note="sqlite3 not installed"
  top_clients_note="sqlite3 not installed"
fi

cpu_temp_c=""
if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
  raw_temp="$(< /sys/class/thermal/thermal_zone0/temp)"
  if [[ "$raw_temp" =~ ^[0-9]+$ ]]; then
    cpu_temp_c="$(awk -v val="$raw_temp" 'BEGIN { printf "%.1f", val / 1000 }')"
  fi
elif command -v vcgencmd > /dev/null 2>&1; then
  vcgencmd_out="$(vcgencmd measure_temp 2>/dev/null || true)"
  if [[ "$vcgencmd_out" =~ temp=([0-9]+(\.[0-9]+)?)\'C ]]; then
    cpu_temp_c="${BASH_REMATCH[1]}"
  fi
fi

load_avg=""
if [[ -r /proc/loadavg ]]; then
  load_avg="$(awk '{printf "%s,%s,%s", $1, $2, $3}' /proc/loadavg)"
else
  load_avg="$(uptime 2>/dev/null || echo "unknown")"
fi

ram_used_pct=""
if command -v free > /dev/null 2>&1; then
  ram_used_pct="$(free -m | awk '/Mem:/ { if ($2 > 0) printf "%.0f", ($3/$2)*100 }')"
fi

disk_used_pct=""
if command -v df > /dev/null 2>&1; then
  disk_used_pct="$(df -P / | awk 'NR==2 {gsub(\"%\", \"\", $5); print $5}')"
fi

<<<<<<< HEAD
=======
uptime_summary=""
if command -v uptime > /dev/null 2>&1; then
  uptime_summary="$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo 'unknown')"
  uptime_summary="${uptime_summary//$'\n'/}"
fi

>>>>>>> 6cc1a47 (feat: add Pi-hole v6 healthcheck, update security step, refresh docs for v6 API)
cli_password=""
if [[ -r "$CLI_PW_PATH" ]]; then
  cli_password="$(tr -d '\r\n' < "$CLI_PW_PATH")"
fi

api_url="${PIHOLE_API_URL:-}"
<<<<<<< HEAD
api_note=""
=======
[[ -n "$api_url" ]] && api_url="${api_url%/}"
api_status="API not queried (PIHOLE_API_URL unset)"
api_used_basic_auth="false"
api_context=0
>>>>>>> 6cc1a47 (feat: add Pi-hole v6 healthcheck, update security step, refresh docs for v6 API)
api_summary_body=""
api_summary_http=""
api_summary_note=""
api_top_clients_body=""
api_top_clients_http=""
api_top_clients_note=""
declare -a TOP_CLIENTS_API=()
api_total_override=""
api_blocked_override=""
api_percent_override=""
<<<<<<< HEAD
=======
auth_token=""
>>>>>>> 6cc1a47 (feat: add Pi-hole v6 healthcheck, update security step, refresh docs for v6 API)

call_api_endpoint() {
  local endpoint="$1" body_ref="$2" code_ref="$3" note_ref="$4"
  local tmp_body tmp_code tmp_err
  tmp_body="$(mktemp -t pihole_api_body_XXXX)"
  tmp_code="$(mktemp -t pihole_api_code_XXXX)"
  tmp_err="$(mktemp -t pihole_api_err_XXXX)"
  TMP_FILES+=("$tmp_body" "$tmp_code" "$tmp_err")

  if ! curl -sS -m 7 \
      -H "Authorization: Basic $auth_token" \
      -H "Accept: application/json" \
      -o "$tmp_body" \
      -w '%{http_code}' \
      "$api_url/$endpoint" > "$tmp_code" 2>"$tmp_err"; then
    printf -v "$body_ref" ""
    printf -v "$code_ref" "000"
    local err_msg
    err_msg="$(tr '\n' ' ' < "$tmp_err" | sed 's/[[:space:]]\+/ /g')"
    printf -v "$note_ref" "curl failed: %s" "$err_msg"
    return
  fi

  printf -v "$body_ref" "%s" "$(cat "$tmp_body")"
  printf -v "$code_ref" "%s" "$(cat "$tmp_code")"
  local err_content
  err_content="$(tr '\n' ' ' < "$tmp_err" | sed 's/[[:space:]]\+/ /g')"
  printf -v "$note_ref" "%s" "$err_content"
}

if [[ -n "$api_url" ]]; then
  if [[ -z "$cli_password" ]]; then
<<<<<<< HEAD
    api_note="PIHOLE_API_URL set but $CLI_PW_PATH not readable"
  elif ! command -v curl > /dev/null 2>&1; then
    api_note="curl not installed; skipping API calls"
  elif ! command -v base64 > /dev/null 2>&1; then
    api_note="base64 not installed; skipping API calls"
  else
    auth_token="$(printf 'cli:%s' "$cli_password" | base64 | tr -d $'\n')"
    api_note="API mode enabled"
    call_api_endpoint "stats/summary" api_summary_body api_summary_http api_summary_note
    call_api_endpoint "stats/top_clients" api_top_clients_body api_top_clients_http api_top_clients_note
  fi
else
  api_note="API not queried (PIHOLE_API_URL unset)"
=======
    api_status="PIHOLE_API_URL set but $CLI_PW_PATH not readable"
  elif ! command -v curl > /dev/null 2>&1; then
    api_status="curl not installed; skipping API calls"
  elif ! command -v base64 > /dev/null 2>&1; then
    api_status="base64 not installed; skipping API calls"
  else
    auth_token="$(printf 'cli:%s' "$cli_password" | base64 | tr -d $'\n')"
    api_used_basic_auth="true"
    api_context=1
    call_api_endpoint "stats/summary" api_summary_body api_summary_http api_summary_note
    call_api_endpoint "stats/top_clients" api_top_clients_body api_top_clients_http api_top_clients_note
    if [[ "$api_summary_http" == "200" || "$api_top_clients_http" == "200" ]]; then
      api_status="API queried with Basic Auth"
    else
      api_status="API query attempted with Basic Auth (check endpoint details)"
    fi
  fi
>>>>>>> 6cc1a47 (feat: add Pi-hole v6 healthcheck, update security step, refresh docs for v6 API)
fi

if [[ "$api_summary_http" == "404" ]]; then
  api_summary_note="Endpoint not found (HTTP 404)"
fi
if [[ "$api_top_clients_http" == "404" ]]; then
  api_top_clients_note="Endpoint not found (HTTP 404)"
fi

if [[ "$api_summary_http" == "200" && -n "$api_summary_body" ]]; then
  if command -v python3 > /dev/null 2>&1; then
    api_summary_parsed="$(SUMMARY_INPUT="$api_summary_body" python3 - <<'PY'
import os, json
data = os.environ.get("SUMMARY_INPUT", "")
if not data:
    raise SystemExit(0)
try:
    obj = json.loads(data)
except Exception:
    raise SystemExit(0)

def find_value(node, keys):
    if isinstance(node, dict):
        for key, value in node.items():
            if key in keys:
                return value
        for value in node.values():
            found = find_value(value, keys)
            if found is not None:
                return found
    elif isinstance(node, list):
        for item in node:
            found = find_value(item, keys)
            if found is not None:
                return found
    return None

def coerce_number(value):
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, dict):
        for key in ("value", "total", "count", "24h", "queries"):
            if key in value:
                return coerce_number(value[key])
    if isinstance(value, list) and value:
        return coerce_number(value[0])
    try:
        return float(str(value))
    except Exception:
        return None

total = coerce_number(find_value(obj, {"total_queries_24h", "total_queries", "dns_queries_today", "queries_total_24h"}))
blocked = coerce_number(find_value(obj, {"blocked_queries_24h", "blocked_queries", "ads_blocked_today", "dns_queries_blocked_24h"}))
percent = coerce_number(find_value(obj, {"blocked_percent", "blocked_percent_24h", "ads_percentage_today"}))

parts = []
for value in (total, blocked, percent):
    if value is None:
        parts.append("")
    else:
        parts.append(str(value))
print("|".join(parts))
PY
)"
    if [[ -n "$api_summary_parsed" ]]; then
      IFS='|' read -r api_total_override api_blocked_override api_percent_override <<<"$api_summary_parsed"
    fi
  fi
fi

if [[ "$api_top_clients_http" == "200" && -n "$api_top_clients_body" ]]; then
  if command -v python3 > /dev/null 2>&1; then
    api_top_clients_parsed="$(TOP_CLIENTS_INPUT="$api_top_clients_body" python3 - <<'PY'
import os, json
data = os.environ.get("TOP_CLIENTS_INPUT", "")
if not data:
    raise SystemExit(0)
try:
    obj = json.loads(data)
except Exception:
    raise SystemExit(0)

def find_clients(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key in {"top_clients", "clients"} and isinstance(value, list):
                return value
        for value in node.values():
            found = find_clients(value)
            if found is not None:
                return found
    elif isinstance(node, list):
        for item in node:
            found = find_clients(item)
            if found is not None:
                return found
    return None

clients = find_clients(obj)
if not clients:
    raise SystemExit(0)

lines = []
for item in clients:
    if not isinstance(item, dict):
        continue
    client = item.get("client") or item.get("ip") or item.get("name")
    count = item.get("count") or item.get("total") or item.get("queries")
    if client is None or count is None:
        continue
    try:
        count_value = float(count)
    except Exception:
        continue
    lines.append(f"{client}|{int(count_value)}")
print("\n".join(lines[:5]))
PY
)"
    if [[ -n "$api_top_clients_parsed" ]]; then
      while IFS='|' read -r client count; do
        [[ -z "$client" ]] && continue
        [[ -z "$count" ]] && continue
        TOP_CLIENTS_API+=("$client|$count")
      done <<<"$api_top_clients_parsed"
    fi
  fi
fi

top_clients_source="sqlite"
declare -a TOP_CLIENTS_DISPLAY=()
if ((${#TOP_CLIENTS_API[@]} > 0)); then
  TOP_CLIENTS_DISPLAY=("${TOP_CLIENTS_API[@]}")
  top_clients_source="API"
elif ((${#TOP_CLIENTS_LOCAL[@]} > 0)); then
  TOP_CLIENTS_DISPLAY=("${TOP_CLIENTS_LOCAL[@]}")
  top_clients_source="sqlite"
fi

if [[ -n "$api_total_override" ]]; then
  traffic_total_24h="$(printf "%.0f" "$api_total_override" 2>/dev/null || echo "$api_total_override")"
fi
if [[ -n "$api_blocked_override" ]]; then
  traffic_blocked_24h="$(printf "%.0f" "$api_blocked_override" 2>/dev/null || echo "$api_blocked_override")"
fi
if [[ -n "$api_percent_override" ]]; then
  traffic_blocked_percent="$(awk -v p="$api_percent_override" 'BEGIN { printf "%.1f", p }' 2>/dev/null || echo "$api_percent_override")"
fi

human_bool() {
  case "$1" in
    true) echo "OK";;
    false) echo "NOT LISTENING";;
    *) echo "UNKNOWN";;
  esac
}

print_text() {
  echo "=== Pi-hole API Healthcheck ==="
  echo "Timestamp: $timestamp"
  echo "Host: $hostname_value ($ipv4_address)"
  echo
  echo "[Service]"
  echo "  FTL service state : $ftl_service_state"
  echo "  Blocking          : $blocking_status"
  echo "  DNS UDP/IPv4      : $(human_bool "$dns_udp_v4")"
  echo "  DNS TCP/IPv4      : $(human_bool "$dns_tcp_v4")"
  echo
  echo "[Traffic last 24h]"
  if [[ -n "$traffic_total_24h" ]]; then
    echo "  Total queries     : ${traffic_total_24h}"
  else
    echo "  Total queries     : unavailable"
  fi
  if [[ -n "$traffic_blocked_24h" ]]; then
    echo "  Blocked queries   : ${traffic_blocked_24h}"
  fi
  if [[ -n "$traffic_blocked_percent" ]]; then
    echo "  Blocked percent   : ${traffic_blocked_percent}%"
  fi
  if [[ -n "$traffic_note" ]]; then
    echo "  Note              : $traffic_note"
  fi
  echo
  echo "[Top clients (source: $top_clients_source)]"
  if ((${#TOP_CLIENTS_DISPLAY[@]} > 0)); then
    local idx=1
    for entry in "${TOP_CLIENTS_DISPLAY[@]}"; do
      client="${entry%%|*}"
      count="${entry##*|}"
      printf '  %d. %-20s %s\n' "$idx" "$client" "$count"
      idx=$((idx + 1))
    done
  else
    echo "  No data available"
    if [[ -n "$top_clients_note" ]]; then
      echo "  Note: $top_clients_note"
    fi
  fi
  echo
  echo "[System]"
<<<<<<< HEAD
=======
  [[ -n "$uptime_summary" ]] && echo "  Uptime            : ${uptime_summary}"
>>>>>>> 6cc1a47 (feat: add Pi-hole v6 healthcheck, update security step, refresh docs for v6 API)
  [[ -n "$cpu_temp_c" ]] && echo "  CPU temperature   : ${cpu_temp_c}°C"
  [[ -n "$load_avg" ]] && echo "  Load average      : ${load_avg}"
  [[ -n "$ram_used_pct" ]] && echo "  RAM used          : ${ram_used_pct}%"
  [[ -n "$disk_used_pct" ]] && echo "  Disk used (/)     : ${disk_used_pct}%"
  echo
  echo "[API]"
<<<<<<< HEAD
  echo "  Status            : $api_note"
=======
  echo "  Status            : $api_status"
>>>>>>> 6cc1a47 (feat: add Pi-hole v6 healthcheck, update security step, refresh docs for v6 API)
  if [[ -n "$api_summary_http" ]]; then
    echo "  Summary endpoint  : HTTP ${api_summary_http}${api_summary_note:+ ($api_summary_note)}"
  fi
  if [[ -n "$api_top_clients_http" ]]; then
    echo "  Top clients ep    : HTTP ${api_top_clients_http}${api_top_clients_note:+ ($api_top_clients_note)}"
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  echo -n "$s"
}

json_bool_or_null() {
  case "$1" in
    true) echo -n "true";;
    false) echo -n "false";;
    null|"") echo -n "null";;
    *) echo -n "null";;
  esac
}

is_number() {
  [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

json_number_or_null() {
  local value="$1"
  if [[ -z "$value" ]]; then
    echo -n "null"
  elif is_number "$value"; then
    echo -n "$value"
  else
    echo -n "null"
  fi
}

<<<<<<< HEAD
=======
json_http_code_or_null() {
  local code="$1"
  if [[ "$code" =~ ^[0-9]{3}$ && "$code" != "000" ]]; then
    echo -n "$code"
  else
    echo -n "null"
  fi
}

json_string_or_null() {
  local text="$1"
  if [[ -z "$text" ]]; then
    echo -n "null"
  else
    printf '"%s"' "$(json_escape "$text")"
  fi
}

>>>>>>> 6cc1a47 (feat: add Pi-hole v6 healthcheck, update security step, refresh docs for v6 API)
print_json() {
  printf '{'
  printf '"timestamp":"%s",' "$(json_escape "$timestamp")"
  printf '"host":{"hostname":"%s","ipv4":"%s"},' "$(json_escape "$hostname_value")" "$(json_escape "$ipv4_address")"
  printf '"service":{"ftl_active":%s,"blocking":"%s"},' "$(json_bool_or_null "$ftl_active_state")" "$(json_escape "$blocking_status")"
  printf '"dns":{"udp_v4":%s,"tcp_v4":%s},' "$(json_bool_or_null "$dns_udp_v4")" "$(json_bool_or_null "$dns_tcp_v4")"
  printf '"traffic":{"total_queries_24h":%s,"blocked_queries_24h":%s,"blocked_percent":%s},' \
    "$(json_number_or_null "$traffic_total_24h")" \
    "$(json_number_or_null "$traffic_blocked_24h")" \
    "$(json_number_or_null "$traffic_blocked_percent")"
  printf '"system":{"cpu_temp_c":%s,"load_avg":"%s","ram_used_pct":%s,"disk_used_pct":%s},' \
    "$(json_number_or_null "$cpu_temp_c")" \
    "$(json_escape "$load_avg")" \
    "$(json_number_or_null "$ram_used_pct")" \
    "$(json_number_or_null "$disk_used_pct")"
  printf '"top_clients":['
  local first=1
  if ((${#TOP_CLIENTS_DISPLAY[@]} > 0)); then
    for entry in "${TOP_CLIENTS_DISPLAY[@]}"; do
      client="${entry%%|*}"
      count="${entry##*|}"
      [[ -z "$client" ]] && continue
      if ! is_number "$count"; then
        continue
      fi
      if (( first )); then
        first=0
      else
        printf ','
      fi
      printf '{"client":"%s","count":%s}' "$(json_escape "$client")" "$count"
    done
  fi
  printf '],'
<<<<<<< HEAD
  printf '"notes":{"traffic":"%s","api":"%s"}' "$(json_escape "$traffic_note")" "$(json_escape "$api_note")"
=======
  if (( api_context )); then
    printf '"api":{'
    printf '"url":"%s",' "$(json_escape "$api_url")"
    printf '"status":"%s",' "$(json_escape "$api_status")"
    printf '"used_basic_auth":%s,' "$([[ "$api_used_basic_auth" == "true" ]] && echo "true" || echo "false")"
    printf '"summary_http_code":%s,' "$(json_http_code_or_null "$api_summary_http")"
    printf '"summary_error":%s,' "$(json_string_or_null "$api_summary_note")"
    printf '"top_clients_http_code":%s,' "$(json_http_code_or_null "$api_top_clients_http")"
    printf '"top_clients_error":%s' "$(json_string_or_null "$api_top_clients_note")"
    printf '},'
  else
    printf '"api":null,'
  fi
  printf '"notes":{"traffic":'
  if [[ -n "$traffic_note" ]]; then
    printf '"%s"' "$(json_escape "$traffic_note")"
  else
    printf 'null'
  fi
  printf ',"api":"%s"}' "$(json_escape "$api_status")"
>>>>>>> 6cc1a47 (feat: add Pi-hole v6 healthcheck, update security step, refresh docs for v6 API)
  printf '}\n'
}

if (( JSON_OUTPUT )); then
  print_json
else
  print_text
fi
