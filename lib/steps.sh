#!/usr/bin/env bash
# ============================================================================
# Pi-hole Maintenance PRO - Step Execution Framework Library
# Version: 5.3.2
# ============================================================================

# Execute a maintenance step with progress tracking
run_step() {
  # shellcheck disable=SC2034,SC2154  # STATUS, STEP_LOGFILE, colors from main
  local n="$1" icon="$2" title="$3" cmd="$4" critical="${5:-false}" display_only="${6:-false}"
  local step_log="$TMPDIR/step_${n}.log"
  STEP_LOGFILE["$n"]="$step_log"
  echo -e "\n${BLUE}╔═[Step ${n}]${NC}\n${BLUE}║ ${icon} ${title}${NC}\n${BLUE}╚═>${NC} "

  local out="/dev/null"
  if [[ -t 1 ]]; then
    if [[ -w /dev/tty ]]; then out="/dev/tty"; else out="/dev/stdout"; fi
  fi

  if [[ "$display_only" == "true" ]]; then
    if bash -lc "$cmd" 2>&1 | tee -a "$out" | strip_ansi > "$step_log"; then
      echo -e "${CHECK} Erfolg"
      STATUS["$n"]="${GREEN}✔ OK${NC}"
      [[ -f "$step_log" ]] && extract_step_data "$n" "$(cat "$step_log")"
    else
      echo -e "${WARN} Warnung"
      STATUS["$n"]="${YELLOW}⚠ WARN${NC}"
      [[ -s "$step_log" ]] && tail -n 20 "$step_log"
      [[ "$critical" == "true" ]] && echo -e "${RED}[ERROR] Kritischer Fehler – Abbruch${NC}" && exit 1
    fi
    return 0
  fi

  bash -lc "$cmd" 2>&1 | strip_ansi > "$step_log" &
  local pid=$!
  (
    local spin=('⠋' '⠙' '⠸' '⠴' '⠦' '⠇')
    local i=0
    while kill -0 "$pid" 2> /dev/null; do
      local last=""
      [[ -f "$step_log" ]] && last="$(tail -n1 "$step_log" | cut -c1-80)"
      printf '\r%s%s%s %s[PID:%s]%s %s' "$CYAN" "$last" "$NC" "$BLUE" "$pid" "$NC" "${spin[$((i % ${#spin[@]}))]}" > "$out" 2> /dev/null || true
      i=$((i + 1))
      sleep 0.25
    done
    printf '\r' > "$out" 2> /dev/null || true
  ) &
  if wait "$pid"; then
    echo -e "\n${CHECK} Erfolg"
    STATUS["$n"]="${GREEN}✔ OK${NC}"
    [[ -f "$step_log" ]] && extract_step_data "$n" "$(cat "$step_log")"
  else
    local ec=$?
    echo -e "\n${FAIL} Fehler (Code: $ec)"
    STATUS["$n"]="${RED}✖ FAIL${NC}"
    [[ -f "$step_log" ]] && tail -n 50 "$step_log"
    [[ "$critical" == "true" ]] && echo -e "${RED}[ERROR] Kritischer Fehler in Step ${n}${NC}" && exit $ec
  fi
}
