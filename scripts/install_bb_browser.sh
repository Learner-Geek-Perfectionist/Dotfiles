#!/bin/bash
# Managed bb-browser installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

WRAPPER_PATH="$HOME/.local/bin/bb-browser-user"
STATE_FILE="$(bb_browser_state_file)"

require_npm() {
	if command -v npm &>/dev/null; then
		return 0
	fi

	print_warn "npm 未找到，跳过 bb-browser 安装"
	return 1
}

write_state_file() {
	local preexisting="$1"
	local installed_version="$2"
	local real_bb_browser_path="$3"

	mkdir -p "$(dirname "$STATE_FILE")"
	{
		printf 'PREEXISTING_BB_BROWSER='
		printf '%q\n' "$preexisting"
		printf 'INSTALLED_VERSION='
		printf '%q\n' "$installed_version"
		printf 'WRAPPER_PATH='
		printf '%q\n' "$WRAPPER_PATH"
		printf 'REAL_BB_BROWSER_PATH='
		printf '%q\n' "$real_bb_browser_path"
	} >"$STATE_FILE"
}

install_wrapper() {
	mkdir -p "$(dirname "$WRAPPER_PATH")"
	cp "$SCRIPT_DIR/bb-browser-user.sh" "$WRAPPER_PATH"
	chmod 755 "$WRAPPER_PATH"
}

installed_bb_browser_path() {
	local npm_prefix candidate

	npm_prefix="$(npm prefix -g 2>/dev/null || npm config get prefix 2>/dev/null || true)"
	npm_prefix="${npm_prefix%/}"
	if [[ -n "$npm_prefix" ]]; then
		candidate="$npm_prefix/bin/bb-browser"
		if [[ -x "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	fi

	candidate="$(command -v bb-browser 2>/dev/null || true)"
	if [[ -n "$candidate" ]]; then
		printf '%s\n' "$candidate"
		return 0
	fi
}

main() {
	local preexisting_bb_browser installed_version real_bb_browser_path

	require_npm || return 0

	preexisting_bb_browser="$(command -v bb-browser 2>/dev/null || true)"

	print_info "安装 bb-browser (via npm)..."
	if ! npm install -g bb-browser@latest; then
		print_warn "bb-browser 安装失败"
		return 0
	fi

	install_wrapper

	real_bb_browser_path="$(installed_bb_browser_path)"
	installed_version=""
	if [[ -n "$real_bb_browser_path" ]]; then
		installed_version="$("$real_bb_browser_path" --version 2>/dev/null || true)"
	fi

	write_state_file "$preexisting_bb_browser" "$installed_version" "$real_bb_browser_path"

	if ! "$WRAPPER_PATH" doctor; then
		print_warn "bb-browser doctor 检查失败"
	fi
}

main "$@"
