SHELL := /bin/bash
SHFMT ?= shfmt
SHELLCHECK ?= shellcheck

SCRIPTS := pihole_maintenance_pro.sh scripts/*.sh tools/*.sh

.PHONY: fmt lint check

fmt:
	@if command -v $(SHFMT) >/dev/null 2>&1; then \
		$(SHFMT) -i 2 -ci -sr -w $(SCRIPTS); \
	else \
		echo "shfmt not installed; skipping fmt"; \
	fi

lint:
	@if command -v $(SHELLCHECK) >/dev/null 2>&1; then \
		$(SHELLCHECK) -x $(SCRIPTS); \
	else \
		echo "shellcheck not installed; skipping lint"; \
	fi

check: fmt lint

