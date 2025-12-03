#!/bin/bash
# Dotfiles 统一安装入口
#
# Linux: Linuxbrew (包管理) + Dotfiles 配置 - 完全 Rootless，无需 sudo
# macOS: Homebrew (包管理) + Dotfiles 配置
#
# 支持: Linux (x86_64, aarch64) / macOS (x86_64, arm64)

set -e

# ========================================
# 版本和配置
# ========================================
DOTFILES_VERSION="5.0.0"
DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/Learner-Geek-Perfectionist/Dotfiles.git}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-beta}"

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export PURPLE='\033[0;35m'
export NC='\033[0m'

# 默认配置
SKIP_VSCODE="${SKIP_VSCODE:-false}"
SKIP_DOTFILES="${SKIP_DOTFILES:-false}"
BREW_ONLY="${BREW_ONLY:-false}"

# 日志文件
LOG_FILE="${LOG_FILE:-/tmp/dotfiles-install-$(whoami).log}"

# ========================================
# 工具函数
# ========================================
print_msg() {
	local msg="$1"
	local color="${2:-$NC}"
	echo -e "${color}${msg}${NC}"
}

print_info() { print_msg "$1" "$CYAN"; }
print_success() { print_msg "$1" "$GREEN"; }
print_warn() { print_msg "$1" "$YELLOW"; }
print_error() { print_msg "$1" "$RED"; }
print_header() { print_msg "$1" "$BLUE"; }
print_step() { print_msg "$1" "$PURPLE"; }

# 检测操作系统
detect_os() {
	local os
	os=$(uname -s)
	case "$os" in
	Darwin) echo "macos" ;;
	Linux) echo "linux" ;;
	*) echo "unknown" ;;
	esac
}

# 检测系统架构
detect_arch() {
	local arch
	arch=$(uname -m)
	case "$arch" in
	x86_64) echo "x86_64" ;;
	aarch64 | arm64) echo "aarch64" ;;
	*) echo "$arch" ;;
	esac
}

# 显示帮助
show_help() {
	cat <<HELP_EOF
Dotfiles 安装脚本 v${DOTFILES_VERSION}

架构:
    Linux: Linuxbrew (包管理) + Dotfiles 配置 - 完全 Rootless，无需 sudo
    macOS: Homebrew (包管理) + Dotfiles 配置

用法: $0 [选项]

选项:
    --brew-only         仅安装 Homebrew（仅 Linux）
    --skip-dotfiles     跳过 Dotfiles 配置安装
    --skip-vscode       跳过 VSCode 插件安装
    --help, -h          显示帮助信息

环境变量:
    BREW_ONLY           设为 "true" 仅安装 Homebrew（仅 Linux）
    SKIP_DOTFILES       设为 "true" 跳过 Dotfiles 配置
    SKIP_VSCODE         设为 "true" 跳过 VSCode 插件

示例:
    # 完整安装
    curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash

    # 仅安装 Homebrew（Linux）
    curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash -s -- --brew-only

    # 跳过 VSCode 插件
    curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash -s -- --skip-vscode
HELP_EOF
}

# ========================================
# 日志设置
# ========================================
setup_logging() {
	{
		echo "======================================"
		echo "Dotfiles Installation Log"
		echo "Version: $DOTFILES_VERSION"
		echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
		echo "OS: $(uname -s) $(uname -r)"
		echo "Arch: $(detect_arch)"
		echo "User: $(whoami)"
		echo "======================================"
		echo ""
	} >"$LOG_FILE"
}

# ========================================
# 依赖检查
# ========================================
# 注意: 这里检查的是"引导依赖"（bootstrap dependencies）
# 第一次运行时 Homebrew 还没装：
#   1. 需要 curl 下载安装脚本
#   2. 需要 git 克隆 dotfiles 仓库和 Homebrew
# 所以必须确保系统已有这些基础工具
#
# 因为用户没有 sudo 权限，无法自动安装依赖
# 只检查依赖是否存在，不存在则提示用户联系管理员

check_dependencies() {
	print_info "检查基础依赖..."

	local -a deps=(git curl) missing=()
	for dep in "${deps[@]}"; do
		command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
	done

	if ((${#missing[@]} == 0)); then
		print_success "✓ 基础依赖已满足"
		return 0
	fi

	print_error "缺少依赖: ${missing[*]}"
	print_info "由于没有 sudo 权限，无法自动安装这些依赖"
	print_info "请联系系统管理员安装以下软件包："
	for dep in "${missing[@]}"; do
		print_info "  - $dep"
	done
	exit 1
}

# ========================================
# 仓库克隆
# ========================================
clone_dotfiles() {
	local tmp_dir="/tmp/Dotfiles-$(whoami)"

	# 清理之前的运行
	[[ -d "$tmp_dir" ]] && rm -rf "$tmp_dir"

	local branch="$DEFAULT_BRANCH"

	print_header "克隆 Dotfiles 仓库 (分支: ${branch})..." >&2

	if ! git clone --depth=1 --branch "$branch" --single-branch "$DOTFILES_REPO_URL" "$tmp_dir"; then
		print_error "克隆仓库失败（分支: ${branch}）" >&2
		exit 1
	fi

	echo "$tmp_dir"
}

# ========================================
# macOS: 安装 Homebrew 包
# ========================================
install_macos_homebrew() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	print_step "步骤 ${step_num}: 安装 Homebrew 包"
	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	if [[ -f "$dotfiles_dir/scripts/macos_install.sh" ]]; then
		bash "$dotfiles_dir/scripts/macos_install.sh"
	else
		print_warn "未找到 macOS 安装脚本，跳过 Homebrew 包安装"
	fi

	print_success "✓ Homebrew 包安装完成"
}

# ========================================
# Linux: 安装 Linuxbrew
# ========================================
install_linuxbrew() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	print_step "步骤 ${step_num}: 安装 Linuxbrew (无 sudo)"
	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	# 安装 Linuxbrew
	if [[ -f "$dotfiles_dir/scripts/install_linuxbrew.sh" ]]; then
		bash "$dotfiles_dir/scripts/install_linuxbrew.sh" --install-only
	else
		print_error "未找到 Linuxbrew 安装脚本"
		exit 1
	fi

	# 确保 brew 在 PATH 中
	local HOMEBREW_PREFIX="$HOME/.linuxbrew"
	export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
	eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)" 2>/dev/null || true

	print_success "✓ Linuxbrew 安装完成"
}

# ========================================
# Linux: 安装 Homebrew 工具包
# ========================================
install_linux_packages() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	print_step "步骤 ${step_num}: 安装 Homebrew 工具包"
	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	local HOMEBREW_PREFIX="$HOME/.linuxbrew"
	export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
	eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)" 2>/dev/null || true

	if ! command -v brew &>/dev/null; then
		print_error "Homebrew 未安装"
		return 1
	fi

	# 加载包定义
	source "$dotfiles_dir/lib/packages.sh"

	if [[ ${#brew_formulas_linux[@]} -eq 0 ]]; then
		print_warn "未定义 Linux 包列表"
		return 0
	fi

	print_info "安装工具包（这可能需要几分钟）..."
	print_info "所有包都是预编译的，无需本地编译"
	echo ""

	if brew install "${brew_formulas_linux[@]}" 2>/dev/null; then
		print_success "✓ 工具包安装完成"

		# 更新 tldr 缓存
		if command -v tldr &>/dev/null; then
			print_info "更新 tldr 缓存..."
			tldr --update 2>/dev/null && print_success "✓ tldr 缓存更新完成"
		fi
	else
		print_warn "部分工具安装失败"
		print_info "可以稍后运行: brew install <package>"
	fi

	# 显示已安装的包
	echo ""
	print_info "已安装的工具:"
	brew list --formula
}

# ========================================
# 安装 Dotfiles 配置
# ========================================
setup_dotfiles() {
	local dotfiles_dir="$1"
	local step_num="$2"

	if [[ "$SKIP_DOTFILES" == "true" ]]; then
		print_warn "跳过 Dotfiles 配置"
		return 0
	fi

	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	print_step "步骤 ${step_num}: 安装 Dotfiles 配置"
	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	if [[ -f "$dotfiles_dir/scripts/install_dotfiles.sh" ]]; then
		DOTFILES_DIR="$dotfiles_dir" bash "$dotfiles_dir/scripts/install_dotfiles.sh"
	else
		print_warn "未找到 Dotfiles 安装脚本，跳过"
	fi

	print_success "✓ Dotfiles 配置完成"
}

# ========================================
# 安装 VSCode 插件
# ========================================
install_vscode() {
	local dotfiles_dir="$1"
	local step_num="$2"

	if [[ "$SKIP_VSCODE" == "true" ]]; then
		print_warn "跳过 VSCode 插件安装"
		return 0
	fi

	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	print_step "步骤 ${step_num}: 安装 VSCode 插件"
	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	if [[ -f "$dotfiles_dir/scripts/install_vscode_ext.sh" ]]; then
		bash "$dotfiles_dir/scripts/install_vscode_ext.sh" || {
			print_warn "VSCode 插件安装跳过（可能未安装 VSCode）"
		}
	fi
}

# ========================================
# 配置 SSH
# ========================================
setup_ssh() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	print_step "步骤 ${step_num}: 配置 SSH"
	print_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	if [[ -f "$dotfiles_dir/config" ]]; then
		mkdir -p "$HOME/.ssh"
		chmod 700 "$HOME/.ssh"

		if [[ -f "$HOME/.ssh/config" ]]; then
			cp "$HOME/.ssh/config" "$HOME/.ssh/config.bak"
			print_info "已备份旧的 SSH 配置"
		fi

		cp "$dotfiles_dir/config" "$HOME/.ssh/config"
		chmod 600 "$HOME/.ssh/config"
		print_success "✓ SSH 配置完成"
	else
		print_warn "未找到 SSH 配置文件，跳过"
	fi
}

# ========================================
# Linux 安装流程
# ========================================
install_linux() {
	local dotfiles_dir="$1"

	# 步骤 1: 安装 Linuxbrew
	install_linuxbrew "$dotfiles_dir" "1/4"

	if [[ "$BREW_ONLY" == "true" ]]; then
		print_success "✓ Linuxbrew 安装完成（仅 Homebrew 模式）"
		return 0
	fi

	# 步骤 2: 安装 Homebrew 工具包
	install_linux_packages "$dotfiles_dir" "2/4"

	# 步骤 3: 安装 Dotfiles 配置
	setup_dotfiles "$dotfiles_dir" "3/4"

	# 步骤 4: VSCode 插件
	install_vscode "$dotfiles_dir" "4/4"
}

# ========================================
# macOS 安装流程
# ========================================
install_macos() {
	local dotfiles_dir="$1"

	# 步骤 1: 安装 Homebrew 包
	install_macos_homebrew "$dotfiles_dir" "1/4"

	# 步骤 2: 安装 Dotfiles 配置
	setup_dotfiles "$dotfiles_dir" "2/4"

	# 步骤 3: VSCode 插件
	install_vscode "$dotfiles_dir" "3/4"

	# 步骤 4: SSH 配置（额外的根目录 config 文件）
	setup_ssh "$dotfiles_dir" "4/4"
}

# ========================================
# 主函数
# ========================================
main() {
	# 解析参数
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--brew-only)
			BREW_ONLY="true"
			shift
			;;
		--skip-dotfiles)
			SKIP_DOTFILES="true"
			shift
			;;
		--skip-vscode)
			SKIP_VSCODE="true"
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

	# 设置日志
	setup_logging

	local os arch
	os=$(detect_os)
	arch=$(detect_arch)

	print_header "╔══════════════════════════════════════════╗"
	print_header "║  🚀 Dotfiles 安装脚本 v${DOTFILES_VERSION}          ║"
	print_header "╚══════════════════════════════════════════╝"
	echo ""
	print_info "操作系统: $os"
	print_info "架构: $arch"
	print_info "用户: $(whoami)"

	if [[ "$os" == "macos" ]]; then
		print_info "安装方式: Homebrew + Dotfiles 配置"
	else
		print_info "安装方式: Linuxbrew + Dotfiles 配置 (完全 Rootless，无需 sudo)"
	fi
	echo ""

	# 检查依赖
	check_dependencies

	# 克隆仓库
	local dotfiles_dir
	dotfiles_dir=$(clone_dotfiles)
	export DOTFILES_DIR="$dotfiles_dir"

	# 根据操作系统执行安装
	case "$os" in
	macos)
		install_macos "$dotfiles_dir"
		;;
	linux)
		install_linux "$dotfiles_dir"
		;;
	*)
		print_error "不支持的操作系统: $os"
		exit 1
		;;
	esac

	# 完成
	echo ""
	print_success "╔══════════════════════════════════════════╗"
	print_success "║  ✅ 安装完成！                           ║"
	print_success "╚══════════════════════════════════════════╝"
	echo ""
	print_info "📝 安装日志: $LOG_FILE"
	echo ""
	print_info "下一步:"
	print_info "  1. 重新打开终端（或运行: source ~/.zshrc）"
	print_info "  2. 验证安装: brew list"
	echo ""
	print_info "常用命令:"
	print_info "  brew install <pkg>          - 安装包"
	print_info "  brew update && brew upgrade - 更新所有包"

	echo ""
}

main "$@"
