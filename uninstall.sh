#!/bin/bash
# Dotfiles 卸载脚本

set -eo pipefail

# ========================================
# 日志配置
# ========================================
export DOTFILES_LOG_DIR="/tmp/dotfiles-logs-$(whoami)/uninstall"
export DOTFILES_LOG="${DOTFILES_LOG:-$DOTFILES_LOG_DIR/dotfiles-uninstall-$(whoami)-$(date '+%Y%m%d-%H%M%S').log}"

# ========================================
# 内嵌工具函数（避免路径依赖）
# ========================================
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置日志
setup_logging() {
	mkdir -p "$DOTFILES_LOG_DIR"
	echo "=== Dotfiles 卸载日志 $(date) ===" >"$DOTFILES_LOG"
}

# 加载工具函数
if [[ -f "$_SCRIPT_DIR/lib/utils.sh" ]]; then
	source "$_SCRIPT_DIR/lib/utils.sh"
else
	echo "错误: 未找到 lib/utils.sh，请在 Dotfiles 目录下运行此脚本"
	exit 1
fi

REMOVE_PIXI=false
REMOVE_DOTFILES=false
REMOVE_CLAUDE=false
FORCE=false

CLAUDE_MANAGED_MARKETPLACES=(
	anthropics/claude-plugins-official
	anthropics/skills
	obra/superpowers-marketplace
	jarrodwatts/claude-hud
)

CLAUDE_MANAGED_PLUGINS=(
	pyright-lsp@claude-plugins-official
	typescript-lsp@claude-plugins-official
	gopls-lsp@claude-plugins-official
	rust-analyzer-lsp@claude-plugins-official
	jdtls-lsp@claude-plugins-official
	clangd-lsp@claude-plugins-official
	csharp-lsp@claude-plugins-official
	php-lsp@claude-plugins-official
	kotlin-lsp@claude-plugins-official
	swift-lsp@claude-plugins-official
	lua-lsp@claude-plugins-official
	github@claude-plugins-official
	commit-commands@claude-plugins-official
	code-simplifier@claude-plugins-official
	claude-hud@claude-hud
	example-skills@anthropic-agent-skills
	superpowers@superpowers-marketplace
)

CLAUDE_MANAGED_MCPS=(
	tavily
	fetch
	open-websearch
	exa
	bb-browser
)

show_help() {
	cat <<'EOF'
用法: ./uninstall.sh [选项]

选项:
    --pixi       仅删除 Pixi (~/.pixi 等)
    --dotfiles   仅删除 Dotfiles 配置
    --claude     仅删除 Claude Code 用户配置（插件/Skill/Hook/Marketplace/MCP）
    --all        同时删除三者
    -f, --force  跳过确认
    -h, --help   显示帮助
EOF
}

confirm() {
	[[ "$FORCE" == "true" ]] && return 0
	read -r -p "$1 [y/N]: " ans
	[[ "$ans" =~ ^[Yy] ]]
}

rm_path() {
	local p="$1"
	[[ -z "$p" ]] && return
	# 规范化路径，防止 //、/tmp/../ 等变体绕过检查
	local real_p
	real_p="$(realpath -m "$p" 2>/dev/null || echo "$p")"
	[[ -z "$real_p" || "$real_p" == "/" ]] && return
	# 安全限制：只允许删除 $HOME 或 /tmp 下的路径
	if [[ "$real_p" != "$HOME"* && "$real_p" != "/tmp"* ]]; then
		print_warn "拒绝删除非 HOME/tmp 路径: $real_p"
		return
	fi
	if [[ -e "$p" || -L "$p" ]]; then
		rm -rf "$p" && print_dim "✓ $p"
	fi
}

prune_empty_parents() {
	local dir="$1"
	while [[ "$dir" == "$HOME"* && "$dir" != "$HOME" ]]; do
		rmdir "$dir" 2>/dev/null || break
		dir="$(dirname "$dir")"
	done
}

remove_manifested_dotfiles() {
	local manifest pending_manifest kind path expected_hash current_hash
	manifest="$(dotfiles_manifest_file)"

	if [[ ! -f "$manifest" ]]; then
		print_warn "未找到 Dotfiles 托管清单，跳过托管文件删除"
		return 0
	fi

	pending_manifest=$(mktemp)
	: >"$pending_manifest"

	while IFS=$'\t' read -r kind path expected_hash; do
		[[ "$kind" == "file" && -n "$path" && -n "$expected_hash" ]] || continue
		[[ "$path" == "$HOME/.claude/settings.json" ]] && continue
		[[ "$path" == "$HOME/.claude.json" ]] && continue
		[[ -f "$path" ]] || continue

		current_hash=$(file_fingerprint "$path" 2>/dev/null || true)
		if [[ "$current_hash" != "$expected_hash" ]]; then
			print_warn "保留已修改文件: $path"
			printf 'file\t%s\t%s\n' "$path" "$expected_hash" >>"$pending_manifest"
			continue
		fi

		rm_path "$path"
		prune_empty_parents "$(dirname "$path")"
	done <"$manifest"

	if [[ -s "$pending_manifest" ]]; then
		chmod 600 "$pending_manifest"
		mv "$pending_manifest" "$manifest"
	else
		rm -f "$pending_manifest"
		rm_path "$manifest"
	fi
}

bb_browser_state_value() {
	local state_file="$1" key="$2" raw value

	[[ -f "$state_file" ]] || return 0

	raw="$(
		awk -v key="$key" -F= '
			$1 == key {
				sub(/^[^=]*=/, "", $0)
				print
				exit
			}
		' "$state_file"
	)"

	[[ -n "$raw" ]] || return 0

	if command -v python3 &>/dev/null; then
		value="$(
			python3 - "$raw" <<'PY'
import shlex
import sys

raw = sys.argv[1]
try:
    parts = shlex.split(raw)
    print(parts[0] if parts else "")
except Exception:
    print(raw)
PY
		)"
	else
		value="$raw"
	fi

	printf '%s\n' "$value"
}

remove_bb_browser() {
	local state_file config_file wrapper_path preexisting_bb_browser real_bb_browser_path target_prefix
	state_file="$(bb_browser_state_file)"
	config_file="$(bb_browser_config_file)"
	wrapper_path="$HOME/.local/bin/bb-browser-user"

	rm_path "$wrapper_path"
	prune_empty_parents "$(dirname "$wrapper_path")"
	rm_path "$config_file"
	prune_empty_parents "$(dirname "$config_file")"

	if [[ -f "$state_file" ]]; then
		preexisting_bb_browser="$(bb_browser_state_value "$state_file" PREEXISTING_BB_BROWSER)"
		real_bb_browser_path="$(bb_browser_state_value "$state_file" REAL_BB_BROWSER_PATH)"
		if [[ "$preexisting_bb_browser" == "0" && -n "$real_bb_browser_path" ]]; then
			target_prefix="$(dirname "$(dirname "$real_bb_browser_path")")"
			if [[ -n "$target_prefix" && "$target_prefix" != "/" ]]; then
				if command -v npm &>/dev/null; then
					npm --prefix "$target_prefix" uninstall -g bb-browser >/dev/null 2>&1 || true
				fi
			fi
		fi
	fi

	rm_path "$state_file"
	prune_empty_parents "$(dirname "$state_file")"
}

remove_dotfiles_ssh_include_block() {
	local ssh_config="$HOME/.ssh/config"
	local start_marker end_marker tmp
	start_marker="$(dotfiles_ssh_include_block_start)"
	end_marker="$(dotfiles_ssh_include_block_end)"

	[[ -f "$ssh_config" ]] || return 0
	grep -qF "$start_marker" "$ssh_config" || return 0

	tmp=$(mktemp)
	awk -v start="$start_marker" -v end="$end_marker" '
		$0 == start { skip = 1; next }
		$0 == end { skip = 0; next }
		!skip { print }
	' "$ssh_config" >"$tmp"

	if grep -q '[^[:space:]]' "$tmp"; then
		mv "$tmp" "$ssh_config"
		chmod 600 "$ssh_config"
	else
		rm -f "$tmp"
		rm_path "$ssh_config"
		prune_empty_parents "$(dirname "$ssh_config")"
	fi

	print_dim "✓ 已清理 ~/.ssh/config 中的 Dotfiles Include 块"
}

remove_dotfiles_superpowers() {
	local state_file clone_dir link_dir repo_url
	local preserve_clone=false preserve_link=false
	state_file="$(superpowers_state_file)"
	clone_dir="$HOME/.codex/superpowers"
	link_dir="$HOME/.agents/skills/superpowers"
	repo_url="https://github.com/obra/superpowers.git"

	if [[ -f "$state_file" ]]; then
		# shellcheck disable=SC1090
		source "$state_file"
		clone_dir="${SUPERPOWERS_CLONE_DIR:-$clone_dir}"
		link_dir="${SUPERPOWERS_LINK_DIR:-$link_dir}"
		repo_url="${SUPERPOWERS_REPO_URL:-$repo_url}"
	fi

	if [[ -L "$link_dir" ]]; then
		local target
		target=$(readlink "$link_dir" 2>/dev/null || true)
		if [[ "$target" == "$clone_dir/skills" ]]; then
			rm_path "$link_dir"
			prune_empty_parents "$(dirname "$link_dir")"
		else
			preserve_link=true
			print_warn "保留 superpowers skills 链接（目标不匹配）: $link_dir"
		fi
	elif [[ -e "$link_dir" ]]; then
		preserve_link=true
		print_warn "保留 superpowers skills 路径（非符号链接）: $link_dir"
	fi

	if [[ -d "$clone_dir/.git" ]]; then
		local origin status_output normalized_origin normalized_repo_url
		origin=$(git -C "$clone_dir" remote get-url origin 2>/dev/null || true)
		status_output=$(git -C "$clone_dir" status --porcelain 2>/dev/null || true)
		normalized_origin=$(normalize_git_remote "$origin" 2>/dev/null || true)
		normalized_repo_url=$(normalize_git_remote "$repo_url" 2>/dev/null || true)
		if [[ -n "$origin" && "$normalized_origin" != "$normalized_repo_url" ]]; then
			preserve_clone=true
			print_warn "保留 superpowers 仓库（origin 不匹配）: $clone_dir"
		elif [[ -n "$status_output" ]]; then
			preserve_clone=true
			print_warn "保留已修改的 superpowers 仓库: $clone_dir"
		else
			rm_path "$clone_dir"
			prune_empty_parents "$(dirname "$clone_dir")"
		fi
	elif [[ -e "$clone_dir" ]]; then
		preserve_clone=true
		print_warn "保留 superpowers 路径（非 Git 仓库）: $clone_dir"
	fi

	if [[ "$preserve_clone" == false && "$preserve_link" == false ]]; then
		rm_path "$state_file"
		prune_empty_parents "$(dirname "$state_file")"
	fi
}

remove_pixi() {
	print_info "🧹 删除 Pixi 及其安装的所有工具..."

	# 显示将要删除的包（如果 pixi 存在）
	if command -v pixi &>/dev/null; then
		print_dim "已安装的工具环境:"
		# 使用 Home 项目模式查看已安装的工具
		(cd "$HOME" && _run_and_log pixi list --explicit 2>/dev/null) || true
	fi

	# 删除 pixi 主目录（包含 bin、envs、manifests）
	# ~/.pixi/bin - pixi 本身和所有 exposed 的命令
	# ~/.pixi/envs - 所有安装的环境和包
	rm_path ~/.pixi

	# 删除 pixi/rattler 缓存和数据目录（包下载缓存在这里）
	for p in ~/.cache/pixi ~/.cache/rattler ~/.local/share/pixi ~/.local/state/pixi ~/.rattler; do
		rm_path "$p"
	done

	# 如果设置了 XDG_CACHE_HOME，也检查那里
	if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
		rm_path "$XDG_CACHE_HOME/rattler"
		rm_path "$XDG_CACHE_HOME/pixi"
	fi

	# 清理 shell 配置文件中的 Pixi PATH
	for rc_file in ~/.zshrc ~/.bashrc; do
		if [[ -f "$rc_file" ]] && grep -q '\.pixi/bin' "$rc_file" 2>/dev/null; then
			# macOS 用 sed -i ''，Linux 用 sed -i
			if [[ "$(uname -s)" == "Darwin" ]]; then
				sed -i '' '/# Pixi: 添加到 PATH/d' "$rc_file"
				sed -i '' '/\.pixi\/bin/d' "$rc_file"
			else
				sed -i '/# Pixi: 添加到 PATH/d' "$rc_file"
				sed -i '/\.pixi\/bin/d' "$rc_file"
			fi
			print_dim "✓ 已清理 $rc_file 中的 Pixi PATH"
		fi
	done

	# 删除 pixi 项目配置文件
	local manifest_path lock_path manifest_state
	manifest_path="$(pixi_manifest_path)"
	lock_path="$(pixi_lock_path)"
	manifest_state="$(pixi_manifest_state_file)"

	if [[ -f "$manifest_state" ]]; then
		if [[ ! -f "$manifest_path" ]] || pixi_manifest_is_managed "$manifest_path"; then
			rm_path "$manifest_path"
			rm_path "$lock_path"
			rm_path "$manifest_state"
			print_dim "✓ 已删除 Dotfiles 托管的 pixi manifest"
		else
			print_warn "检测到已脱管的 ~/pixi.toml，保留 ~/pixi.toml 和 ~/pixi.lock"
			rm_path "$manifest_state"
		fi
	elif [[ -f "$manifest_path" || -f "$lock_path" ]]; then
		print_warn "检测到用户自维护的 ~/pixi.toml，保留 ~/pixi.toml 和 ~/pixi.lock"
	fi

	print_success "Pixi 及所有工具已删除"
}

remove_claude() {
	print_info "🤖 删除 Claude Code 用户配置（仅限 Dotfiles 管理的 Claude 项）..."

	# 1) study-master Skill + Hooks
	rm_path ~/.claude/skills/study-master
	rm_path ~/.claude/hooks/check-study_master.sh

	# 清理 settings.json 中的 Dotfiles 管理项，避免误删用户自定义配置
	local settings_file="$HOME/.claude/settings.json"
	if [[ -f "$settings_file" ]] && command -v jq &>/dev/null; then
		local hook_cmd='bash "$HOME/.claude/hooks/check-study_master.sh"'
		local managed_plugins_json
		managed_plugins_json=$(printf '%s\n' "${CLAUDE_MANAGED_PLUGINS[@]}" | jq -R . | jq -s .)
		jq --arg cmd "$hook_cmd" --argjson managed_plugins "$managed_plugins_json" '
			if .hooks.PostToolUse then
				.hooks.PostToolUse |= map(
					.hooks |= map(select(.command != $cmd))
				) |
				.hooks.PostToolUse |= map(select(.hooks | length > 0)) |
				if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end |
				if (.hooks | length) == 0 then del(.hooks) else . end
			else . end |
			if (.enabledPlugins | type) == "object" then
				.enabledPlugins |= with_entries(select(.key as $k | $managed_plugins | index($k) | not)) |
				if (.enabledPlugins | length) == 0 then del(.enabledPlugins) else . end
			else . end |
			if (.statusLine?.type == "command") and (
				(.statusLine.command // "") | test("claude-hud/claude-hud|claude-hud/hud-wrapper\\.sh|\\.claude/statusline\\.sh")
			) then
				del(.statusLine)
			else . end
		' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
		print_dim "✓ 已定向清理 settings.json 中的 Dotfiles 管理项"
	fi

	# 2) 实际卸载 Dotfiles 安装的 Claude 插件和 Marketplace
	if command -v claude &>/dev/null; then
		local plugin
		for plugin in "${CLAUDE_MANAGED_PLUGINS[@]}"; do
			claude plugin uninstall "$plugin" &>/dev/null && print_dim "✓ 插件: $plugin 已卸载"
		done

		local marketplace
		for marketplace in "${CLAUDE_MANAGED_MARKETPLACES[@]}"; do
			claude plugin marketplace remove "$marketplace" &>/dev/null && print_dim "✓ Marketplace: $marketplace 已移除"
		done
	fi

	# 3) claude-hud 配置及旧版 wrapper 脚本
	rm_path ~/.claude/plugins/claude-hud/config.json
	rm_path ~/.claude/plugins/claude-hud/hud-wrapper.sh
	rm_path ~/.claude/plugins/claude-hud/hud-proxy.mjs

	# 3) 旧 statusline.sh
	rm_path ~/.claude/statusline.sh

	# 4) MCP Servers（通过 claude CLI 定向移除 Dotfiles 安装的项）
	if command -v claude &>/dev/null; then
		local mcp_list
		mcp_list=$(claude mcp list 2>/dev/null) || true
		local mcp
		for mcp in "${CLAUDE_MANAGED_MCPS[@]}"; do
			if echo "$mcp_list" | grep -Eq "^[[:space:]]*${mcp}:"; then
				claude mcp remove "$mcp" --scope user &>/dev/null && print_dim "✓ MCP: $mcp 已移除"
			fi
		done
	fi

	print_success "Claude Code 配置已清理"
	print_dim "💡 Claude Code CLI 本身未卸载，如需卸载请运行: npm uninstall -g @anthropic-ai/claude-code"
	print_dim "💡 共享语言工具链（LSP / Kotlin/Native / npm/go/dotnet 全局工具）已保留，避免影响其它编辑器和工作流"
}

remove_dotfiles() {
	print_info "🗑️ 删除 Dotfiles..."

	remove_dotfiles_superpowers
	remove_bb_browser
	remove_manifested_dotfiles
	remove_dotfiles_ssh_include_block

	# macOS 专属清理
	if [[ "$(uname -s)" == "Darwin" ]]; then
		local brew_maintenance_plist="$HOME/Library/LaunchAgents/com.dotfiles.brew-maintenance.plist"
		local brew_maintenance_script="$HOME/Library/Application Support/com.dotfiles/brew-maintenance.sh"
		local legacy_brew_cleanup_plist="$HOME/Library/LaunchAgents/com.dotfiles.brew-cleanup.plist"
		local legacy_brew_autoupdate_plist="$HOME/Library/LaunchAgents/com.github.domt4.homebrew-autoupdate.plist"
		local removed_legacy_autoupdate=false
		# 恢复安装前保存的电源管理配置
		if [[ -f "$(pmset_state_file)" ]]; then
			if restore_pmset_state; then
				rm_path "$(pmset_state_file)"
			else
				print_warn "检测到 pmset 备份，但未能恢复（可能缺少 sudo 权限）"
			fi
		elif command -v pmset &>/dev/null && pmset -g | awk '/^ sleep/ {print $2}' | grep -q '^0$'; then
			print_warn "未找到 pmset 备份，跳过恢复"
		fi
		if [[ -f "$brew_maintenance_plist" ]]; then
			launchctl unload "$brew_maintenance_plist" &>/dev/null || true
			rm_path "$brew_maintenance_plist"
			print_dim "✓ Homebrew 自动维护 LaunchAgent 已移除"
		fi
		if [[ -f "$brew_maintenance_script" ]]; then
			rm_path "$brew_maintenance_script"
			print_dim "✓ Homebrew 自动维护脚本已移除"
		fi
		# 停止旧版 Homebrew autoupdate
		if command -v brew &>/dev/null && brew commands 2>/dev/null | grep -q autoupdate; then
			if brew autoupdate delete &>/dev/null; then
				print_dim "✓ Homebrew autoupdate 已停止并删除"
				removed_legacy_autoupdate=true
			fi
		fi
		if [[ "$removed_legacy_autoupdate" == false && -f "$legacy_brew_autoupdate_plist" ]]; then
			launchctl unload "$legacy_brew_autoupdate_plist" &>/dev/null || true
			rm_path "$legacy_brew_autoupdate_plist"
			print_dim "✓ 旧版 Homebrew autoupdate LaunchAgent 已移除"
		fi
		if [[ -f "$legacy_brew_cleanup_plist" ]]; then
			launchctl unload "$legacy_brew_cleanup_plist" &>/dev/null || true
			rm_path "$legacy_brew_cleanup_plist"
			print_dim "✓ Homebrew cleanup LaunchAgent 已移除"
		fi
		# 从 access_bpf 组移除用户
		if has_sudo && dscl . -read /Groups/access_bpf GroupMembership 2>/dev/null | grep -qw "$(whoami)"; then
			sudo dseditgroup -o edit -d "$(whoami)" -t user access_bpf 2>/dev/null && print_dim "✓ 已从 access_bpf 组移除"
		fi
		# Homebrew 包可能被其他软件依赖，不自动卸载，仅提示
		if command -v brew &>/dev/null; then
			print_dim "💡 Homebrew 包未自动卸载（可能被其他软件依赖）"
			print_dim "   如需卸载，请参考 lib/packages.sh 中的包列表手动执行 brew uninstall"
		fi
	fi

	print_dim "💡 Zinit、p10k、zsh 缓存等运行时目录已保留；如需清理请手动删除对应缓存目录"
}

# 解析参数
while (($#)); do
	case "$1" in
	--pixi) REMOVE_PIXI=true ;;
	--dotfiles) REMOVE_DOTFILES=true ;;
	--claude) REMOVE_CLAUDE=true ;;
	--all)
		REMOVE_PIXI=true
		REMOVE_DOTFILES=true
		REMOVE_CLAUDE=true
		;;
	-f | --force) FORCE=true ;;
	-h | --help)
		show_help
		exit 0
		;;
	*)
		print_error "未知选项: $1"
		exit 1
		;;
	esac
	shift
done

# 初始化日志
setup_logging

# 交互菜单
if [[ "$REMOVE_PIXI" == "false" && "$REMOVE_DOTFILES" == "false" && "$REMOVE_CLAUDE" == "false" ]]; then
	echo -e "\n请选择:\n  1) Pixi\n  2) Dotfiles\n  3) Claude Code\n  4) 全部\n  5) 退出"
	read -r -p "输入 1-5: " c
	case "$c" in
	1) REMOVE_PIXI=true ;;
	2) REMOVE_DOTFILES=true ;;
	3) REMOVE_CLAUDE=true ;;
	4)
		REMOVE_PIXI=true
		REMOVE_DOTFILES=true
		REMOVE_CLAUDE=true
		;;
	5) exit 0 ;;
	*) print_error "无效选项: $c"; exit 1 ;;
	esac
fi

# 执行删除
[[ "$REMOVE_PIXI" == "true" ]] && confirm "确认删除 Pixi?" && remove_pixi
[[ "$REMOVE_DOTFILES" == "true" ]] && confirm "确认删除 Dotfiles?" && remove_dotfiles
[[ "$REMOVE_CLAUDE" == "true" ]] && confirm "确认删除 Claude Code 配置?" && remove_claude

_echo_blank
print_success "卸载完成！"
print_dim "📝 日志: $DOTFILES_LOG"
