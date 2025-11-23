# Unit Tests

This directory contains unit tests for the modular library functions in `lib/`.

## Test Files

### `test_utils.sh`
Tests for `lib/utils.sh`:
- Color initialization
- ANSI stripping
- Step descriptions
- Data extraction from step output

### `test_system.sh`
Tests for `lib/system.sh`:
- System information collection (load, memory, disk, temperature)
- Health recommendations based on metrics

### `test_pihole.sh`
Tests for `lib/pihole.sh`:
- FTL database detection
- Query summary formatting
- Client summary formatting

## Running Tests

### Run all tests
```bash
make test
# or directly:
bash tests/run_tests.sh
```

### Run individual test suite
```bash
bash tests/test_utils.sh
bash tests/test_system.sh
bash tests/test_pihole.sh
```

## Test Framework

The tests use a simple custom testing framework with these assertion helpers:

- `assert_equals <expected> <actual> <test_name>` - Assert two values are equal
- `assert_not_empty <value> <test_name>` - Assert value is not empty
- `assert_matches <pattern> <value> <test_name>` - Assert value matches regex pattern

## Test Environment

Tests are designed to run in environments without Pi-hole installed:
- Database-dependent functions gracefully handle missing databases
- Network-dependent tests use mocked data where appropriate
- Tests use `set -euo pipefail` for strict error handling

## Adding New Tests

When adding new library functions, follow these steps:

1. Create tests in the appropriate test file (or create a new `test_*.sh` file)
2. Use the assertion helpers for consistency
3. Ensure tests pass in CI environment (no Pi-hole, no root)
4. Update test summary counters appropriately
5. Run `make test` to verify all tests pass

## CI Integration

Unit tests are automatically run in CI (see `.github/workflows/ci-sanity.yml`):
```yaml
- name: Run unit tests
  run: make test
```

All tests must pass before changes can be merged.
