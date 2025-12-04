#!/bin/bash
# Dotfiles 配置安装脚本
# 只同步明确列出的文件/目录，避免覆盖用户的其它配置

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/../lib/utils.sh"

COPY_SUMMARY=()

# 检测是否在 VSCode/Cursor 远程服务器环境中
is_remote_server() {
	[[ -d "$HOME/.vscode-server" ]] || [[ -d "$HOME/.cursor-server" ]]
}

copy_path() {
	local src="$DOTFILES_DIR/$1"
	local dest="$HOME/$2"
	local summary_msg=""

	[[ ! -e "$src" ]] && return 0

	if [[ -d "$src" ]]; then
		mkdir -p "$dest"
		cp -Rf "$src/." "$dest/"
		summary_msg="目录同步: $src -> $dest（覆盖同名文件）"
	else
		mkdir -p "$(dirname "$dest")"
		cp -f "$src" "$dest"
		summary_msg="文件复制: $src -> $dest（覆盖同名文件）"
	fi
	COPY_SUMMARY+=("$summary_msg")

	print_success "  ✓ $2"
}

main() {
	print_header "📁 Dotfiles 配置安装"
	echo ""

	# 点文件
	copy_path ".zshrc" ".zshrc"
	copy_path ".zprofile" ".zprofile"
	copy_path ".zshenv" ".zshenv"

	# .config 子目录（通用）
	copy_path ".config/zsh" ".config/zsh"
	copy_path ".config/kitty" ".config/kitty"

	# VSCode/Cursor 配置（根据操作系统区分路径）
	if [[ "$(uname)" == "Darwin" ]]; then
		# macOS: ~/Library/Application Support/
		copy_path "Library/Application Support/Code/User" "Library/Application Support/Code/User"
		copy_path "Library/Application Support/Cursor/User" "Library/Application Support/Cursor/User"
		# macOS 专属
		copy_path ".config/karabiner" ".config/karabiner"
		copy_path ".hammerspoon" ".hammerspoon"
	elif is_remote_server; then
		# 远程服务器环境：设置从本地同步，存放在 ~/.cursor-server/data/User/，无需复制
		print_info "检测到远程服务器环境，跳过 VSCode/Cursor 设置（设置从本地自动同步）"
	else
		# Linux 本地环境: ~/.config/
		copy_path ".config/Code/User" ".config/Code/User"
		copy_path ".config/Cursor/User" ".config/Cursor/User"
	fi

	# 其它目录
	copy_path ".ssh/config" ".ssh/config"
	copy_path ".pixi/manifests" ".pixi/manifests"

	if ((${#COPY_SUMMARY[@]} > 0)); then
		print_header "🧾 文件复制详情"
		for msg in "${COPY_SUMMARY[@]}"; do
			print_info "  ➜ $msg"
		done
	fi

	# 权限
	[[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh" && chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
	[[ -f "$HOME/.config/zsh/fzf/fzf-preview.sh" ]] && chmod +x "$HOME/.config/zsh/fzf/fzf-preview.sh"

	# 安装 zinit 插件
	print_header "🔌 安装 Zinit 插件"
	if command -v zsh &>/dev/null; then
		# 使用 zsh 执行插件安装脚本
		zsh "$HOME/.config/zsh/plugins/zinit-plugin.zsh" && print_success "✓ Zinit 插件安装完成"
	else
		print_warn "⚠️ 未找到 zsh，跳过 zinit 插件安装"
	fi

	print_success "✅ 安装完成！请运行: source ~/.zshrc"
}

main
