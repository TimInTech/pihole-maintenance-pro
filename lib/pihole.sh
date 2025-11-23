#!/usr/bin/env bash
# ============================================================================
# Pi-hole Maintenance PRO - Pi-hole Specific Functions Library
# Version: 5.3.2
# ============================================================================

# Backup Pi-hole configuration and databases
backup_pihole() {
  local backup_dir
  backup_dir="/etc/pihole/backup_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_dir"
  cp -a /etc/pihole/*.db "$backup_dir" 2> /dev/null || true
  cp -a /etc/pihole/pihole.toml "$backup_dir" 2> /dev/null || true
  cp -a /etc/pihole/hosts/*.list "$backup_dir" 2> /dev/null || true
  echo "Backup erstellt: $backup_dir"
}

# Get FTL query statistics summary
get_query_summary() {
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 > /dev/null 2>&1; then
    local total_queries blocked_queries blocked_percent
    total_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s','now','-24 hours');" 2> /dev/null || echo 0)
    blocked_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s','now','-24 hours') AND status IN (1,4,5,6,7,8,9,10,11);" 2> /dev/null || echo 0)
    if [[ "$total_queries" -gt 0 ]]; then
      blocked_percent=$((blocked_queries * 100 / total_queries))
      echo "24h: ${total_queries} queries, ${blocked_percent}% blocked"
    else
      echo "No recent data"
    fi
  else
    echo "DB not available"
  fi
}

# Get FTL client statistics summary
get_client_summary() {
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 > /dev/null 2>&1; then
    local unique_clients
    unique_clients=$(sqlite3 "$FTL_DB" "SELECT COUNT(DISTINCT client) FROM queries WHERE timestamp > strftime('%s','now','-24 hours');" 2> /dev/null || echo 0)
    echo "${unique_clients} active clients"
  else
    echo "DB not available"
  fi
}

# Detect Pi-hole FTL database location
detect_ftl_db() {
  local ftl_db=""
  for c in /etc/pihole/pihole-FTL.db /run/pihole-FTL.db /var/lib/pihole/pihole-FTL.db; do
    [[ -f "$c" ]] && ftl_db="$c" && break
  done
  echo "$ftl_db"
}
