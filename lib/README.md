# Library Modules

This directory contains modular, reusable library functions extracted from the main script to improve testability, maintainability, and code organization.

## Structure

### `utils.sh`
Utility functions for general-purpose operations:
- `init_colors()` - Initialize color codes and symbols for terminal output
- `strip_ansi()` - Remove ANSI escape sequences from text
- `echo_hdr()` - Display the script header banner
- `extract_step_data()` - Extract relevant data from step execution output
- `get_step_description()` - Get human-readable description for a step number

### `system.sh`
System monitoring and health check functions:
- `collect_system_info()` - Collect system performance metrics (load, memory, disk, temperature)
- `show_recommendations()` - Analyze metrics and display health warnings/recommendations

### `pihole.sh`
Pi-hole specific functions:
- `backup_pihole()` - Create backup of Pi-hole configuration and databases
- `get_query_summary()` - Get FTL query statistics summary (24h)
- `get_client_summary()` - Get FTL client statistics summary (24h)
- `detect_ftl_db()` - Auto-detect Pi-hole FTL database location

### `output.sh`
Output formatting functions:
- `summary()` - Display intelligent summary with performance dashboard
- `output_json()` - Output maintenance results in machine-readable JSON format

### `steps.sh`
Step execution framework:
- `run_step()` - Execute a maintenance step with progress tracking, logging, and status reporting

## Usage

These libraries are automatically sourced by the main script (`pihole_maintenance_pro.sh`) when present. The main script includes fallback inline definitions for backward compatibility if the library directory is not available.

## Testing

Each library module has corresponding unit tests in the `tests/` directory:
- `tests/test_utils.sh` - Tests for utils.sh
- `tests/test_system.sh` - Tests for system.sh  
- `tests/test_pihole.sh` - Tests for pihole.sh

Run all tests with:
```bash
make test
# or directly:
bash tests/run_tests.sh
```

## Design Principles

1. **Isolation** - Each library focuses on a specific domain (utilities, system, pihole, output, steps)
2. **Testability** - Functions are designed to be unit-testable in isolation
3. **Minimal coupling** - Libraries minimize dependencies on global state
4. **Backward compatibility** - Main script works with or without library files
5. **Shellcheck clean** - All code passes shellcheck with appropriate suppressions documented
