#!/usr/bin/env bash
# ============================================================================
# Pi-hole Maintenance PRO - System Monitoring Library
# Version: 5.3.2
# ============================================================================

# Collect system performance metrics
collect_system_info() {
  # shellcheck disable=SC2034,SC2154  # PERFORMANCE_DATA used/assigned in main script
  PERFORMANCE_DATA[load]=$(uptime | awk -F'load average: ' '{print $2}' | cut -d',' -f1 | xargs)
  PERFORMANCE_DATA[memory]=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}' 2> /dev/null || echo "N/A")
  PERFORMANCE_DATA[disk]=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
  [[ -f /sys/class/thermal/thermal_zone0/temp ]] && PERFORMANCE_DATA[temp]=$(($(cat /sys/class/thermal/thermal_zone0/temp 2> /dev/null || echo 0) / 1000)) || PERFORMANCE_DATA[temp]="N/A"
}

# Show system health recommendations
show_recommendations() {
  # shellcheck disable=SC2154  # PERFORMANCE_DATA and STEP_DATA from main script
  local warnings=() recommendations=()
  [[ "${PERFORMANCE_DATA[memory]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[memory] > 85)) && {
    warnings+=("⚠️  High memory usage: ${PERFORMANCE_DATA[memory]}%")
    recommendations+=("💡 Consider restarting FTL or increasing RAM")
  }
  [[ "${PERFORMANCE_DATA[disk]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[disk] > 85)) && {
    warnings+=("⚠️  Low disk space: ${PERFORMANCE_DATA[disk]}% used")
    recommendations+=("💡 Consider log rotation or cleanup: pihole -f")
  }
  [[ "${PERFORMANCE_DATA[temp]}" =~ ^[0-9]+$ ]] && ((PERFORMANCE_DATA[temp] > 70)) && {
    warnings+=("🌡️  High temperature: ${PERFORMANCE_DATA[temp]}°C")
    recommendations+=("💡 Check cooling/ventilation")
  }
  [[ "${STEP_DATA[07_listeners]}" =~ ^[0-9]+$ ]] && ((STEP_DATA[07_listeners] < 1)) && {
    warnings+=("🔥 CRITICAL: No DNS listeners on port 53")
    recommendations+=("🚨 Restart Pi-hole FTL: sudo systemctl restart pihole-FTL")
  }
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}════════ WARNINGS ════════${NC}"
    printf '%s\n' "${warnings[@]}"
  fi
  if [[ ${#recommendations[@]} -gt 0 ]]; then
    echo -e "\n${BLUE}════════ RECOMMENDATIONS ════════${NC}"
    printf '%s\n' "${recommendations[@]}"
  fi
}
