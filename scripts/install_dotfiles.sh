#!/bin/bash
# Dotfiles 配置安装脚本
# 只同步明确列出的文件/目录，避免覆盖用户的其它配置

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/../lib/utils.sh"

COPY_SUMMARY=()

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
	local summary_msg=""

	[[ ! -e "$src" ]] && return 0

	if [[ -d "$src" ]]; then
		mkdir -p "$dest"
		cp -rf "$src/." "$dest/"
		summary_msg="📁 $1 → ~/$2"
	else
		mkdir -p "$(dirname "$dest")"
		cp -f "$src" "$dest"
		summary_msg="📄 $1 → ~/$2"
	fi
	COPY_SUMMARY+=("$summary_msg")

	print_success "$2"
}

main() {
	print_header "📁 Dotfiles 配置安装："
	echo ""

	# 点文件
	copy_path ".zshrc" ".zshrc"
	copy_path ".zprofile" ".zprofile"
	copy_path ".zshenv" ".zshenv"

	# .config 子目录（通用）
	copy_path ".config/zsh" ".config/zsh"
	copy_path ".config/kitty" ".config/kitty"

	# VSCode/Cursor 配置（只复制 settings.json，避免覆盖用户的其它配置）
	if [[ "$(uname)" == "Darwin" ]]; then
		# macOS: ~/Library/Application Support/
		has_vscode && copy_path "Library/Application Support/Code/User/settings.json" "Library/Application Support/Code/User/settings.json"
		has_cursor && copy_path "Library/Application Support/Cursor/User/settings.json" "Library/Application Support/Cursor/User/settings.json"
		# macOS 专属
		copy_path ".config/karabiner" ".config/karabiner"
		copy_path ".hammerspoon" ".hammerspoon"
	else
		# Linux: ~/.config/
		if is_remote_server; then
			print_info "检测到远程服务器环境，跳过 VSCode/Cursor 设置（设置从本地自动同步）"
		else
			has_vscode && copy_path ".config/Code/User/settings.json" ".config/Code/User/settings.json"
			has_cursor && copy_path ".config/Cursor/User/settings.json" ".config/Cursor/User/settings.json"
		fi
	fi

	# 其它目录
	copy_path ".ssh/config" ".ssh/config"
	copy_path ".pixi/manifests" ".pixi/manifests"

	if ((${#COPY_SUMMARY[@]} > 0)); then
		echo ""
		print_header "🧾 文件复制详情："
		echo ""
		for msg in "${COPY_SUMMARY[@]}"; do
			print_info "➜ $msg"
		done
	fi

	# 权限
	[[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh" && chmod 600 "$HOME/.ssh"/* 2>/dev/null
	[[ -f "$HOME/.config/zsh/fzf/fzf-preview.sh" ]] && chmod +x "$HOME/.config/zsh/fzf/fzf-preview.sh"

	# 安装 zinit 插件
	echo ""
	print_header "🔌 安装 Zinit 插件："
	echo ""
	if command -v zsh &>/dev/null; then
		print_info "正在安装 zinit 插件..."
		# ZINIT_SYNC=1 同步加载，确保所有插件安装完成再退出
		_run_and_log zsh -c "ZINIT_SYNC=1 source '$HOME/.zshrc'"
		print_success "Zinit 插件安装完成"
		print_success "安装完成！请运行: source ~/.zshrc"
	else
		print_warn "未找到 zsh，跳过 zinit 插件安装"
		print_success "安装完成！请先安装 zsh 后运行: source ~/.zshrc"
	fi
}

main
