# 🔐 Security Policy

## 🧩 Supported Versions

We currently support the latest version of this project only.

## 📢 Reporting a Vulnerability

If you discover a security vulnerability, **please do not open an issue publicly**.

Instead, contact the maintainer **Tim (github.com/TimInTech)** privately via GitHub or email, and we will respond as quickly as possible.

All responsible disclosures will be acknowledged.

The helper script `tools/pihole_api_healthcheck.sh` may read `/etc/pihole/cli_pw` for local diagnostics only. This credential rotates automatically when pihole-FTL restarts and must never be exposed remotely.
