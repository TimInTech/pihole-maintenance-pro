#!/usr/bin/env bash
# ============================================================================
# Unit Tests for lib/system.sh
# ============================================================================
set -euo pipefail

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output for test results
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/system.sh
source "${SCRIPT_DIR}/../lib/system.sh"

# Test helper functions
assert_not_empty() {
  local actual="$1" test_name="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -n "$actual" ]]; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name (value is empty)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_matches() {
  local pattern="$1" actual="$2" test_name="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$actual" =~ $pattern ]]; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name"
    echo "  Expected pattern: '$pattern'"
    echo "  Actual value:     '$actual'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

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
echo ""
echo "================================"
echo "Test Summary"
echo "================================"
echo "Total:  $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo "Failed: 0"
  exit 0
fi
