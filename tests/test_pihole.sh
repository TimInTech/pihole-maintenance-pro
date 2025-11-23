#!/usr/bin/env bash
# ============================================================================
# Unit Tests for lib/pihole.sh
# ============================================================================
set -euo pipefail

# Source shared test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test_helpers.sh
source "${SCRIPT_DIR}/test_helpers.sh"

# Source the library
# shellcheck source=../lib/pihole.sh
source "${SCRIPT_DIR}/../lib/pihole.sh"

# Test detect_ftl_db function
test_detect_ftl_db() {
  echo -e "\n${YELLOW}Testing detect_ftl_db...${NC}"
  
  # This function searches for actual database files
  # In a test environment, they likely won't exist
  set +e
  local result
  result=$(detect_ftl_db 2>/dev/null)
  set -e
  
  TESTS_RUN=$((TESTS_RUN + 1))
  # Accept empty result as valid (no DB in test environment)
  if [[ -z "$result" ]] || [[ -f "$result" ]]; then
    if [[ -z "$result" ]]; then
      echo -e "${GREEN}✓${NC} PASS: detect_ftl_db returns empty when no DB found (expected in test env)"
    else
      echo -e "${GREEN}✓${NC} PASS: detect_ftl_db found DB at: $result"
    fi
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: detect_ftl_db returned non-empty but file doesn't exist: $result"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test get_query_summary function
test_get_query_summary() {
  echo -e "\n${YELLOW}Testing get_query_summary...${NC}"
  
  # Mock FTL_DB as empty (no database available)
  FTL_DB=""
  local result
  result=$(get_query_summary)
  assert_equals "DB not available" "$result" "get_query_summary with no DB"
}

# Test get_client_summary function
test_get_client_summary() {
  echo -e "\n${YELLOW}Testing get_client_summary...${NC}"
  
  # Mock FTL_DB as empty (no database available)
  FTL_DB=""
  local result
  result=$(get_client_summary)
  assert_equals "DB not available" "$result" "get_client_summary with no DB"
}

# Run all tests
echo "================================"
echo "Running pihole.sh Unit Tests"
echo "================================"

test_detect_ftl_db
test_get_query_summary
test_get_client_summary

# Print summary
print_test_summary
