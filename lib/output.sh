#!/usr/bin/env bash
# ============================================================================
# Pi-hole Maintenance PRO - Output Formatting Library
# Version: 5.3.2
# ============================================================================

# Display intelligent summary of maintenance run
summary() {
  # shellcheck disable=SC2154  # Variables from main script
  collect_system_info
  echo
  echo -e "${CYAN}╔═══════════════ PERFORMANCE DASHBOARD ═══════════════╗${NC}"
  printf "${CYAN}║${NC} 🚀 Load: %-8s 💾 RAM: %s%%    🌡️  Temp: %s°C    🗄️  Disk: %s%% ${CYAN}║${NC}\n" \
    "${PERFORMANCE_DATA[load]:-N/A}" "${PERFORMANCE_DATA[memory]:-N/A}" "${PERFORMANCE_DATA[temp]:-N/A}" "${PERFORMANCE_DATA[disk]:-N/A}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
  echo
  echo -e "${MAGENTA}════════ INTELLIGENTE ZUSAMMENFASSUNG ════════${NC}"
  for k in $(printf '%s\n' "${!STATUS[@]}" | sort -n); do
    local step_info=""
    case "$k" in
      00) step_info="🌍 Network    ${STEP_DATA[00_ip]:+IP: ${STEP_DATA[00_ip]}}" ;;
      03)
        ver="${STEP_DATA[03_version]}"
        ver="${ver#v}"
        step_info="🛡️  Pi-hole    ${ver:+v$ver}"
        ;;
      07) step_info="🔍 Health     ${STEP_DATA[07_listeners]:+${STEP_DATA[07_listeners]} listeners}" ;;
      08) step_info="🌐 DNS Ext    ${STEP_DATA[08_response]:-${NC}}" ;;
      09) step_info="🏠 DNS Local  ${STEP_DATA[09_response]:-${NC}}" ;;
      10) step_info="📡 GitHub     ${STEP_DATA[10_github]:-${NC}}" ;;
      12) step_info="📊 FTL Query  $(get_query_summary)" ;;
      13) step_info="👥 FTL Client $(get_client_summary)" ;;
      *) step_info="$(get_step_description "$k")" ;;
    esac
    # %b nötig, damit ANSI-Sequenzen in STATUS farbig ausgegeben werden (nicht als \033…)
    printf '  %-4s %-50s %b\n' "#${k}" "$step_info" "${STATUS[$k]}"
    : "${STEP_LOGFILE[$k]+x}" > /dev/null
  done
  echo
  show_recommendations
  echo -e "Log: ${CYAN}$LOGFILE${NC}"
  echo -e "Step logs: ${CYAN}$TMPDIR${NC} (werden beim Exit gelöscht)"
}

# Output maintenance results as JSON
output_json() {
  # shellcheck disable=SC2154  # Variables from main script
  collect_system_info
  local timestamp total_steps successful_steps failed_steps warned_steps overall_status total_queries blocked_queries blocked_percentage
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  total_steps=${#STATUS[@]}
  successful_steps=0
  failed_steps=0
  warned_steps=0
  for s in "${STATUS[@]}"; do
    if [[ "$s" == *OK* ]]; then ((successful_steps++)); fi
    if [[ "$s" == *FAIL* ]]; then ((failed_steps++)); fi
    if [[ "$s" == *WARN* ]]; then ((warned_steps++)); fi
  done
  overall_status="healthy"
  ((failed_steps > 0)) && overall_status="critical"
  ((warned_steps > 0 && failed_steps == 0)) && overall_status="warning"

  total_queries=0
  blocked_queries=0
  blocked_percentage=0
  if [[ -n "$FTL_DB" ]] && command -v sqlite3 > /dev/null 2>&1; then
    total_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s','now','-24 hours');" 2> /dev/null || echo 0)
    blocked_queries=$(sqlite3 "$FTL_DB" "SELECT COUNT(*) FROM queries WHERE timestamp > strftime('%s','now','-24 hours') AND status IN (1,4,5,6,7,8,9,10,11);" 2> /dev/null || echo 0)
    if [[ "$total_queries" -gt 0 ]]; then blocked_percentage=$(awk "BEGIN {printf \"%.1f\", $blocked_queries/$total_queries*100}"); fi
  fi

  local issues=() recommendations=()
  [[ "${PERFORMANCE_DATA[memory]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[memory] > 85)) && {
    issues+=("high_memory")
    recommendations+=("restart_ftl")
  }
  [[ "${PERFORMANCE_DATA[disk]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[disk] > 85)) && {
    issues+=("low_disk_space")
    recommendations+=("log_rotation")
  }
  [[ "${STEP_DATA[07_listeners]}" =~ ^[0-9]+$ ]] && ((STEP_DATA[07_listeners] < 1)) && {
    issues+=("no_dns_listeners")
    recommendations+=("restart_pihole_ftl")
  }

  cat << EOF
{
  "timestamp": "$timestamp",
  "status": "$overall_status",
  "version": "5.3.2",
  "summary": {
    "total_steps": $total_steps,
    "successful_steps": $successful_steps,
    "failed_steps": $failed_steps,
    "warned_steps": $warned_steps,
    "total_queries_24h": $total_queries,
    "blocked_queries_24h": $blocked_queries,
    "blocked_percentage": $blocked_percentage,
    "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')],
    "recommendations": [$(printf '"%s",' "${recommendations[@]}" | sed 's/,$//')]
  },
  "performance": {
    "load_average": "${PERFORMANCE_DATA[load]:-N/A}",
    "memory_usage_percent": ${PERFORMANCE_DATA[memory]:-0},
    "disk_usage_percent": ${PERFORMANCE_DATA[disk]:-0},
    "temperature_celsius": "${PERFORMANCE_DATA[temp]:-N/A}"
  },
  "network": {
    "local_ip": "${STEP_DATA[00_ip]:-N/A}",
    "dns_listeners": ${STEP_DATA[07_listeners]:-0},
    "external_dns_response": "${STEP_DATA[08_response]:-N/A}",
    "local_dns_response": "${STEP_DATA[09_response]:-N/A}",
    "github_connectivity": "${STEP_DATA[10_github]:-N/A}"
  },
  "pihole": {
    "version": "${STEP_DATA[03_version]:-N/A}",
    "gravity_last_update": "$(stat -c %Y /etc/pihole/gravity.db 2> /dev/null || echo 0)"
  },
  "logs": { "main_log": "$LOGFILE", "step_logs": "$TMPDIR" }
}
EOF
}
