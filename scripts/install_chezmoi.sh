#!/bin/bash
# Chezmoi 安装和初始化脚本
# Dotfiles 管理器

set -e

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

# ========================================
# 配置
# ========================================
CHEZMOI_BIN="$HOME/.local/bin/chezmoi"
CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"

# ========================================
# 获取 Dotfiles 目录
# ========================================
get_dotfiles_dir() {
	if [[ -n "$DOTFILES_DIR" ]]; then
		echo "$DOTFILES_DIR"
		return
	fi

	echo "$(cd "$SCRIPT_DIR/.." && pwd)"
}

# ========================================
# 安装 Chezmoi
# ========================================
install_chezmoi() {
	print_header "=========================================="
	print_header "🏠 安装 Chezmoi (Dotfiles 管理器)"
	print_header "=========================================="

	# 检查是否已安装
	if command -v chezmoi &>/dev/null; then
		print_info "Chezmoi 已安装: $(chezmoi --version)"
		return 0
	fi

	# 优先使用 mise 安装
	export PATH="$HOME/.local/bin:$PATH"

	if command -v mise &>/dev/null; then
		print_info "使用 mise 安装 chezmoi..."
		mise install ubi:twpayne/chezmoi
		mise use -g ubi:twpayne/chezmoi@latest
		print_success "✓ Chezmoi 已通过 mise 安装"
		return 0
	fi

	# 回退：直接下载
	print_info "直接下载 chezmoi..."
	mkdir -p "$HOME/.local/bin"

	sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

	if [[ -x "$CHEZMOI_BIN" ]]; then
		print_success "✓ Chezmoi 安装成功"
	else
		print_error "Chezmoi 安装失败"
		exit 1
	fi
}

# ========================================
# 初始化 Chezmoi
# ========================================
init_chezmoi() {
	print_header "=========================================="
	print_header "初始化 Chezmoi 源"
	print_header "=========================================="

	local dotfiles_dir
	dotfiles_dir=$(get_dotfiles_dir)
	local chezmoi_src="$dotfiles_dir/chezmoi"

	# 确保 chezmoi 在 PATH 中
	export PATH="$HOME/.local/bin:$PATH"

	if [[ ! -d "$chezmoi_src" ]]; then
		print_error "Chezmoi 源目录不存在: $chezmoi_src"
		exit 1
	fi

	print_info "Dotfiles 目录: $dotfiles_dir"
	print_info "Chezmoi 源: $chezmoi_src"

	# 如果已经初始化，先清理
	if [[ -d "$CHEZMOI_SOURCE" ]]; then
		print_warn "Chezmoi 源目录已存在，将重新初始化"
		rm -rf "$CHEZMOI_SOURCE"
	fi

	# 创建 chezmoi 源目录
	mkdir -p "$CHEZMOI_SOURCE"

	# 复制配置文件
	print_info "复制配置文件到 chezmoi 源..."
	cp -r "$chezmoi_src/"* "$CHEZMOI_SOURCE/"

	# 设置 chezmoi 配置
	if [[ -f "$CHEZMOI_SOURCE/.chezmoi.toml.tmpl" ]]; then
		print_info "发现 chezmoi 配置模板"
	fi

	print_success "✓ Chezmoi 源初始化完成"
}

# ========================================
# 应用配置
# ========================================
apply_chezmoi() {
	print_header "=========================================="
	print_header "应用 Dotfiles 配置"
	print_header "=========================================="

	export PATH="$HOME/.local/bin:$PATH"

	print_info "运行 chezmoi apply..."

	# 首次运行时初始化
	if [[ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]]; then
		print_info "首次运行，将提示输入配置信息..."
		chezmoi init --apply
	else
		chezmoi apply
	fi

	print_success "✓ Dotfiles 配置已应用"
}

# ========================================
# 显示帮助
# ========================================
show_help() {
	cat <<HELP_EOF
Chezmoi 安装和配置脚本

用法: $0 [选项]

选项:
    --install-only      仅安装 chezmoi
    --init-only         仅初始化源（不应用配置）
    --apply-only        仅应用配置
    --help, -h          显示帮助信息

环境变量:
    DOTFILES_DIR        Dotfiles 目录 (默认: 自动检测)

示例:
    # 完整安装和配置
    $0

    # 仅安装 chezmoi
    $0 --install-only

常用 chezmoi 命令:
    chezmoi cd              - 进入源目录
    chezmoi edit <file>     - 编辑配置文件
    chezmoi diff            - 查看变更
    chezmoi apply           - 应用配置
    chezmoi update          - 从远程更新
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
		--init-only)
			action="init"
			shift
			;;
		--apply-only)
			action="apply"
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
		install_chezmoi
		init_chezmoi
		apply_chezmoi
		;;
	install)
		install_chezmoi
		;;
	init)
		init_chezmoi
		;;
	apply)
		apply_chezmoi
		;;
	esac

	echo ""
	print_success "=========================================="
	print_success "✅ Chezmoi 设置完成！"
	print_success "=========================================="
	echo ""
	print_info "常用命令:"
	print_info "  chezmoi cd          - 进入源目录"
	print_info "  chezmoi edit ~/.zshrc - 编辑 zshrc"
	print_info "  chezmoi diff        - 查看变更"
	print_info "  chezmoi apply       - 应用配置"
	print_info "  chezmoi update      - 从远程更新"
	echo ""
}

main "$@"
