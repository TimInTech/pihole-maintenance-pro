#!/usr/bin/env bash
# ============================================================================
# Shared Test Helper Functions
# ============================================================================

# Test counters (global across all tests)
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output for test results
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Print test summary
print_test_summary() {
  echo ""
  echo "================================"
  echo "Test Summary"
  echo "================================"
  echo "Total:  $TESTS_RUN"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    return 1
  else
    echo "Failed: 0"
    return 0
  fi
}
