#!/bin/bash
# Linuxbrew 安装脚本 - 完全无 sudo
# 安装到用户目录 ~/.linuxbrew，无需 root 权限
#
# 文档: https://docs.brew.sh/Homebrew-on-Linux

set -e

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../lib/utils.sh" ]]; then
	source "$SCRIPT_DIR/../lib/utils.sh"
fi

# ========================================
# 配置
# ========================================
# 无 sudo 安装到用户目录
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$HOME/.linuxbrew}"

# ========================================
# 检查 Homebrew 是否已安装
# ========================================
check_brew_installed() {
	if [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
		local version
		version=$("$HOMEBREW_PREFIX/bin/brew" --version 2>/dev/null | head -1)
		print_info "Homebrew 已安装: $version"
		return 0
	fi
	return 1
}

# ========================================
# 无 sudo 安装 Homebrew
# ========================================
install_homebrew_rootless() {
	print_header "=========================================="
	print_header "🍺 安装 Linuxbrew (无 sudo)"
	print_header "=========================================="

	print_info "安装目录: $HOMEBREW_PREFIX"
	echo ""

	# 检查是否已安装
	if check_brew_installed; then
		print_warn "Homebrew 已安装，跳过安装步骤"
		return 0
	fi

	# 检查依赖
	local missing_deps=()
	for cmd in git curl; do
		if ! command -v "$cmd" &>/dev/null; then
			missing_deps+=("$cmd")
		fi
	done

	if ((${#missing_deps[@]} > 0)); then
		print_error "缺少依赖: ${missing_deps[*]}"
		print_info "请确保系统已安装 git 和 curl"
		exit 1
	fi

	print_info "下载并安装 Homebrew (无 root 权限)..."

	# 创建安装目录
	mkdir -p "$HOMEBREW_PREFIX"

	# 克隆 Homebrew
	print_info "克隆 Homebrew 仓库..."
	git clone --depth=1 https://github.com/Homebrew/brew "$HOMEBREW_PREFIX/Homebrew"

	# 创建必要的目录结构
	mkdir -p "$HOMEBREW_PREFIX/bin"
	mkdir -p "$HOMEBREW_PREFIX/etc"
	mkdir -p "$HOMEBREW_PREFIX/include"
	mkdir -p "$HOMEBREW_PREFIX/lib"
	mkdir -p "$HOMEBREW_PREFIX/opt"
	mkdir -p "$HOMEBREW_PREFIX/sbin"
	mkdir -p "$HOMEBREW_PREFIX/share"
	mkdir -p "$HOMEBREW_PREFIX/var/homebrew/linked"
	mkdir -p "$HOMEBREW_PREFIX/Cellar"
	mkdir -p "$HOMEBREW_PREFIX/Caskroom"
	mkdir -p "$HOMEBREW_PREFIX/Frameworks"

	# 创建 brew 符号链接
	ln -sf "$HOMEBREW_PREFIX/Homebrew/bin/brew" "$HOMEBREW_PREFIX/bin/brew"

	# 验证安装
	if [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
		print_success "✓ Homebrew 安装成功"
	else
		print_error "Homebrew 安装失败"
		exit 1
	fi

	# 设置环境变量
	export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
	eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"

	# 更新 Homebrew
	print_info "更新 Homebrew..."
	"$HOMEBREW_PREFIX/bin/brew" update --force --quiet

	# 安装 homebrew-core
	print_info "安装 homebrew-core..."
	"$HOMEBREW_PREFIX/bin/brew" tap homebrew/core --force

	print_success "✓ Linuxbrew 安装完成"
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

	# Homebrew shellenv 配置
	local brew_shellenv="eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\""

	case "$shell_name" in
	zsh)
		local zshrc="$HOME/.zshrc"
		touch "$zshrc"

		# 添加 Homebrew（如果不存在）
		if ! grep -q '\.linuxbrew' "$zshrc" 2>/dev/null; then
			echo "" >>"$zshrc"
			echo "# Linuxbrew: 添加到环境变量" >>"$zshrc"
			echo "$brew_shellenv" >>"$zshrc"
			print_success "✓ 已添加 Homebrew 配置到 .zshrc"
		else
			print_warn "Homebrew 配置已存在于 .zshrc"
		fi
		;;
	bash)
		local bashrc="$HOME/.bashrc"
		touch "$bashrc"

		if ! grep -q '\.linuxbrew' "$bashrc" 2>/dev/null; then
			echo "" >>"$bashrc"
			echo "# Linuxbrew: 添加到环境变量" >>"$bashrc"
			echo "$brew_shellenv" >>"$bashrc"
			print_success "✓ 已添加 Homebrew 配置到 .bashrc"
		else
			print_warn "Homebrew 配置已存在于 .bashrc"
		fi
		;;
	*)
		print_warn "未知 Shell: $shell_name"
		print_info "请手动添加以下内容到你的 shell 配置文件:"
		print_info "  $brew_shellenv"
		;;
	esac
}

# ========================================
# 安装全局工具包
# ========================================
install_packages() {
	print_header "=========================================="
	print_header "安装工具包"
	print_header "=========================================="

	# 设置环境变量
	export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
	eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"

	if ! command -v brew &>/dev/null; then
		print_error "Homebrew 未找到，无法安装工具包"
		return 1
	fi

	# 加载包定义
	local lib_dir="$SCRIPT_DIR/../lib"
	if [[ -f "$lib_dir/packages.sh" ]]; then
		source "$lib_dir/packages.sh"
	else
		print_error "未找到包定义文件: $lib_dir/packages.sh"
		return 1
	fi

	# 检查是否定义了 Linux 包列表
	if [[ ${#brew_formulas_linux[@]} -eq 0 ]]; then
		print_warn "未定义 Linux 包列表 (brew_formulas_linux)"
		return 0
	fi

	print_info "安装 CLI 工具（这可能需要几分钟）..."
	print_info "所有包都是预编译的，无需本地编译"
	echo ""

	# 安装包（忽略已安装的）
	if brew install "${brew_formulas_linux[@]}" 2>/dev/null; then
		print_success "✓ 工具包安装完成"
	else
		print_warn "部分工具安装失败"
		print_info "可以稍后运行: brew install <package>"
	fi

	# 更新 tldr 缓存
	if command -v tldr &>/dev/null; then
		print_info "更新 tldr 缓存..."
		tldr --update 2>/dev/null && print_success "✓ tldr 缓存更新完成"
	fi

	# 显示已安装的包
	echo ""
	print_info "已安装的工具:"
	brew list --formula
}

# ========================================
# 显示帮助
# ========================================
show_help() {
	cat <<HELP_EOF
Linuxbrew 安装脚本 (无 sudo)

用法: $0 [选项]

选项:
    --install-only      仅安装 Homebrew，不安装工具包
    --packages-only     仅安装工具包（假设 Homebrew 已安装）
    --shell-only        仅配置 shell 集成
    --help, -h          显示帮助信息

环境变量:
    HOMEBREW_PREFIX     Homebrew 安装目录 (默认: ~/.linuxbrew)

示例:
    # 完整安装
    $0

    # 仅安装 Homebrew
    $0 --install-only

常用 brew 命令:
    brew install <pkg>     - 安装包
    brew list              - 列出已安装的包
    brew upgrade           - 升级所有包
    brew uninstall <pkg>   - 移除包
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
		--packages-only)
			action="packages"
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
		install_homebrew_rootless
		setup_shell_integration
		install_packages
		;;
	install)
		install_homebrew_rootless
		setup_shell_integration
		;;
	packages)
		install_packages
		;;
	shell)
		setup_shell_integration
		;;
	esac

	# 检测 shell 配置文件
	local rc_file="~/.bashrc"
	[[ "$SHELL" == *zsh ]] && rc_file="~/.zshrc"

	echo ""
	print_success "=========================================="
	print_success "✅ Linuxbrew 设置完成！"
	print_success "=========================================="
	echo ""
	print_info "下一步:"
	print_info "  1. 重新打开终端，或运行: source $rc_file"
	print_info "  2. 验证安装: brew list"
	echo ""
	print_info "常用命令:"
	print_info "  brew install <pkg>  - 安装包"
	print_info "  brew list           - 列出已安装包"
	print_info "  brew upgrade        - 升级所有包"
	echo ""
}

main "$@"

