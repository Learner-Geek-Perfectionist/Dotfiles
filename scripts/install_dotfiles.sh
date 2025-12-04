#!/bin/bash
# Dotfiles 配置安装脚本
# 只同步明确列出的文件/目录，避免覆盖用户的其它配置

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/../lib/utils.sh"

COPY_SUMMARY=()

# 检测远程服务器类型：cursor / vscode / 空（非远程）
get_remote_server_type() {
	if [[ -d "$HOME/.cursor-server" ]]; then
		echo "cursor"
	elif [[ -d "$HOME/.vscode-server" ]]; then
		echo "vscode"
	fi
}

# 检测是否安装了 VSCode（code --help 输出包含 code）
has_vscode() {
	code --help 2>&1 | head -1 | grep -qi "code"
}

# 检测是否安装了 Cursor（cursor --help 输出包含 cursor）
has_cursor() {
	cursor --help 2>&1 | head -1 | grep -qi "cursor"
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

	# VSCode/Cursor 配置（根据操作系统/环境区分路径）
	local server_type
	server_type="$(get_remote_server_type)"

	if [[ "$(uname)" == "Darwin" ]]; then
		# macOS: ~/Library/Application Support/
		if has_vscode; then
			copy_path "Library/Application Support/Code/User" "Library/Application Support/Code/User"
		fi
		if has_cursor; then
			copy_path "Library/Application Support/Cursor/User" "Library/Application Support/Cursor/User"
		fi
		# macOS 专属
		copy_path ".config/karabiner" ".config/karabiner"
		copy_path ".hammerspoon" ".hammerspoon"
	elif [[ "$server_type" == "cursor" ]]; then
		# Cursor 远程服务器环境
		print_info "检测到 Cursor 远程服务器环境"
		copy_path ".config/Cursor/User/settings.json" ".cursor-server/data/User/settings.json"
		copy_path ".config/Cursor/User/keybindings.json" ".cursor-server/data/User/keybindings.json"
		copy_path ".config/Cursor/User/settings.json" ".cursor/settings.json"
	elif [[ "$server_type" == "vscode" ]]; then
		# VSCode 远程服务器环境
		print_info "检测到 VSCode 远程服务器环境"
		copy_path ".config/Code/User/settings.json" ".vscode-server/data/User/settings.json"
		copy_path ".config/Code/User/keybindings.json" ".vscode-server/data/User/keybindings.json"
		copy_path ".config/Code/User/settings.json" ".vscode/settings.json"
	else
		# Linux 本地环境: ~/.config/
		if has_vscode; then
			copy_path ".config/Code/User" ".config/Code/User"
		fi
		if has_cursor; then
			copy_path ".config/Cursor/User" ".config/Cursor/User"
		fi
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
