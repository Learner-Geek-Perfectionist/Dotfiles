#!/bin/bash
# Managed bb-browser installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

WRAPPER_PATH="$HOME/.local/bin/bb-browser-user"
STATE_FILE="$(bb_browser_state_file)"

managed_npm_prefix() {
	local npm_prefix

	npm_prefix="$(npm prefix -g 2>/dev/null || npm config get prefix 2>/dev/null || true)"
	npm_prefix="${npm_prefix%/}"
	[[ -n "$npm_prefix" ]] || return 1
	printf '%s\n' "$npm_prefix"
}

backup_artifact() {
	local target="$1" backup_file

	[[ -e "$target" ]] || return 0

	backup_file="$(mktemp "${TMPDIR:-/tmp}/bb-browser-install.XXXXXX")"
	cp -p "$target" "$backup_file"
	printf '%s\n' "$backup_file"
}

restore_artifact() {
	local target="$1" backup_file="$2"

	if [[ -n "$backup_file" && -e "$backup_file" ]]; then
		mkdir -p "$(dirname "$target")"
		cp -p "$backup_file" "$target"
		return 0
	fi

	rm -f "$target"
}

rollback_install_artifacts() {
	local wrapper_backup="$1" state_backup="$2"

	restore_artifact "$WRAPPER_PATH" "$wrapper_backup"
	restore_artifact "$STATE_FILE" "$state_backup"
}

rollback_managed_bb_browser() {
	local npm_prefix="$1" preexisting_bb_browser="$2" managed_bb_browser="$3" managed_backup="$4"

	[[ -n "$npm_prefix" && "$npm_prefix" != "/" ]] || return 0
	if [[ -n "$managed_backup" ]]; then
		restore_artifact "$managed_bb_browser" "$managed_backup"
		return 0
	fi
	if [[ "$preexisting_bb_browser" == "$managed_bb_browser" ]]; then
		return 0
	fi
	command -v npm &>/dev/null || return 0

	npm --prefix "$npm_prefix" uninstall -g bb-browser >/dev/null 2>&1 || true
}

cleanup_artifact_backup() {
	local backup_file="$1"

	[[ -n "$backup_file" ]] || return 0
	rm -f "$backup_file"
}

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
	local preexisting_bb_browser installed_version real_bb_browser_path managed_prefix
	local managed_bb_browser managed_bb_browser_backup wrapper_backup state_backup

	require_npm || return 0

	preexisting_bb_browser="$(command -v bb-browser 2>/dev/null || true)"
	managed_prefix="$(managed_npm_prefix || true)"
	managed_bb_browser=""
	if [[ -n "$managed_prefix" ]]; then
		managed_bb_browser="$managed_prefix/bin/bb-browser"
	fi
	managed_bb_browser_backup=""
	if [[ -n "$preexisting_bb_browser" && "$preexisting_bb_browser" == "$managed_bb_browser" ]]; then
		managed_bb_browser_backup="$(backup_artifact "$preexisting_bb_browser")"
	fi

	print_info "安装 bb-browser (via npm)..."
	if ! npm install -g bb-browser@latest; then
		print_warn "bb-browser 安装失败"
		return 0
	fi

	wrapper_backup="$(backup_artifact "$WRAPPER_PATH")"
	state_backup="$(backup_artifact "$STATE_FILE")"

	if ! install_wrapper; then
		rollback_managed_bb_browser "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup"
		rollback_install_artifacts "$wrapper_backup" "$state_backup"
		cleanup_artifact_backup "$wrapper_backup"
		cleanup_artifact_backup "$state_backup"
		cleanup_artifact_backup "$managed_bb_browser_backup"
		return 1
	fi

	real_bb_browser_path="$(installed_bb_browser_path)"
	installed_version=""
	if [[ -n "$real_bb_browser_path" ]]; then
		installed_version="$("$real_bb_browser_path" --version 2>/dev/null || true)"
	fi

	if ! write_state_file "$preexisting_bb_browser" "$installed_version" "$real_bb_browser_path"; then
		rollback_managed_bb_browser "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup"
		rollback_install_artifacts "$wrapper_backup" "$state_backup"
		cleanup_artifact_backup "$wrapper_backup"
		cleanup_artifact_backup "$state_backup"
		cleanup_artifact_backup "$managed_bb_browser_backup"
		return 1
	fi

	if ! "$WRAPPER_PATH" doctor; then
		rollback_managed_bb_browser "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup"
		rollback_install_artifacts "$wrapper_backup" "$state_backup"
		cleanup_artifact_backup "$wrapper_backup"
		cleanup_artifact_backup "$state_backup"
		cleanup_artifact_backup "$managed_bb_browser_backup"
		print_error "bb-browser 健康检查失败"
		return 1
	fi

	cleanup_artifact_backup "$wrapper_backup"
	cleanup_artifact_backup "$state_backup"
	cleanup_artifact_backup "$managed_bb_browser_backup"
}

main "$@"
