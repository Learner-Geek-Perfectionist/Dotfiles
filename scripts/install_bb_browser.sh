#!/bin/bash
# Managed bb-browser installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

WRAPPER_PATH="$HOME/.local/bin/bb-browser-user"
WRAPPER_BACKUP_PATH="$(bb_browser_wrapper_backup_file)"
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

rollback_wrapper_artifacts() {
	local preexisting_wrapper_marker="$1"

	if [[ "$preexisting_wrapper_marker" == "1" && -e "$WRAPPER_BACKUP_PATH" ]]; then
		restore_artifact "$WRAPPER_PATH" "$WRAPPER_BACKUP_PATH"
		return 0
	fi

	rm -f "$WRAPPER_PATH"
}

rollback_install_artifacts() {
	local preexisting_wrapper_marker="$1" wrapper_backup_backup="$2" state_backup="$3"

	rollback_wrapper_artifacts "$preexisting_wrapper_marker"
	restore_artifact "$WRAPPER_BACKUP_PATH" "$wrapper_backup_backup"
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

read_existing_install_state() {
	[[ -f "$STATE_FILE" ]] || return 0

	(
		set +u
		# shellcheck disable=SC1090
		source "$STATE_FILE"
		printf '%s\n' \
			"${PREEXISTING_BB_BROWSER:-}" \
			"${PREEXISTING_BB_BROWSER_PATH:-}" \
			"${PREEXISTING_WRAPPER:-}" \
			"${PREEXISTING_WRAPPER_BACKUP_PATH:-}" \
			"${REAL_BB_BROWSER_PATH:-}"
	)
}

write_state_file() {
	local preexisting_marker="$1"
	local preexisting_path="$2"
	local preexisting_wrapper_marker="$3"
	local installed_version="$4"
	local real_bb_browser_path="$5"

	mkdir -p "$(dirname "$STATE_FILE")"
	{
		printf 'PREEXISTING_BB_BROWSER=%s\n' "$preexisting_marker"
		printf 'PREEXISTING_BB_BROWSER_PATH='
		printf '%q\n' "$preexisting_path"
		printf 'PREEXISTING_WRAPPER=%s\n' "$preexisting_wrapper_marker"
		printf 'PREEXISTING_WRAPPER_BACKUP_PATH='
		printf '%q\n' "$WRAPPER_BACKUP_PATH"
		printf 'INSTALLED_VERSION='
		printf '%q\n' "$installed_version"
		printf 'WRAPPER_PATH='
		printf '%q\n' "$WRAPPER_PATH"
		printf 'REAL_BB_BROWSER_PATH='
		printf '%q\n' "$real_bb_browser_path"
	} >"$STATE_FILE"
}

refresh_codex_config() {
	local codex_src="$SCRIPT_DIR/../.codex/config.toml"
	local codex_dest="$HOME/.codex/config.toml"

	[[ -f "$SCRIPT_DIR/deploy_codex_config.sh" && -f "$codex_src" ]] || return 0
	if ! bash "$SCRIPT_DIR/deploy_codex_config.sh" "$codex_src" "$codex_dest" "$HOME"; then
		print_warn "bb-browser 安装完成，但 Codex 配置刷新失败"
	fi
}

prepare_wrapper_backup() {
	local preexisting_wrapper_marker="$1" tracked_preexisting_wrapper="$2"

	if [[ "$preexisting_wrapper_marker" == "1" ]]; then
		if [[ "$tracked_preexisting_wrapper" == "1" && -e "$WRAPPER_BACKUP_PATH" ]]; then
			return 0
		fi
		mkdir -p "$(dirname "$WRAPPER_BACKUP_PATH")"
		cp -p "$WRAPPER_PATH" "$WRAPPER_BACKUP_PATH"
		return 0
	fi

	rm -f "$WRAPPER_BACKUP_PATH"
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
	local preexisting_bb_browser preexisting_bb_browser_marker preexisting_bb_browser_path
	local preexisting_wrapper_marker
	local installed_version real_bb_browser_path managed_prefix
	local managed_bb_browser managed_bb_browser_backup wrapper_backup_backup state_backup
	local recorded_preexisting_bb recorded_preexisting_bb_path recorded_preexisting_wrapper
	local recorded_wrapper_backup_path recorded_real_bb_browser_path

	require_npm || return 0

	{
		IFS= read -r recorded_preexisting_bb || true
		IFS= read -r recorded_preexisting_bb_path || true
		IFS= read -r recorded_preexisting_wrapper || true
		IFS= read -r recorded_wrapper_backup_path || true
		IFS= read -r recorded_real_bb_browser_path || true
	} < <(read_existing_install_state || true)
	if [[ -n "$recorded_wrapper_backup_path" ]]; then
		WRAPPER_BACKUP_PATH="$recorded_wrapper_backup_path"
	fi

	preexisting_bb_browser="$(command -v bb-browser 2>/dev/null || true)"
	preexisting_bb_browser_marker=0
	preexisting_bb_browser_path=""
	if [[ "$recorded_preexisting_bb" == "0" && -n "$recorded_real_bb_browser_path" && "$preexisting_bb_browser" == "$recorded_real_bb_browser_path" ]]; then
		preexisting_bb_browser_marker=0
		preexisting_bb_browser_path=""
	elif [[ "$recorded_preexisting_bb" == "1" && -n "$recorded_preexisting_bb_path" ]]; then
		preexisting_bb_browser_marker=1
		preexisting_bb_browser_path="$recorded_preexisting_bb_path"
	elif [[ -n "$preexisting_bb_browser" ]]; then
		preexisting_bb_browser_marker=1
		preexisting_bb_browser_path="$preexisting_bb_browser"
	fi
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

	preexisting_wrapper_marker=0
	if [[ "$recorded_preexisting_wrapper" == "1" ]]; then
		preexisting_wrapper_marker=1
	elif [[ "$recorded_preexisting_wrapper" == "0" && -e "$WRAPPER_PATH" ]]; then
		preexisting_wrapper_marker=0
	elif [[ -e "$WRAPPER_PATH" ]]; then
		preexisting_wrapper_marker=1
	fi
	wrapper_backup_backup="$(backup_artifact "$WRAPPER_BACKUP_PATH")"
	state_backup="$(backup_artifact "$STATE_FILE")"

	if ! prepare_wrapper_backup "$preexisting_wrapper_marker" "$recorded_preexisting_wrapper"; then
		rollback_managed_bb_browser "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup"
		rollback_install_artifacts "$preexisting_wrapper_marker" "$wrapper_backup_backup" "$state_backup"
		cleanup_artifact_backup "$wrapper_backup_backup"
		cleanup_artifact_backup "$state_backup"
		cleanup_artifact_backup "$managed_bb_browser_backup"
		return 1
	fi

	if ! install_wrapper; then
		rollback_managed_bb_browser "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup"
		rollback_install_artifacts "$preexisting_wrapper_marker" "$wrapper_backup_backup" "$state_backup"
		cleanup_artifact_backup "$wrapper_backup_backup"
		cleanup_artifact_backup "$state_backup"
		cleanup_artifact_backup "$managed_bb_browser_backup"
		return 1
	fi

	real_bb_browser_path="$(installed_bb_browser_path)"
	installed_version=""
	if [[ -n "$real_bb_browser_path" ]]; then
		installed_version="$("$real_bb_browser_path" --version 2>/dev/null || true)"
	fi

	if ! write_state_file "$preexisting_bb_browser_marker" "$preexisting_bb_browser_path" "$preexisting_wrapper_marker" "$installed_version" "$real_bb_browser_path"; then
		rollback_managed_bb_browser "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup"
		rollback_install_artifacts "$preexisting_wrapper_marker" "$wrapper_backup_backup" "$state_backup"
		cleanup_artifact_backup "$wrapper_backup_backup"
		cleanup_artifact_backup "$state_backup"
		cleanup_artifact_backup "$managed_bb_browser_backup"
		return 1
	fi

	if ! "$WRAPPER_PATH" doctor; then
		rollback_managed_bb_browser "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup"
		rollback_install_artifacts "$preexisting_wrapper_marker" "$wrapper_backup_backup" "$state_backup"
		cleanup_artifact_backup "$wrapper_backup_backup"
		cleanup_artifact_backup "$state_backup"
		cleanup_artifact_backup "$managed_bb_browser_backup"
		print_error "bb-browser 健康检查失败"
		return 1
	fi

	cleanup_artifact_backup "$wrapper_backup_backup"
	cleanup_artifact_backup "$state_backup"
	cleanup_artifact_backup "$managed_bb_browser_backup"
	refresh_codex_config
}

main "$@"
