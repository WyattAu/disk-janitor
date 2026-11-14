SHELL_SCRIPTS := $(wildcard scripts/*.sh)

.PHONY: lint test build fmt fmt-check coverage contract ci

lint: ## shellcheck + bash -n on every script
	@command -v shellcheck >/dev/null || { echo "shellcheck not installed"; exit 1; }
	shellcheck $(SHELL_SCRIPTS)
	for f in $(SHELL_SCRIPTS); do bash -n "$$f"; done
	@echo "lint clean"

test: lint ## smoke: dry-run style checks that do not delete anything
	@bash -c 'source /dev/stdin <<< "$$(sed -n "/^is_artifact_dir()/,/^}/p" scripts/disk-janitor.sh)"; \
	set -e; \
	$$0 /x/node_modules/pkg/build >/dev/null 2>&1 || true; \
	if is_artifact_dir /x/node_modules/astro/dist/build; then echo "FAIL: node_modules not protected"; exit 1; fi; \
	if is_artifact_dir /x/vendor/crate/src/build; then echo "FAIL: vendor not protected"; exit 1; fi; \
	is_artifact_dir /x/repo/target || { echo "FAIL: target should be deletable"; exit 1; }; \
	is_artifact_dir /x/repo/proofs/.lake || { echo "FAIL: .lake should be deletable"; exit 1; }; \
	if is_artifact_dir /x/repo/src/build; then echo "FAIL: bare source build protected"; exit 1; fi; \
	echo "guard tests passed"'

build: ## no build step; placeholder for verb parity
	@echo "nothing to build (shell scripts)"

fmt: ## no formatter wired; placeholder for verb parity
	@echo "no formatter configured (bashfmt not enforced)"

fmt-check: fmt

coverage: ## not applicable to shell
	@echo "coverage not applicable"

contract: test

ci: lint test
