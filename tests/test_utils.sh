#!/usr/bin/env bash
# ============================================================================
# Unit Tests for lib/utils.sh
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
# shellcheck source=../lib/utils.sh
source "${SCRIPT_DIR}/../lib/utils.sh"

# Test helper functions
assert_equals() {
  local expected="$1" actual="$2" test_name="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

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

# Test init_colors function
test_init_colors() {
  echo -e "\n${YELLOW}Testing init_colors...${NC}"
  init_colors
  assert_not_empty "$RED" "RED color should be set"
  assert_not_empty "$GREEN" "GREEN color should be set"
  assert_not_empty "$CHECK" "CHECK symbol should be set"
}

# Test strip_ansi function
test_strip_ansi() {
  echo -e "\n${YELLOW}Testing strip_ansi...${NC}"
  local input=$'\033[0;31mRED TEXT\033[0m'
  local expected="RED TEXT"
  local actual
  actual=$(echo "$input" | strip_ansi)
  assert_equals "$expected" "$actual" "strip_ansi should remove ANSI codes"
}

# Test get_step_description function
test_get_step_description() {
  echo -e "\n${YELLOW}Testing get_step_description...${NC}"
  local desc
  desc=$(get_step_description "01")
  assert_equals "📦 APT Updates" "$desc" "Step 01 description"
  
  desc=$(get_step_description "04")
  assert_equals "🆙 Pi-hole Update" "$desc" "Step 04 description"
  
  desc=$(get_step_description "99")
  assert_equals "Step 99" "$desc" "Unknown step description"
}

# Test extract_step_data function
test_extract_step_data() {
  echo -e "\n${YELLOW}Testing extract_step_data...${NC}"
  declare -gA STEP_DATA
  
  # Test IP extraction
  local output="inet 192.168.1.100/24"
  extract_step_data "00" "$output"
  assert_equals "192.168.1.100" "${STEP_DATA[00_ip]}" "IP address extraction"
  
  # Test version extraction
  output="Core version is v6.1.4"
  extract_step_data "03" "$output"
  assert_equals "v6.1.4" "${STEP_DATA[03_version]}" "Version extraction"
  
  # Test listeners count
  output=$'line1\nline2\nline3'
  extract_step_data "07" "$output"
  assert_equals "3" "${STEP_DATA[07_listeners]}" "Listeners count"
}

# Run all tests
echo "================================"
echo "Running utils.sh Unit Tests"
echo "================================"

test_init_colors
test_strip_ansi
test_get_step_description
test_extract_step_data

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
