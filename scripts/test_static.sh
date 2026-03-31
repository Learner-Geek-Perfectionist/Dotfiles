#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test_helpers.sh
source "$SCRIPT_DIR/test_helpers.sh"

run_shell_syntax_checks() {
	cd "$REPO_ROOT"
	local shell_files=(
		install.sh
		uninstall.sh
		lib/*.sh
		scripts/*.sh
		scripts/wrappers/*
		sh-script/*.sh
	)
	local file
	for file in "${shell_files[@]}"; do
		bash -n "$file"
	done
}

run_python_checks() {
	cd "$REPO_ROOT"
	if ! command -v python3 &>/dev/null; then
		if [[ "${CI:-}" == "true" ]]; then
			fail "python3 is required in CI"
		fi
		warn "python3 not found, skipping Python syntax checks"
		return 0
	fi

	python3 -m py_compile .config/kitty/*.py
}

run_lua_checks() {
	cd "$REPO_ROOT"
	if ! command -v luac &>/dev/null; then
		if [[ "${CI:-}" == "true" ]]; then
			fail "luac is required in CI"
		fi
		warn "luac not found, skipping Lua syntax checks"
		return 0
	fi

	find .hammerspoon -name '*.lua' -print0 | xargs -0 -n1 luac -p
}

run_shellcheck() {
	cd "$REPO_ROOT"
	if ! command -v shellcheck &>/dev/null; then
		if [[ "${CI:-}" == "true" ]]; then
			fail "shellcheck is required in CI"
		fi
		warn "shellcheck not found, skipping ShellCheck"
		return 0
	fi

	shellcheck -S warning install.sh uninstall.sh lib/*.sh scripts/*.sh scripts/wrappers/* sh-script/*.sh
}

run_test "Shell syntax" run_shell_syntax_checks
run_test "Python syntax" run_python_checks
run_test "Lua syntax" run_lua_checks
run_test "ShellCheck" run_shellcheck

section "Done"
pass "Static checks completed"
