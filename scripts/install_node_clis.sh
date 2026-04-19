#!/bin/bash
# shellcheck disable=SC2088
# Unified npm-global installer for Node-based CLIs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

OS=""
STATE_FILE="$(node_cli_npm_state_file)"

NODE_CLI_PACKAGES=(
	"@anthropic-ai/claude-code"
	"@openai/codex"
	"@mermaid-js/mermaid-cli"
	"bb-browser"
	"typescript-language-server"
	"typescript"
	"intelephense"
)

package_install_command() {
	local package="$1"
	printf '%s@latest\n' "$package"
}

sync_linux_npm_prefix() {
	local desired_prefix npmrc tmp

	desired_prefix="$(linux_npm_global_prefix)"
	npmrc="$HOME/.npmrc"
	tmp="$(mktemp)"

	if [[ -f "$npmrc" ]]; then
		awk -v desired="$desired_prefix" '
			BEGIN { replaced = 0 }
			/^[[:space:]]*prefix[[:space:]]*=/ {
				if (!replaced) {
					print "prefix=" desired
					replaced = 1
				}
				next
			}
			{ print }
			END {
				if (!replaced) {
					print "prefix=" desired
				}
			}
		' "$npmrc" >"$tmp"
	else
		printf 'prefix=%s\n' "$desired_prefix" >"$tmp"
	fi

	mv "$tmp" "$npmrc"
	export npm_config_prefix="$desired_prefix"
	export NPM_CONFIG_PREFIX="$desired_prefix"
	export PATH="$(linux_npm_global_bin_dir):$PATH"
}

ensure_npm_ready() {
	if ! command -v npm &>/dev/null; then
		print_warn "npm 未找到，跳过 Node CLI 安装"
		return 1
	fi

	if [[ "$OS" == "linux" ]]; then
		sync_linux_npm_prefix
	fi

	return 0
}

npm_prefix_for_state() {
	if [[ "$OS" == "linux" ]]; then
		linux_npm_global_prefix
		return 0
	fi

	npm prefix -g 2>/dev/null || npm config get prefix 2>/dev/null || true
}

npm_root_for_prefix() {
	local prefix="$1"
	[[ -n "$prefix" ]] || return 1
	printf '%s/lib/node_modules\n' "${prefix%/}"
}

package_preexisted() {
	local package="$1" npm_root="$2"
	[[ -d "$npm_root/$package" ]]
}

write_state_file() {
	local prefix="$1"
	shift
	local entries=("$@")

	mkdir -p "$(dirname "$STATE_FILE")"
	{
		printf 'prefix\t%s\n' "$prefix"
		printf '%s\n' "${entries[@]}"
	} >"$STATE_FILE"
}

run_npm_global_install() {
	local install_target="$1"

	if [[ -n "${DOTFILES_LOG:-}" ]]; then
		npm install -g "$install_target" >>"$DOTFILES_LOG" 2>&1
	else
		npm install -g "$install_target" >/dev/null 2>&1
	fi
}

install_node_clis() {
	local managed_prefix managed_root
	local installed=0 updated=0 failed=0
	local state_entries=()

	managed_prefix="$(npm_prefix_for_state)"
	managed_prefix="${managed_prefix%/}"
	[[ -n "$managed_prefix" ]] || {
		print_warn "无法解析 npm global prefix，跳过 Node CLI 安装"
		return 0
	}

	managed_root="$(npm_root_for_prefix "$managed_prefix")"

	print_info "安装 Node CLI（npm global）..."
	print_dim "npm prefix: $managed_prefix"

	local package install_target preexisting_marker
	for package in "${NODE_CLI_PACKAGES[@]}"; do
		install_target="$(package_install_command "$package")"
		preexisting_marker=0
		if package_preexisted "$package" "$managed_root"; then
			preexisting_marker=1
		fi

		if run_npm_global_install "$install_target"; then
			if [[ "$preexisting_marker" == "1" ]]; then
				updated=$((updated + 1))
			else
				installed=$((installed + 1))
			fi
			state_entries+=($'package\t'"${package}"$'\t'"${preexisting_marker}")
		else
			print_warn "Node CLI 安装失败: $package"
			failed=$((failed + 1))
		fi
	done

	if [[ ${#state_entries[@]} -gt 0 ]]; then
		write_state_file "$managed_prefix" "${state_entries[@]}"
	fi

	if [[ $failed -eq 0 ]]; then
		print_success "Node CLI: 新增 $installed, 更新 $updated"
	else
		print_warn "Node CLI: 新增 $installed, 更新 $updated, 失败 $failed"
	fi
}

main() {
	OS="$(detect_os)"

	ensure_npm_ready || return 0
	install_node_clis
}

main "$@"
