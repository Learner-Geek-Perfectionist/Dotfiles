#!/bin/bash
# Mise 安装脚本
# 原生、Rootless 的工具版本管理器
#
# 支持: Linux (x86_64, aarch64) / macOS (x86_64, arm64)
# 无需 root 权限，安装到 ~/.local/bin

set -e

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

# ========================================
# 配置
# ========================================
MISE_BIN_DIR="${MISE_BIN_DIR:-$HOME/.local/bin}"
MISE_DATA_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}"

# ========================================
# 检查 mise 是否已安装
# ========================================
check_mise_installed() {
	if command -v mise &>/dev/null; then
		local version
		version=$(mise --version 2>/dev/null | head -1)
		print_info "Mise 已安装: $version"
		return 0
	fi
	return 1
}

# ========================================
# 安装 mise
# ========================================
install_mise() {
	print_header "=========================================="
	print_header "🚀 安装 Mise (工具版本管理器)"
	print_header "=========================================="

	local os arch
	os=$(detect_os)
	arch=$(detect_arch)

	print_info "操作系统: $os"
	print_info "架构: $arch"
	print_info "安装目录: $MISE_BIN_DIR"
	echo ""

	# 创建目录
	mkdir -p "$MISE_BIN_DIR"

	# 检查是否已安装
	if check_mise_installed; then
		print_warn "Mise 已安装，跳过安装步骤"
		return 0
	fi

	# 使用官方安装脚本
	print_info "下载并安装 Mise..."

	if curl -fsSL https://mise.run | sh; then
		print_success "✓ Mise 安装成功"
	else
		print_error "Mise 安装失败"
		exit 1
	fi

	# 验证安装
	if [[ -x "$MISE_BIN_DIR/mise" ]]; then
		print_success "✓ Mise 二进制文件已就位: $MISE_BIN_DIR/mise"
	elif command -v mise &>/dev/null; then
		print_success "✓ Mise 已可用"
	else
		print_error "Mise 安装验证失败"
		exit 1
	fi
}

# ========================================
# 配置 Shell 集成
# ========================================
setup_shell_integration() {
	print_header "=========================================="
	print_header "配置 Shell 集成"
	print_header "=========================================="

	local shell_name
	shell_name=$(basename "$SHELL")

	# Mise 激活命令
	local mise_activate='eval "$(mise activate bash)"'
	local mise_activate_zsh='eval "$(mise activate zsh)"'

	# PATH 配置
	local path_export='export PATH="$HOME/.local/bin:$PATH"'

	case "$shell_name" in
	zsh)
		local zshrc="$HOME/.zshrc"

		# 确保文件存在
		touch "$zshrc"

		# 添加 PATH（如果不存在）
		if ! grep -q '\.local/bin' "$zshrc" 2>/dev/null; then
			echo "" >>"$zshrc"
			echo "# Mise: 添加本地 bin 到 PATH" >>"$zshrc"
			echo "$path_export" >>"$zshrc"
			print_success "✓ 已添加 PATH 到 .zshrc"
		fi

		# 添加 mise 激活（如果不存在）
		if ! grep -q 'mise activate' "$zshrc" 2>/dev/null; then
			echo "" >>"$zshrc"
			echo "# Mise: 激活工具版本管理" >>"$zshrc"
			echo "$mise_activate_zsh" >>"$zshrc"
			print_success "✓ 已添加 mise 激活到 .zshrc"
		else
			print_warn "mise 激活已存在于 .zshrc"
		fi
		;;
	bash)
		local bashrc="$HOME/.bashrc"

		touch "$bashrc"

		if ! grep -q '\.local/bin' "$bashrc" 2>/dev/null; then
			echo "" >>"$bashrc"
			echo "# Mise: 添加本地 bin 到 PATH" >>"$bashrc"
			echo "$path_export" >>"$bashrc"
			print_success "✓ 已添加 PATH 到 .bashrc"
		fi

		if ! grep -q 'mise activate' "$bashrc" 2>/dev/null; then
			echo "" >>"$bashrc"
			echo "# Mise: 激活工具版本管理" >>"$bashrc"
			echo "$mise_activate" >>"$bashrc"
			print_success "✓ 已添加 mise 激活到 .bashrc"
		else
			print_warn "mise 激活已存在于 .bashrc"
		fi
		;;
	*)
		print_warn "未知 Shell: $shell_name"
		print_info "请手动添加以下内容到你的 shell 配置文件:"
		print_info "  $path_export"
		print_info "  eval \"\$(mise activate <shell>)\""
		;;
	esac
}

# ========================================
# 安装工具包
# ========================================
install_tools() {
	print_header "=========================================="
	print_header "安装工具包"
	print_header "=========================================="

	# 确保 mise 在 PATH 中
	export PATH="$MISE_BIN_DIR:$PATH"

	# mise 配置由 chezmoi 管理，安装到 ~/.config/mise/config.toml
	local mise_config="$HOME/.config/mise/config.toml"

	if [[ -f "$mise_config" ]]; then
		print_info "找到配置文件: $mise_config"

		# 信任配置文件
		print_info "信任配置文件..."
		mise trust "$mise_config" 2>/dev/null || true

		# 安装所有工具
		print_info "安装工具包（这可能需要几分钟）..."
		if mise install; then
			print_success "✓ 工具包安装完成"
		else
			print_warn "部分工具安装失败，请检查日志"
		fi
	else
		print_warn "未找到 mise 配置文件: $mise_config"
		print_info "请先运行 chezmoi apply 安装配置"
		print_info "或手动创建配置文件后运行 mise install"
	fi
}

# ========================================
# 显示帮助
# ========================================
show_help() {
	cat <<HELP_EOF
Mise 安装脚本

用法: $0 [选项]

选项:
    --install-only      仅安装 mise，不配置 shell
    --tools-only        仅安装工具包（假设 mise 已安装）
    --shell-only        仅配置 shell 集成
    --help, -h          显示帮助信息

环境变量:
    MISE_BIN_DIR        mise 安装目录 (默认: ~/.local/bin)
    DOTFILES_DIR        Dotfiles 目录 (默认: 自动检测)

示例:
    # 完整安装
    $0

    # 仅安装 mise
    $0 --install-only

    # 仅安装工具包
    $0 --tools-only
HELP_EOF
}

# ========================================
# 主函数
# ========================================
main() {
	local action="full"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--install-only)
			action="install"
			shift
			;;
		--tools-only)
			action="tools"
			shift
			;;
		--shell-only)
			action="shell"
			shift
			;;
		--help | -h)
			show_help
			exit 0
			;;
		*)
			print_error "未知参数: $1"
			show_help
			exit 1
			;;
		esac
	done

	case "$action" in
	full)
		install_mise
		setup_shell_integration
		install_tools
		;;
	install)
		install_mise
		;;
	tools)
		install_tools
		;;
	shell)
		setup_shell_integration
		;;
	esac

	echo ""
	print_success "=========================================="
	print_success "✅ Mise 设置完成！"
	print_success "=========================================="
	echo ""
	print_info "下一步:"
	print_info "  1. 重新打开终端，或运行: source ~/.zshrc"
	print_info "  2. 验证安装: mise doctor"
	print_info "  3. 查看已安装工具: mise list"
	echo ""
	print_info "常用命令:"
	print_info "  mise install        - 安装配置文件中的所有工具"
	print_info "  mise use node@20    - 设置 Node.js 版本"
	print_info "  mise list           - 列出已安装的工具"
	print_info "  mise upgrade        - 升级所有工具"
	echo ""
}

main "$@"
