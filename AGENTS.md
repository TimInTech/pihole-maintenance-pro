# Repository Guidelines

## Project Structure & Module Organization
- `pihole_maintenance_pro.sh` — main Bash script (step framework, JSON output, logging).
- `scripts/` — installer, utilities, and optional tests (e.g., `install.sh`, `uninstall.sh`).
- `tools/` — helper scripts (e.g., `repair_pihole_ftl_db.sh`).
- `docs/`, `README*.md` — documentation; `assets/` — static icons.

## Build, Test, and Development Commands
- Syntax check: `bash -n pihole_maintenance_pro.sh`
- Lint: `shellcheck -x pihole_maintenance_pro.sh scripts/*.sh tools/*.sh`
- Format: `shfmt -w -i 2 -ci .`
- Safe local self-test (no system changes):
  `RUN_SELFTEST=1 bash pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload`
- Normal run on a Pi-hole host:
  `sudo /usr/local/bin/pihole_maintenance_pro.sh --json`

## Coding Style & Naming Conventions
- Bash 5+, `set -euo pipefail`; keep strict `IFS`.
- Indent 2 spaces; wrap ~100 chars; quote variables; use `local` in functions.
- Functions: `snake_case` (e.g., `run_step`); constants: `UPPER_SNAKE` (e.g., `LOGFILE`).
- No interactive prompts; expose behavior via flags.
- Preserve cron PATH handling (`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`).

## Testing Guidelines
- CI/dev machines may not have Pi-hole. Rely on syntax/lint/format and the self-test command.
- Optional tests live in `scripts/` (e.g., `test-repo.sh`). Keep them idempotent and side-effect-free.

## Commit & Pull Request Guidelines
- Conventional Commits: `feat:`, `fix(scope):`, `docs:`, `ci:`, `chore:`; reference issues (e.g., `closes #29`).
- PRs: short what/why, affected flags/steps, and proof (log snippet or `--json` sample).
- Run before PR: `bash -n`, `shellcheck`, `shfmt -d .`, and the self-test run.

## Security & Configuration Tips
- Script auto-detects `pihole`; cron often uses a reduced PATH—set a full PATH in cron to avoid surprises.
- Logs default to `/var/log` with a safe temporary fallback.
- On non-Pi-hole systems, test only with `--no-*` flags.

