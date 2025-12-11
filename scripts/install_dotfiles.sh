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
	[[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh" && chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
	[[ -f "$HOME/.config/zsh/fzf/fzf-preview.sh" ]] && chmod +x "$HOME/.config/zsh/fzf/fzf-preview.sh"

	# 安装 zinit 插件
	echo ""
	print_header "🔌 安装 Zinit 插件："
	echo ""
	if command -v zsh &>/dev/null; then
		local zinit_dir="$HOME/.local/share/zinit"
		local zsh_log="/tmp/zinit-install-$$.log"
		
		# 检测所有核心插件是否都已安装（fast-syntax-highlighting 是最后一个异步插件）
		local all_installed=true
		for plugin in "powerlevel10k" "fzf-tab" "zsh-completions" "zsh-autosuggestions" "fast-syntax-highlighting"; do
			if ! ls "$zinit_dir/plugins/"*"$plugin"* &>/dev/null; then
				all_installed=false
				break
			fi
		done
		
		if [[ "$all_installed" == "true" ]]; then
			print_info "Zinit 插件已完整安装，跳过"
		else
			# 有缺失插件：需要等待异步下载完成（zinit 使用 wait lucid 异步加载）
			print_info "正在安装 zinit 插件（异步下载中，请稍候）..."
			# 8 秒等待让所有异步插件有足够时间下载（包括 fast-syntax-highlighting）
			zsh -ic "source '$HOME/.zshrc'; sleep 8; exit" >"$zsh_log" 2>&1 || true
			# 输出到终端和日志
			if [[ -f "$zsh_log" && -s "$zsh_log" ]]; then
				cat "$zsh_log"
				cat "$zsh_log" | _strip_ansi >>"$DOTFILES_LOG"
				rm -f "$zsh_log"
			fi
		fi
		print_success "Zinit 插件安装完成"
		print_success "安装完成！请运行: source ~/.zshrc"
	else
		print_warn "未找到 zsh，跳过 zinit 插件安装"
		print_success "安装完成！请先安装 zsh 后运行: source ~/.zshrc"
	fi
}

main
