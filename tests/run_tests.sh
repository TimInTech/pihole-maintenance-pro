#!/usr/bin/env bash
# ============================================================================
# Test Runner - Run all unit tests
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                       Pi-hole Maintenance PRO                          ║"
echo "║                          Unit Test Runner                              ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

total_tests=0
passed_tests=0
failed_tests=0

# Run each test file
for test_file in "$SCRIPT_DIR"/test_*.sh; do
  if [[ -f "$test_file" ]]; then
    test_name=$(basename "$test_file")
    echo -e "\n${YELLOW}Running $test_name...${NC}"
    
    if bash "$test_file"; then
      echo -e "${GREEN}✓ $test_name completed successfully${NC}"
      passed_tests=$((passed_tests + 1))
    else
      echo -e "${RED}✗ $test_name failed${NC}"
      failed_tests=$((failed_tests + 1))
    fi
    total_tests=$((total_tests + 1))
  fi
done

# Overall summary
echo ""
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                         Overall Test Summary                           ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Total test suites:  $total_tests"
echo -e "${GREEN}Passed: $passed_tests${NC}"

if [[ $failed_tests -gt 0 ]]; then
  echo -e "${RED}Failed: $failed_tests${NC}"
  exit 1
else
  echo "Failed: 0"
  echo -e "\n${GREEN}${BOLD}All tests passed!${NC}"
  exit 0
fi
