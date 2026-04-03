#!/bin/bash
# Managed bb-browser installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

WRAPPER_PATH="$HOME/.local/bin/bb-browser-user"
WRAPPER_BACKUP_PATH="$(bb_browser_wrapper_backup_file)"
XIAOHONGSHU_SEARCH_TEMPLATE="$SCRIPT_DIR/bb-browser-sites/xiaohongshu/search.js"
XIAOHONGSHU_SEARCH_PATH="$(bb_browser_xiaohongshu_search_file)"
XIAOHONGSHU_SEARCH_BACKUP_PATH="$(bb_browser_xiaohongshu_search_backup_file)"
STATE_FILE="$(bb_browser_state_file)"
CONFIG_FILE="$(bb_browser_config_file)"

managed_npm_root() {
	local npm_root

	npm_root="$(npm root -g 2>/dev/null || true)"
	npm_root="${npm_root%/}"
	[[ -n "$npm_root" ]] || return 1
	printf '%s\n' "$npm_root"
}

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

rollback_xiaohongshu_search_artifacts() {
	local preexisting_search_marker="$1"

	if [[ "$preexisting_search_marker" == "1" && -e "$XIAOHONGSHU_SEARCH_BACKUP_PATH" ]]; then
		restore_artifact "$XIAOHONGSHU_SEARCH_PATH" "$XIAOHONGSHU_SEARCH_BACKUP_PATH"
		return 0
	fi

	rm -f "$XIAOHONGSHU_SEARCH_PATH"
}

rollback_install_artifacts() {
	local preexisting_wrapper_marker="$1" preexisting_search_marker="$2"
	local wrapper_backup_backup="$3" search_backup_backup="$4" state_backup="$5" config_backup="$6"

	rollback_wrapper_artifacts "$preexisting_wrapper_marker"
	rollback_xiaohongshu_search_artifacts "$preexisting_search_marker"
	restore_artifact "$WRAPPER_BACKUP_PATH" "$wrapper_backup_backup"
	restore_artifact "$XIAOHONGSHU_SEARCH_BACKUP_PATH" "$search_backup_backup"
	restore_artifact "$STATE_FILE" "$state_backup"
	restore_artifact "$CONFIG_FILE" "$config_backup"
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

cleanup_install_backups() {
	local wrapper_backup_backup="$1" search_backup_backup="$2" state_backup="$3" managed_bb_browser_backup="$4" config_backup="$5"

	cleanup_artifact_backup "$wrapper_backup_backup"
	cleanup_artifact_backup "$search_backup_backup"
	cleanup_artifact_backup "$state_backup"
	cleanup_artifact_backup "$managed_bb_browser_backup"
	cleanup_artifact_backup "$config_backup"
}

rollback_install_attempt() {
	local managed_prefix="$1" preexisting_bb_browser="$2" managed_bb_browser="$3" managed_bb_browser_backup="$4"
	local preexisting_wrapper_marker="$5" preexisting_search_marker="$6"
	local wrapper_backup_backup="$7" search_backup_backup="$8" state_backup="$9" config_backup="${10}"

	rollback_managed_bb_browser "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup"
	rollback_install_artifacts "$preexisting_wrapper_marker" "$preexisting_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
	cleanup_install_backups "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$managed_bb_browser_backup" "$config_backup"
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
			"${REAL_BB_BROWSER_PATH:-}" \
			"${PREEXISTING_XIAOHONGSHU_SEARCH:-}" \
			"${PREEXISTING_XIAOHONGSHU_SEARCH_PATH:-}" \
			"${PREEXISTING_XIAOHONGSHU_SEARCH_BACKUP_PATH:-}"
	)
}

write_state_file() {
	local preexisting_marker="$1"
	local preexisting_path="$2"
	local preexisting_wrapper_marker="$3"
	local preexisting_xiaohongshu_search_marker="$4"
	local preexisting_xiaohongshu_search_path="$5"
	local installed_version="$6"
	local real_bb_browser_path="$7"

	mkdir -p "$(dirname "$STATE_FILE")"
	{
		printf 'PREEXISTING_BB_BROWSER=%s\n' "$preexisting_marker"
		printf 'PREEXISTING_BB_BROWSER_PATH='
		printf '%q\n' "$preexisting_path"
		printf 'PREEXISTING_WRAPPER=%s\n' "$preexisting_wrapper_marker"
		printf 'PREEXISTING_WRAPPER_BACKUP_PATH='
		printf '%q\n' "$WRAPPER_BACKUP_PATH"
		printf 'PREEXISTING_XIAOHONGSHU_SEARCH=%s\n' "$preexisting_xiaohongshu_search_marker"
		printf 'PREEXISTING_XIAOHONGSHU_SEARCH_PATH='
		printf '%q\n' "$preexisting_xiaohongshu_search_path"
		printf 'PREEXISTING_XIAOHONGSHU_SEARCH_BACKUP_PATH='
		printf '%q\n' "$XIAOHONGSHU_SEARCH_BACKUP_PATH"
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

prepare_xiaohongshu_search_backup() {
	local preexisting_search_marker="$1" tracked_preexisting_search="$2"

	if [[ "$preexisting_search_marker" == "1" ]]; then
		if [[ "$tracked_preexisting_search" == "1" && -e "$XIAOHONGSHU_SEARCH_BACKUP_PATH" ]]; then
			return 0
		fi
		mkdir -p "$(dirname "$XIAOHONGSHU_SEARCH_BACKUP_PATH")"
		cp -p "$XIAOHONGSHU_SEARCH_PATH" "$XIAOHONGSHU_SEARCH_BACKUP_PATH"
		return 0
	fi

	rm -f "$XIAOHONGSHU_SEARCH_BACKUP_PATH"
}

install_wrapper() {
	mkdir -p "$(dirname "$WRAPPER_PATH")"
	cp "$SCRIPT_DIR/bb-browser-user.sh" "$WRAPPER_PATH"
	chmod 755 "$WRAPPER_PATH"
}

write_managed_config() {
	mkdir -p "$(dirname "$CONFIG_FILE")"
	cat >"$CONFIG_FILE" <<'EOF'
{
  "browser": "microsoft-edge",
  "profileDirectory": "Default",
  "port": 19825
}
EOF
}

install_managed_xiaohongshu_search() {
	[[ -f "$XIAOHONGSHU_SEARCH_TEMPLATE" ]] || return 1
	mkdir -p "$(dirname "$XIAOHONGSHU_SEARCH_PATH")"
	cp "$XIAOHONGSHU_SEARCH_TEMPLATE" "$XIAOHONGSHU_SEARCH_PATH"
	chmod 644 "$XIAOHONGSHU_SEARCH_PATH"
}

verify_wrapper_mcp_bootstrap() {
	local tmp_dir request_file output_file pid rc

	tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bb-browser-mcp.XXXXXX")" || return 1
	request_file="$tmp_dir/request.jsonl"
	output_file="$tmp_dir/output.jsonl"
	cat >"$request_file" <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"dotfiles-installer","version":"1.0.0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
EOF

	rc=1
	(
		cat "$request_file"
	) | "$WRAPPER_PATH" --mcp >"$output_file" 2>/dev/null &
	pid="$!"

	for _ in {1..20}; do
		if ! kill -0 "$pid" >/dev/null 2>&1; then
			if wait "$pid"; then
				rc=0
			else
				rc=$?
			fi
			break
		fi
		sleep 1
	done

	if kill -0 "$pid" >/dev/null 2>&1; then
		kill "$pid" >/dev/null 2>&1 || true
		wait "$pid" >/dev/null 2>&1 || true
		rm -rf "$tmp_dir"
		return 1
	fi

	if [[ "$rc" -ne 0 ]]; then
		rm -rf "$tmp_dir"
		return 1
	fi

	if ! grep -Eq '"protocolVersion"[[:space:]]*:[[:space:]]*"2024-11-05"' "$output_file"; then
		rm -rf "$tmp_dir"
		return 1
	fi

	if ! grep -Eq '"tools"[[:space:]]*:' "$output_file"; then
		rm -rf "$tmp_dir"
		return 1
	fi

	rm -rf "$tmp_dir"
}

apply_managed_dist_patches() {
	local npm_root="$1" dist_dir
	[[ -n "$npm_root" ]] || return 0
	dist_dir="$npm_root/bb-browser/dist"
	[[ -d "$dist_dir" ]] || return 0

	node "$SCRIPT_DIR/patch_bb_browser_dist.mjs" "$dist_dir" >>"$DOTFILES_LOG" 2>&1
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
	local preexisting_wrapper_marker preexisting_xiaohongshu_search_marker preexisting_xiaohongshu_search_path
	local installed_version real_bb_browser_path managed_prefix
	local managed_bb_browser managed_bb_browser_backup wrapper_backup_backup search_backup_backup state_backup config_backup managed_root
	local recorded_preexisting_bb recorded_preexisting_bb_path recorded_preexisting_wrapper
	local recorded_wrapper_backup_path recorded_real_bb_browser_path
	local recorded_preexisting_xiaohongshu_search recorded_preexisting_xiaohongshu_search_path recorded_xiaohongshu_search_backup_path

	require_npm || return 0

	{
		IFS= read -r recorded_preexisting_bb || true
		IFS= read -r recorded_preexisting_bb_path || true
		IFS= read -r recorded_preexisting_wrapper || true
		IFS= read -r recorded_wrapper_backup_path || true
		IFS= read -r recorded_real_bb_browser_path || true
		IFS= read -r recorded_preexisting_xiaohongshu_search || true
		IFS= read -r recorded_preexisting_xiaohongshu_search_path || true
		IFS= read -r recorded_xiaohongshu_search_backup_path || true
	} < <(read_existing_install_state || true)
	if [[ -n "$recorded_wrapper_backup_path" ]]; then
		WRAPPER_BACKUP_PATH="$recorded_wrapper_backup_path"
	fi
	if [[ -n "$recorded_xiaohongshu_search_backup_path" ]]; then
		XIAOHONGSHU_SEARCH_BACKUP_PATH="$recorded_xiaohongshu_search_backup_path"
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

	preexisting_xiaohongshu_search_marker=0
	preexisting_xiaohongshu_search_path=""
	if [[ "$recorded_preexisting_xiaohongshu_search" == "0" ]]; then
		preexisting_xiaohongshu_search_marker=0
		preexisting_xiaohongshu_search_path=""
	elif [[ "$recorded_preexisting_xiaohongshu_search" == "1" && -n "$recorded_preexisting_xiaohongshu_search_path" ]]; then
		preexisting_xiaohongshu_search_marker=1
		preexisting_xiaohongshu_search_path="$recorded_preexisting_xiaohongshu_search_path"
	elif [[ -e "$XIAOHONGSHU_SEARCH_PATH" ]]; then
		preexisting_xiaohongshu_search_marker=1
		preexisting_xiaohongshu_search_path="$XIAOHONGSHU_SEARCH_PATH"
	fi

	print_info "安装 bb-browser (via npm)..."
	if ! npm install -g bb-browser@latest >>"$DOTFILES_LOG" 2>&1; then
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
	search_backup_backup="$(backup_artifact "$XIAOHONGSHU_SEARCH_BACKUP_PATH")"
	state_backup="$(backup_artifact "$STATE_FILE")"
	config_backup="$(backup_artifact "$CONFIG_FILE")"

	if ! prepare_wrapper_backup "$preexisting_wrapper_marker" "$recorded_preexisting_wrapper"; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		return 1
	fi

	if ! prepare_xiaohongshu_search_backup "$preexisting_xiaohongshu_search_marker" "$recorded_preexisting_xiaohongshu_search"; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		return 1
	fi

	if ! install_wrapper; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		return 1
	fi

	managed_root="$(managed_npm_root || true)"
	if ! apply_managed_dist_patches "$managed_root"; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		print_error "bb-browser dist 补丁应用失败"
		return 1
	fi

	if ! install_managed_xiaohongshu_search; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		print_error "bb-browser 小红书 adapter 安装失败"
		return 1
	fi

	if ! write_managed_config; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		print_error "bb-browser 配置写入失败"
		return 1
	fi

	real_bb_browser_path="$(installed_bb_browser_path)"
	installed_version=""
	if [[ -n "$real_bb_browser_path" ]]; then
		installed_version="$("$real_bb_browser_path" --version 2>/dev/null || true)"
	fi

	if ! write_state_file "$preexisting_bb_browser_marker" "$preexisting_bb_browser_path" "$preexisting_wrapper_marker" \
		"$preexisting_xiaohongshu_search_marker" "$preexisting_xiaohongshu_search_path" "$installed_version" "$real_bb_browser_path"; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		return 1
	fi

	if ! "$WRAPPER_PATH" doctor; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		print_error "bb-browser 健康检查失败"
		return 1
	fi

	if ! verify_wrapper_mcp_bootstrap; then
		rollback_install_attempt "$managed_prefix" "$preexisting_bb_browser" "$managed_bb_browser" "$managed_bb_browser_backup" \
			"$preexisting_wrapper_marker" "$preexisting_xiaohongshu_search_marker" "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$config_backup"
		print_error "bb-browser MCP 初始化检查失败"
		return 1
	fi

	cleanup_install_backups "$wrapper_backup_backup" "$search_backup_backup" "$state_backup" "$managed_bb_browser_backup" "$config_backup"
	refresh_codex_config
}

main "$@"
