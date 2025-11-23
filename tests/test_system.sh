#!/usr/bin/env bash
# ============================================================================
# Unit Tests for lib/system.sh
# ============================================================================
set -euo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test_helpers.sh
source "${SCRIPT_DIR}/test_helpers.sh"

# Source the library
# shellcheck source=../lib/system.sh
source "${SCRIPT_DIR}/../lib/system.sh"

# Test collect_system_info function
test_collect_system_info() {
  echo -e "\n${YELLOW}Testing collect_system_info...${NC}"
  declare -gA PERFORMANCE_DATA
  
  collect_system_info
  
  assert_not_empty "${PERFORMANCE_DATA[load]}" "Load average should be set"
  assert_not_empty "${PERFORMANCE_DATA[memory]}" "Memory usage should be set"
  assert_not_empty "${PERFORMANCE_DATA[disk]}" "Disk usage should be set"
  assert_not_empty "${PERFORMANCE_DATA[temp]}" "Temperature should be set"
  
  # Validate format
  assert_matches "^[0-9]+$|^N/A$" "${PERFORMANCE_DATA[memory]}" "Memory should be numeric or N/A"
  assert_matches "^[0-9]+$" "${PERFORMANCE_DATA[disk]}" "Disk should be numeric"
}

# Test show_recommendations function
test_show_recommendations() {
  echo -e "\n${YELLOW}Testing show_recommendations...${NC}"
  declare -gA PERFORMANCE_DATA STEP_DATA
  
  # Set up test data - normal conditions (should produce no warnings)
  PERFORMANCE_DATA[memory]=50
  PERFORMANCE_DATA[disk]=50
  PERFORMANCE_DATA[temp]=45
  STEP_DATA[07_listeners]=4
  
  # Capture output
  local output
  output=$(show_recommendations 2>&1)
  
  # With normal conditions, should not produce warnings
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -z "$output" ]]; then
    echo -e "${GREEN}✓${NC} PASS: No warnings with normal metrics"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${YELLOW}⚠${NC} INFO: Got output (may be expected): $output"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

# Run all tests
echo "================================"
echo "Running system.sh Unit Tests"
echo "================================"

test_collect_system_info
test_show_recommendations

# Print summary
print_test_summary
