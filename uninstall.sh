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

show_help() {
	cat <<'EOF'
用法: ./uninstall.sh [选项]

选项:
    --pixi       仅删除 Pixi (~/.pixi 等)
    --dotfiles   仅删除 Dotfiles 配置
    --claude     仅删除 Claude Code 配置（插件/Skill/Hook/LSP/MCP）
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
	print_info "🤖 删除 Claude Code 配置（由 install_claude_code.sh 安装的内容）..."

	# 1) study-master Skill + Hooks
	rm_path ~/.claude/skills/study-master
	rm_path ~/.claude/hooks/check-study_master.sh

	# 清理 settings.json 中的 study-master hooks
	local settings_file="$HOME/.claude/settings.json"
	if [[ -f "$settings_file" ]] && command -v jq &>/dev/null; then
		local hook_cmd='bash "$HOME/.claude/hooks/check-study_master.sh"'
		jq --arg cmd "$hook_cmd" '
			if .hooks.PostToolUse then
				.hooks.PostToolUse |= map(
					.hooks |= map(select(.command != $cmd))
				) |
				.hooks.PostToolUse |= map(select(.hooks | length > 0)) |
				if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end |
				if (.hooks | length) == 0 then del(.hooks) else . end
			else . end
		' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
		print_dim "✓ 已清理 settings.json 中的 hooks"

		# 清理 enabledPlugins
		jq 'del(.enabledPlugins)' "$settings_file" > "$settings_file.tmp" && \
			mv "$settings_file.tmp" "$settings_file"
		print_dim "✓ 已清理 settings.json 中的 enabledPlugins"

		# 清理 extraKnownMarketplaces
		jq 'del(.extraKnownMarketplaces)' "$settings_file" > "$settings_file.tmp" && \
			mv "$settings_file.tmp" "$settings_file"
		print_dim "✓ 已清理 settings.json 中的 extraKnownMarketplaces"

		# 清理 statusLine
		jq 'del(.statusLine)' "$settings_file" > "$settings_file.tmp" && \
			mv "$settings_file.tmp" "$settings_file"
		print_dim "✓ 已清理 settings.json 中的 statusLine"
	fi

	# 2) 实际卸载已安装的 Claude 插件和 Marketplace
	if command -v claude &>/dev/null; then
		# 卸载插件
		local plugin_list
		plugin_list=$(claude plugin list 2>/dev/null) || true
		if [[ -n "$plugin_list" ]]; then
			echo "$plugin_list" | sed -n 's/^.*❯ //p' | while IFS= read -r plugin; do
				[[ -n "$plugin" ]] && claude plugin uninstall "$plugin" &>/dev/null && print_dim "✓ 插件: $plugin 已卸载"
			done
		fi
		# 移除 Marketplace
		local marketplace_list
		marketplace_list=$(claude plugin marketplace list 2>/dev/null) || true
		if [[ -n "$marketplace_list" ]]; then
			echo "$marketplace_list" | sed -n 's/^.*❯ //p' | while IFS= read -r mp; do
				[[ -n "$mp" ]] && claude plugin marketplace remove "$mp" &>/dev/null && print_dim "✓ Marketplace: $mp 已移除"
			done
		fi
	fi

	# 3) claude-hud 配置及旧版 wrapper 脚本
	rm_path ~/.claude/plugins/claude-hud/config.json
	rm_path ~/.claude/plugins/claude-hud/hud-wrapper.sh
	rm_path ~/.claude/plugins/claude-hud/hud-proxy.mjs

	# 3) 旧 statusline.sh
	rm_path ~/.claude/statusline.sh

	# 4) LSP Servers（由 install_claude_code.sh 安装）
	rm_path ~/.local/share/lsp
	for bin in rust-analyzer kotlin-language-server lua-language-server jdtls; do
		rm_path ~/.local/bin/"$bin"
	done

	# 5) Kotlin/Native（由 install_kotlin_native.sh 安装）
	rm_path ~/.local/share/kotlin-native
	for bin in konanc cinterop klib; do
		rm_path ~/.local/bin/"$bin"
	done

	# 6) npm 全局安装的 LSP servers
	if command -v npm &>/dev/null; then
		for pkg in typescript-language-server typescript intelephense; do
			if npm ls -g "$pkg" &>/dev/null; then
				npm uninstall -g "$pkg" &>/dev/null && print_dim "✓ npm: $pkg 已卸载"
			fi
		done
	fi

	# 7) Go 安装的 LSP（gopls）
	if command -v go &>/dev/null; then
		local gopath
		gopath="$(go env GOPATH 2>/dev/null)"
		[[ -n "$gopath" ]] && rm_path "$gopath/bin/gopls"
	fi

	# 8) dotnet 安装的 LSP（csharp-ls）
	if command -v dotnet &>/dev/null; then
		dotnet tool uninstall -g csharp-ls &>/dev/null && print_dim "✓ dotnet: csharp-ls 已卸载"
	fi

	# 9) MCP Servers（通过 claude CLI 移除）
	if command -v claude &>/dev/null; then
		local mcp_list
		mcp_list=$(claude mcp list 2>/dev/null) || true
		for mcp in tavily fetch open-websearch exa; do
			if echo "$mcp_list" | grep -Eq "^[[:space:]]*${mcp}:"; then
				claude mcp remove "$mcp" --scope user &>/dev/null && print_dim "✓ MCP: $mcp 已移除"
			fi
		done
	fi

	print_success "Claude Code 配置已清理"
	print_dim "💡 Claude Code CLI 本身未卸载，如需卸载请运行: npm uninstall -g @anthropic-ai/claude-code"
}

remove_dotfiles() {
	print_info "🗑️ 删除 Dotfiles..."

	# Zsh 配置
	for p in ~/.zshrc ~/.zprofile ~/.zshenv; do
		rm_path "$p"
	done

	# direnv 配置
	rm_path ~/.envrc
	rm_path ~/.config/direnv

	# .config 目录下的配置
	for p in ~/.config/{zsh,kitty,ripgrep}; do
		rm_path "$p"
	done

	# Git 配置
	rm_path ~/.gitconfig
	rm_path ~/.gitignore

	# SSH 配置（只移除 dotfiles 部分，保留机器本地配置）
	rm_path ~/.ssh/config.d/00-dotfiles

	# 工具脚本
	rm_path ~/sh-script

	# Linux keychain（由 install_dotfiles.sh 安装）
	rm_path ~/.local/bin/keychain

	# 删除 zinit 相关目录（插件、补全、缓存等）
	for p in ~/.local/share/zinit ~/.cache/zinit; do
		rm_path "$p"
	done

	# 删除 p10k 缓存
	for p in ~/.cache/p10k-instant-prompt-*.zsh; do
		[[ -e "$p" ]] && rm -f "$p" && print_success "已删除: $p"
	done

	# 删除 ~/.cache/zsh 目录（但保留 .zsh_history）
	if [[ -d ~/.cache/zsh ]]; then
		print_dim "清理 ~/.cache/zsh（保留历史记录）"
		# 备份 history 文件
		local history_file=~/.cache/zsh/.zsh_history
		local history_backup=""
		if [[ -f "$history_file" ]]; then
			history_backup=$(mktemp)
			cp "$history_file" "$history_backup"
		fi
		# 删除整个目录
		rm -rf ~/.cache/zsh
		# 恢复 history 文件
		if [[ -n "$history_backup" && -f "$history_backup" ]]; then
			mkdir -p ~/.cache/zsh
			mv "$history_backup" "$history_file"
			print_dim "✓ 已保留: $history_file"
		fi
	fi

	# VSCode/Cursor 配置（路径数组抽出，删除逻辑只写一次）
	local vscode_dirs=()
	if [[ "$(uname -s)" == "Darwin" ]]; then
		vscode_dirs=(~/"Library/Application Support"/{Code,Cursor}/User)
	else
		vscode_dirs=(~/.config/{Code,Cursor}/User)
	fi
	for dir in "${vscode_dirs[@]}"; do
		for f in settings.json keybindings.json; do
			rm_path "$dir/$f"
		done
	done

	# macOS 专属清理
	if [[ "$(uname -s)" == "Darwin" ]]; then
		for p in ~/.config/karabiner ~/.hammerspoon; do
			rm_path "$p"
		done
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
		# 停止 Homebrew autoupdate
		if command -v brew &>/dev/null && brew commands 2>/dev/null | grep -q autoupdate; then
			brew autoupdate delete &>/dev/null && print_dim "✓ Homebrew autoupdate 已停止并删除"
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
