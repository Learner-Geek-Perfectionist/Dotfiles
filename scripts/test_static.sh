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

capture_bootstrap_banner() {
	local width="$1" msg="$2"
	local temp_source log_file
	temp_source="$(mktemp)"
	log_file="$(mktemp)"

	sed '$d' "$REPO_ROOT/install.sh" >"$temp_source"
	(
		export COLUMNS="$width" DOTFILES_LOG="$log_file" TERM="xterm-256color"
		# shellcheck source=/dev/null
		source "$temp_source"
		print_banner "$msg"
	)

	rm -f "$temp_source" "$log_file"
}

capture_utils_banner() {
	local width="$1" msg="$2"
	local log_file
	log_file="$(mktemp)"

	(
		export COLUMNS="$width" DOTFILES_LOG="$log_file" TERM="xterm-256color"
		# shellcheck source=../lib/utils.sh
		source "$REPO_ROOT/lib/utils.sh"
		print_banner "$msg"
	)

	rm -f "$log_file"
}

inspect_banner_output() {
	python3 - "$1" <<'PY'
import re
import sys

line = re.sub(r'\x1b\[[0-9;]*m', '', sys.argv[1]).rstrip('\n')
leading = len(line) - len(line.lstrip(' '))
trailing = len(line) - len(line.rstrip(' '))
core_end = len(line) - trailing if trailing else len(line)
print(f"{leading}|{trailing}|{line[leading:core_end]}")
PY
}

assert_banner_layout() {
	local label="$1" output="$2" expected_left="$3" expected_right="$4" expected_text="$5"
	local actual left right text

	actual="$(inspect_banner_output "$output")"
	IFS='|' read -r left right text <<<"$actual"

	assert_equal "$expected_left" "$left" "$label left padding"
	assert_equal "$expected_right" "$right" "$label right padding"
	assert_equal "$expected_text" "$text" "$label content"
}

run_banner_regression_checks() {
	local output

	output="$(capture_bootstrap_banner 10 $'e\u0301')"
	assert_banner_layout "bootstrap combining mark" "$output" 4 5 $'e\u0301'

	output="$(capture_bootstrap_banner 10 '🇨🇳')"
	assert_banner_layout "bootstrap flag emoji" "$output" 4 4 '🇨🇳'

	output="$(capture_bootstrap_banner 10 '👨‍👩‍👧‍👦')"
	assert_banner_layout "bootstrap zwj emoji" "$output" 4 4 '👨‍👩‍👧‍👦'

	output="$(capture_utils_banner 10 $'e\u0301')"
	assert_banner_layout "utils combining mark" "$output" 4 5 $'e\u0301'

	output="$(capture_utils_banner 10 '🇨🇳')"
	assert_banner_layout "utils flag emoji" "$output" 4 4 '🇨🇳'

	output="$(capture_utils_banner 10 '👨‍👩‍👧‍👦')"
	assert_banner_layout "utils zwj emoji" "$output" 4 4 '👨‍👩‍👧‍👦'
}

run_install_clone_path_regression_checks() {
	local temp_source fake_bin log_file log_dir clone_dir
	temp_source="$(mktemp)"
	fake_bin="$(make_temp_dir)"
	log_file="$(mktemp)"

	sed '$d' "$REPO_ROOT/install.sh" >"$temp_source"
	cat >"$fake_bin/git" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/git"

	{
		IFS= read -r log_dir
		IFS= read -r clone_dir
	} < <(
		PATH="$fake_bin:/usr/bin:/bin" DOTFILES_LOG="$log_file" TERM="xterm-256color" bash -c '
			set -euo pipefail
			# shellcheck source=/dev/null
			source "$1"
			printf "%s\n" "$DOTFILES_LOG_DIR"
			clone_dotfiles 2>/dev/null
		' _ "$temp_source"
	)

	[[ "${log_dir,,}" != "${clone_dir,,}" ]] || fail "clone path collides with log dir on case-insensitive filesystems: $clone_dir"
	rm -f "$temp_source" "$log_file"
	rm -rf "$fake_bin"
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
run_test "Banner width" run_banner_regression_checks
run_test "Install clone path" run_install_clone_path_regression_checks
run_test "Python syntax" run_python_checks
run_test "Lua syntax" run_lua_checks
run_test "ShellCheck" run_shellcheck

section "Done"
pass "Static checks completed"
