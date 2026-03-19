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
	[[ -z "$p" || "$p" == "/" ]] && return
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
	rm_path ~/pixi.toml
	rm_path ~/pixi.lock

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

	# 2) claude-hud 配置
	rm_path ~/.claude/plugins/claude-hud/config.json

	# 3) 旧 statusline.sh
	rm_path ~/.claude/statusline.sh

	# 4) LSP Servers（由 install_claude_code.sh 安装）
	rm_path ~/.local/share/lsp
	for bin in rust-analyzer kotlin-language-server lua-language-server jdtls; do
		rm_path ~/.local/bin/"$bin"
	done

	# 5) MCP Servers（通过 claude CLI 移除）
	if command -v claude &>/dev/null; then
		for mcp in tavily fetch open-websearch; do
			if claude mcp list 2>/dev/null | grep -q "^  $mcp:"; then
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
	for p in ~/.config/{zsh,kitty}; do
		rm_path "$p"
	done

	# Git 配置
	rm_path ~/.gitconfig
	rm_path ~/.gitignore

	# SSH 配置
	rm_path ~/.ssh/config

	# 工具脚本
	rm_path ~/sh-script

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

	# 根据操作系统区分 VSCode/Cursor 配置路径
	# 删除 settings.json 和 keybindings.json
	if [[ "$(uname -s)" == "Darwin" ]]; then
		# macOS: Library 路径 + macOS 专属工具
		for p in ~/"Library/Application Support"/{Code,Cursor}/User/{settings.json,keybindings.json}; do
			rm_path "$p"
		done
		# macOS 专属工具
		for p in ~/.config/karabiner ~/.hammerspoon; do
			rm_path "$p"
		done
		# 停止 Homebrew autoupdate
		if command -v brew &>/dev/null && brew commands 2>/dev/null | grep -q autoupdate; then
			brew autoupdate delete &>/dev/null && print_dim "✓ Homebrew autoupdate 已停止并删除"
		fi
	else
		# Linux: .config 路径
		for p in ~/.config/{Code,Cursor}/User/{settings.json,keybindings.json}; do
			rm_path "$p"
		done
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
	*) exit 0 ;;
	esac
fi

# 执行删除
[[ "$REMOVE_PIXI" == "true" ]] && confirm "确认删除 Pixi?" && remove_pixi
[[ "$REMOVE_DOTFILES" == "true" ]] && confirm "确认删除 Dotfiles?" && remove_dotfiles
[[ "$REMOVE_CLAUDE" == "true" ]] && confirm "确认删除 Claude Code 配置?" && remove_claude

_echo_blank
print_success "卸载完成！"
print_dim "📝 日志: $DOTFILES_LOG"
