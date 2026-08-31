# 🛰️ Pi-hole Maintenance PRO MAX

**One idempotent, logged, cron-friendly maintenance run for Pi-hole v6 — safe to test before you trust it.**

[![Build](https://img.shields.io/github/actions/workflow/status/TimInTech/pihole-maintenance-pro/ci-sanity.yml?branch=main)](https://github.com/TimInTech/pihole-maintenance-pro/actions)
[![License](https://img.shields.io/github/license/TimInTech/pihole-maintenance-pro)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-Donate-ffdd00?logo=buymeacoffee&logoColor=000&labelColor=fff)](https://buymeacoffee.com/timintech)

**Languages:** 🇬🇧 English (this file) • [🇩🇪 Deutsch](README.de.md)

---

## What & why

`pihole-maintenance-pro` is a single Bash script that runs the recurring maintenance a Pi-hole v6
host needs — OS package updates, `pihole -up`, gravity/blocklist refresh, plus DNS and system
health checks — as **one repeatable, timestamped, log-producing run** instead of a pile of
hand-typed commands and half-remembered cron lines.

The problem it solves: manual Pi-hole upkeep is easy to forget, easy to get wrong under cron's
reduced `PATH`, and hard to audit after the fact. This script makes the run **idempotent**, logs
everything to `/var/log`, takes a backup **before** it touches Pi-hole, and lets you **dry-test it
without root and without changing anything** first.

### Who it's for

- Pi-hole **v6** users on **Raspberry Pi OS (Bookworm / Trixie)** (also works on comparable
  Debian-based hosts).
- Anyone running Pi-hole maintenance **unattended via cron** who wants logs, health checks, and a
  safe way to verify the run before scheduling it.

## Why this over a plain maintenance one-liner

| Concern | A plain `apt update && pihole -up && pihole -g` | This project |
| --- | --- | --- |
| Test before trusting | none | non-destructive selftest, no root, no changes |
| Backups | none | auto backup **before** update/gravity |
| Health checks | none | port 53, `dig`, DNS local/external, FTL analytics |
| Skip specific steps | edit the command | granular `--no-*` flags |
| Output | raw stdout | timestamped log + summary + optional JSON |
| Cron reliability | breaks on reduced `PATH` | sets a full `PATH` early |
| Interrupt handling | partial state | clean, once-only cleanup on Ctrl-C |

## Quick Start

**1. Try it safely first — no root, no system changes:**

```bash
git clone https://github.com/TimInTech/pihole-maintenance-pro.git
cd pihole-maintenance-pro
RUN_SELFTEST=1 bash pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

**2. Install (script + healthcheck + weekly cron):**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

**3. Run a real maintenance pass on your Pi-hole host:**

```bash
sudo /usr/local/bin/pihole_maintenance_pro.sh
```

## Safety principles

- **Non-destructive selftest.** `RUN_SELFTEST=1` skips the root check and, combined with the
  `--no-*` flags, performs no APT, upgrade, or gravity changes — ideal for CI and a first look.
- **Backup before change.** A snapshot of `/etc/pihole` (`*.db`, `pihole.toml`, host lists) is
  written to `/etc/pihole/backup_<timestamp>` **before** `pihole -up` and before `pihole -g`.
  Add `--backup` for an extra rotated snapshot under `/var/backups/pihole/<timestamp>` (keeps the
  last 5).
- **Opt out per step.** `--no-apt`, `--no-upgrade`, `--no-gravity` let you scope exactly what runs.
- **Predictable exit codes** (see table below) make it safe to gate in scripts and cron.
- **Clean interrupts.** `SIGINT`/`SIGTERM` (Ctrl-C) render the summary and clean up the temp
  directory exactly once.
- **Reversible install.** A one-command [uninstall](#update--uninstall) removes the script, logs,
  temp data, and cron entry.

## Features

- APT `update` / `upgrade` / `autoremove` / `autoclean`
- Pi-hole update (`pihole -up`), gravity refresh (`pihole -g`), optional FTL restart
  (`--restart-ftl`, only when needed on v6)
- Health checks: port 53 listeners, `dig`, local & external DNS resolution, GitHub reachability
- Optional Tailscale info and FTL toplists via `sqlite3`
- Performance dashboard and an end-of-run summary
- Automatic pre-change Pi-hole backup; optional rotated backup via `--backup`
- Machine-readable output via `--json`
- Installer provisions a weekly cron (`0 4 * * 0`) idempotently
- Timestamped logs in `/var/log/pihole_maintenance_pro_<timestamp>.log`

## Requirements

- Pi-hole **v6** with the `pihole` CLI on `PATH`
- Raspberry Pi OS (Bookworm / Trixie) or a comparable Debian-based system
- Bash 5+, `sudo`/root for real runs
- Optional: `sqlite3` (FTL toplists), a configured `PIHOLE_API_URL` for the healthcheck tool

> Compatibility note: this is designed for current Pi-hole v6 maintenance workflows. Verify on your
> own host with the non-destructive selftest before scheduling it in cron.

## Installation

**Installer (recommended)** — installs the maintenance script and
`tools/pihole_api_healthcheck.sh` to `/usr/local/bin` and adds a weekly cron:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

**Manual installation:**

```bash
cd ~
wget -O pihole_maintenance_pro.sh https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/pihole_maintenance_pro.sh
chmod +x pihole_maintenance_pro.sh
sudo install -m 0755 pihole_maintenance_pro.sh /usr/local/bin/pihole_maintenance_pro.sh
```

<!-- UNINSTALL:BEGIN -->
### Update / Uninstall

Re-run the installer to pull and overwrite with the latest version (idempotent):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/install.sh)"
```

Clean removal of the script, logs, temp data, and the cron entry:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TimInTech/pihole-maintenance-pro/main/scripts/uninstall.sh)"
```
<!-- UNINSTALL:END -->

## Non-destructive test / selftest

Run this from a clone to validate behavior without root and without changing your system. It skips
the root check (`RUN_SELFTEST=1`) and disables every mutating step (`--no-*`):

```bash
RUN_SELFTEST=1 bash pihole_maintenance_pro.sh --no-apt --no-upgrade --no-gravity --no-dnsreload
```

This is the same self-test CI runs. It still requires the `pihole` CLI to get past the environment
check: on a host **without** Pi-hole the script stops early with exit code `127` and makes no
changes (CI sets `CI=1`, which turns that case into a clean exit `0`). For a pure syntax check on
any machine, use `bash -n pihole_maintenance_pro.sh`.

## Typical usage

```bash
# Full interactive run
sudo /usr/local/bin/pihole_maintenance_pro.sh

# OS-only maintenance, leave Pi-hole untouched
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-upgrade --no-gravity

# Pi-hole-only maintenance, skip APT
sudo /usr/local/bin/pihole_maintenance_pro.sh --no-apt

# Machine-readable output
sudo /usr/local/bin/pihole_maintenance_pro.sh --json
```

### Flags

| Flag | Effect |
| --- | --- |
| `--no-apt` | Skip APT `update`/`upgrade`/`autoremove`/`autoclean` |
| `--no-upgrade` | Skip `pihole -up` |
| `--no-gravity` | Skip `pihole -g` (blocklists / gravity) |
| `--no-dnsreload` | Deprecated on v6 (no-op; kept for compatibility) |
| `--restart-ftl` | Restart `pihole-FTL` at the end (v6: only if needed) |
| `--backup` | Extra rotated backup under `/var/backups/pihole/` before Pi-hole ops |
| `--json` | Emit a machine-readable JSON block in place of the human-readable end-of-run summary |
| `-h`, `--help` | Show usage |

## Output, logs & JSON

Every run writes a timestamped log to `/var/log/pihole_maintenance_pro_<timestamp>.log`.
Per-step live lines use a unified, timestamped format (`[HH:MM:SS] OK|WARN|ERR …`). `--json`
replaces the end-of-run summary with a machine-readable JSON block. Note that the progress/step
lines are still printed to stdout **before** it, so capture or extract the trailing JSON rather
than piping the whole run straight into `jq`.

### Sample run (real Pi-hole v6)

Captured on a Raspberry Pi with Pi-hole Core 6.1.4, Web 6.2.1, FTL 6.2.3 — the live dashboard and
summary rendered by the current release:

```text
╔═══════════════ PERFORMANCE DASHBOARD ═══════════════╗
║ 🚀 Load: 1.81     💾 RAM: 23%    🌡  Temp: 50°C    🗄  Disk: 9% ║
╚═══════════════════════════════════════════════════════╝

════════ INTELLIGENTE ZUSAMMENFASSUNG ════════
  #00  🌍 Network    IP: 192.168.178.21                 ✔ OK
  #03  🛡  Pi-hole    v6.1.4                         ✔ OK
  #07  🔍 Health     4 listeners                        ✔ OK
  #08  🌐 DNS Ext    172.217.16.78                      ✔ OK
  #09  🏠 DNS Local  127.0.0.1                          ✔ OK
  #12  📊 FTL Query  24h: 141222 queries, 1% blocked    ✔ OK
  #13  👥 FTL Client 25 active clients                  ✔ OK
```

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success (also `--help`, and CI without the `pihole` CLI) |
| `1` | Not run as root without `RUN_SELFTEST`, or a critical step failed |
| `2` | Unknown option |
| `127` | `pihole` CLI not found (outside CI) |
| `130` | Interrupted (SIGINT / Ctrl-C) |
| `143` | Terminated (SIGTERM) |

## Scheduling (cron)

The installer adds a weekly cron (`0 4 * * 0`) automatically. To schedule manually, set a full
`PATH` — Trixie's cron runs with a reduced one:

```cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/30 * * * * /usr/local/bin/pihole_api_healthcheck.sh >> /var/log/pihole_healthcheck.log 2>&1
30 3 * * * /usr/local/bin/pihole_maintenance_pro.sh >> /var/log/pihole_maintenance_pro.log 2>&1
```

## Pi-hole v6 API notes

- `setupVars.conf` is gone; configuration lives in `/etc/pihole/pihole.toml`
- The API is served at `/api` (not `/api.php`)
- Authentication uses session tokens: `POST /api/auth` returns `sid`, passed via the `X-FTL-SID`
  header
- The healthcheck tool (`tools/pihole_api_healthcheck.sh`) can query endpoints when
  `PIHOLE_API_URL` is set; set `PIHOLE_PASSWORD` to enable session login (see `.env.example`)
- Unbound is optional and not required by this script

## Troubleshooting

**Missing `sqlite3` (FTL toplists):**

```bash
sudo apt update && sudo apt install -y sqlite3
```

**Test FTL database read access:**

```bash
sudo sqlite3 -readonly /etc/pihole/pihole-FTL.db "SELECT COUNT(*) FROM queries;"
```

**Locale warnings:**

```bash
echo -e "en_GB.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8" | sudo tee /etc/locale.gen >/dev/null
sudo locale-gen && sudo update-locale LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8
```

- **Cron didn't run reliably:** ensure a full `PATH` in the crontab (see [Scheduling](#scheduling-cron)).
- **Pi 3B `linux-image-rpi-v8` note:** ignorable on ARMv7.

## Contributing

Contributions are welcome. See [`AGENTS.md`](AGENTS.md) for structure and conventions, and run the
local checks before opening a PR:

```bash
make check   # bash -n + shellcheck + shfmt
```

Please follow Conventional Commits (`feat:`, `fix(scope):`, `docs:`, `ci:`, `chore:`).

## License

MIT. See [LICENSE](LICENSE).

## Support

If this project helps you, you can support it here: [buymeacoffee.com/timintech](https://buymeacoffee.com/timintech)
