.PHONY: check fmt lint

SHELL := /bin/bash
SHFMT ?= shfmt
SHELLCHECK ?= shellcheck

SCRIPTS := pihole_maintenance_pro.sh scripts/*.sh tools/*.sh

check:
	@echo "bash -n"
	bash -n $(SCRIPTS)
	@echo "shellcheck"
	@if command -v $(SHELLCHECK) >/dev/null 2>&1; then \
		$(SHELLCHECK) -x $(SCRIPTS) || true; \
	else \
		echo "shellcheck not installed; skipping"; \
	fi
	@echo "shfmt -d (no changes)"
	@if command -v $(SHFMT) >/dev/null 2>&1; then \
		$(SHFMT) -i 2 -ci -sr -d .; \
	else \
		echo "shfmt not installed; skipping"; \
	fi

fmt:
	@if command -v $(SHFMT) >/dev/null 2>&1; then \
		$(SHFMT) -i 2 -ci -sr -w .; \
	else \
		echo "shfmt not installed; skipping"; \
	fi

lint:
	@if command -v $(SHELLCHECK) >/dev/null 2>&1; then \
		$(SHELLCHECK) -x $(SCRIPTS); \
	else \
		echo "shellcheck not installed; skipping"; \
	fi
