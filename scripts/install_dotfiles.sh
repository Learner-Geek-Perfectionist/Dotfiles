#!/bin/bash
# Dotfiles 配置安装脚本
# 只同步明确列出的文件/目录，避免覆盖用户的其它配置

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/../lib/utils.sh"

# 检测是否安装了 VSCode
has_vscode() {
	command -v code &>/dev/null && code --help 2>&1 | head -1 | grep -qi "code"
}

# 检测是否安装了 Cursor
has_cursor() {
	command -v cursor &>/dev/null && cursor --help 2>&1 | head -1 | grep -qi "cursor"
}

# 检测是否在远程服务器环境（VSCode/Cursor Remote SSH）
is_remote_server() {
	[[ -n "$VSCODE_IPC_HOOK_CLI" ]] && [[ -n "$SSH_CONNECTION" ]]
}

copy_path() {
	local src="$DOTFILES_DIR/$1"
	local dest="$HOME/$2"

	[[ ! -e "$src" ]] && return 0

	if [[ -d "$src" ]]; then
		mkdir -p "$dest"
		cp -rf "$src/." "$dest/"
	else
		mkdir -p "$(dirname "$dest")"
		cp -f "$src" "$dest"
	fi

	print_success "~/$2"
}

main() {
	print_info "📁 Dotfiles 配置安装"

	# 点文件
	copy_path ".zshrc" ".zshrc"
	copy_path ".zprofile" ".zprofile"
	copy_path ".zshenv" ".zshenv"
	copy_path ".envrc" ".envrc"

	# .config 子目录（通用）
	copy_path ".config/zsh" ".config/zsh"
	copy_path ".config/kitty" ".config/kitty"
	copy_path ".config/ripgrep" ".config/ripgrep"

	# direnv 配置（替换 __HOME__ 为实际路径）
	if [[ -f "$DOTFILES_DIR/.config/direnv/direnv.toml" ]]; then
		mkdir -p "$HOME/.config/direnv"
		sed "s|__HOME__|$HOME|g" "$DOTFILES_DIR/.config/direnv/direnv.toml" > "$HOME/.config/direnv/direnv.toml"
		print_success "~/.config/direnv/direnv.toml"
	fi

	# VSCode/Cursor 配置（只复制 settings.json 和 keybindings.json，避免覆盖用户的其它配置）
	if [[ "$(uname)" == "Darwin" ]]; then
		# macOS: ~/Library/Application Support/
		has_vscode && copy_path "Library/Application Support/Code/User/settings.json" "Library/Application Support/Code/User/settings.json"
		has_vscode && copy_path "Library/Application Support/Code/User/keybindings.json" "Library/Application Support/Code/User/keybindings.json"
		has_cursor && copy_path "Library/Application Support/Cursor/User/settings.json" "Library/Application Support/Cursor/User/settings.json"
		has_cursor && copy_path "Library/Application Support/Cursor/User/keybindings.json" "Library/Application Support/Cursor/User/keybindings.json"
		# macOS 专属
		copy_path ".config/karabiner" ".config/karabiner"
		copy_path ".hammerspoon" ".hammerspoon"
	else
		# Linux: ~/.config/
		if is_remote_server; then
			print_info "检测到远程服务器环境，跳过 VSCode/Cursor 设置（设置从本地自动同步）"
		else
			has_vscode && copy_path ".config/Code/User/settings.json" ".config/Code/User/settings.json"
			has_vscode && copy_path ".config/Code/User/keybindings.json" ".config/Code/User/keybindings.json"
			has_cursor && copy_path ".config/Cursor/User/settings.json" ".config/Cursor/User/settings.json"
			has_cursor && copy_path ".config/Cursor/User/keybindings.json" ".config/Cursor/User/keybindings.json"
		fi
	fi

	# Git 配置
	copy_path ".gitconfig" ".gitconfig"
	copy_path ".gitignore" ".gitignore"

	# Claude Code 配置
	# settings.json 使用 jq 合并：静态设置覆盖，动态字段（插件等）保留
	local claude_src="$DOTFILES_DIR/.claude/settings.json"
	local claude_dest="$HOME/.claude/settings.json"
	if [[ -f "$claude_src" ]]; then
		mkdir -p "$HOME/.claude"
		if [[ -f "$claude_dest" ]] && command -v jq &>/dev/null; then
			local tmp_merged
			tmp_merged=$(mktemp)
			if jq -s '.[0] * .[1]' "$claude_dest" "$claude_src" >"$tmp_merged" 2>/dev/null; then
				mv "$tmp_merged" "$claude_dest"
			else
				rm -f "$tmp_merged"
				cp -f "$claude_src" "$claude_dest"
			fi
		else
			cp -f "$claude_src" "$claude_dest"
		fi
		print_success "~/.claude/settings.json"
	fi
	copy_path ".claude/statusline.sh" ".claude/statusline.sh"

	# 其它文件
	copy_path ".ssh/config" ".ssh/config"
	# Linux: 安装 keychain（SSH agent 管理器，纯 shell 脚本）
	if [[ "$(uname)" != "Darwin" ]] && ! command -v keychain &>/dev/null; then
		mkdir -p "$HOME/.local/bin"
		if curl -fsSL "https://github.com/funtoo/keychain/raw/master/keychain.sh" -o "$HOME/.local/bin/keychain"; then
			chmod +x "$HOME/.local/bin/keychain"
			print_success "keychain (SSH agent manager)"
		else
			print_warn "keychain 下载失败，SSH agent 需手动管理"
		fi
	fi
	# pixi.toml 由 install.sh 的 sync_pixi_tools() 统一部署，避免重复
	copy_path "sh-script" "sh-script"

	# 权限
	[[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh" && find "$HOME/.ssh" -maxdepth 1 -type f -exec chmod 600 {} + 2>/dev/null
	[[ -f "$HOME/.config/zsh/fzf/fzf-preview.sh" ]] && chmod +x "$HOME/.config/zsh/fzf/fzf-preview.sh"
	[[ -d "$HOME/sh-script" ]] && chmod +x "$HOME/sh-script"/*.sh 2>/dev/null
	[[ -f "$HOME/.claude/statusline.sh" ]] && chmod +x "$HOME/.claude/statusline.sh"

	# 安装 zinit 插件
	_echo_blank
	print_info "🔌 安装 Zinit 插件..."
	if command -v zsh &>/dev/null; then
		# ZINIT_SYNC=1 同步加载，确保所有插件安装完成再退出
		if _run_and_log zsh -c "ZINIT_SYNC=1 source '$HOME/.zshrc'"; then
			print_success "Zinit 插件安装完成"
		fi
	else
		print_warn "未找到 zsh，跳过 zinit 插件安装"
	fi
}

main
