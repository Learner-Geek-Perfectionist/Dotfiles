#!/bin/bash
# Dotfiles 统一安装入口
# Linux: 默认使用 nix-user-chroot + devbox（无需 sudo）
# macOS: 使用 Homebrew

set -e

# ========================================
# 版本和配置
# ========================================
DOTFILES_VERSION="2.0.0"
DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/Learner-Geek-Perfectionist/Dotfiles.git}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-beta}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-}"

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export LIGHT_BLUE='\033[1;34m'
export NC='\033[0m'

# 默认配置
USE_SUDO="${USE_SUDO:-false}"
SKIP_VSCODE="${SKIP_VSCODE:-false}"
DOTFILES_ONLY="${DOTFILES_ONLY:-false}"

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

# 解析需要克隆的 Git 分支
resolve_branch() {
	if [[ -n "$DOTFILES_BRANCH" ]]; then
		return
	fi

	if [[ -n "$GITHUB_REF_NAME" ]]; then
		DOTFILES_BRANCH="$GITHUB_REF_NAME"
		return
	fi

	DOTFILES_BRANCH="$DEFAULT_BRANCH"
}

# 显示帮助
show_help() {
	cat <<HELP_EOF
Dotfiles 安装脚本 v${DOTFILES_VERSION}

用法: $0 [选项]

选项:
    --use-sudo          使用 sudo 安装（Linux 系统级 Nix）
    --skip-vscode       跳过 VSCode 插件安装
    --dotfiles-only     仅安装 dotfiles 配置，不安装工具
    --branch BRANCH     指定 Git 分支（默认: \$DOTFILES_BRANCH 或 ${DEFAULT_BRANCH}）
    --help, -h          显示帮助信息

环境变量:
    USE_SUDO            设为 "true" 使用 sudo 安装
    SKIP_VSCODE         设为 "true" 跳过 VSCode 插件
    DOTFILES_ONLY       设为 "true" 仅安装配置文件
    DOTFILES_BRANCH     指定 Git 分支

示例:
    # 默认安装（无需 sudo，适合服务器环境）
    curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash

    # 使用 sudo 安装
    curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash -s -- --use-sudo

    # 仅安装 dotfiles
    curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash -s -- --dotfiles-only
HELP_EOF
}

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
	aarch64) echo "aarch64" ;;
	arm64) echo "aarch64" ;;
	*) echo "$arch" ;;
	esac
}

# ========================================
# 日志设置
# ========================================
setup_logging() {
	# 使用 script 命令创建 PTY 环境
	if [[ -z "$__DOTFILES_PTY" ]]; then
		export __DOTFILES_PTY=1

		# 初始化日志
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

		SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"

		if [[ -n "$SCRIPT_SOURCE" && -r "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]] &&
			[[ ! "$SCRIPT_SOURCE" =~ (^|/)(bash|sh|zsh|dash|ksh)$ ]] &&
			[[ ! "$SCRIPT_SOURCE" =~ ^/dev/ ]] &&
			[[ ! "$SCRIPT_SOURCE" =~ ^/proc/ ]]; then
			SCRIPT_PATH="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)/$(basename "$SCRIPT_SOURCE")"
		else
			SCRIPT_PATH=""
		fi

		if [[ -n "$SCRIPT_PATH" ]]; then
			if [[ $(uname -s) == "Darwin" ]]; then
				exec script -q -a "$LOG_FILE" /bin/bash "$SCRIPT_PATH" "$@"
			else
				exec script -q -a "$LOG_FILE" -c "/bin/bash \"$SCRIPT_PATH\" $*"
			fi
		fi
	fi
}

# ========================================
# 仓库克隆
# ========================================
clone_dotfiles() {
	local tmp_dir="/tmp/Dotfiles-$(whoami)"

	# 清理之前的运行
	[[ -d "$tmp_dir" ]] && rm -rf "$tmp_dir"

	# 硬编码使用 beta 分支
	local branch="beta"
	
	print_header "克隆 Dotfiles 仓库 (分支: ${branch})..." >&2

	if ! git clone --depth=1 --branch "$branch" --single-branch "$DOTFILES_REPO_URL" "$tmp_dir"; then
		print_error "克隆仓库失败（分支: ${branch}）" >&2
		exit 1
	fi

	echo "$tmp_dir"
}

# ========================================
# macOS 安装流程
# ========================================
install_macos() {
	local dotfiles_dir="$1"

	print_header "=========================================="
	print_header "macOS 安装流程"
	print_header "=========================================="

	# 确保 Xcode CLI 工具已安装
	if ! command -v git &>/dev/null; then
		print_info "安装 Xcode Command Line Tools..."
		xcode-select --install 2>/dev/null || true
		print_warn "请完成安装对话框，然后按 Enter 继续..."
		read -r
	fi

	# 执行 macOS 安装脚本
	if [[ -f "$dotfiles_dir/scripts/macos_install.sh" ]]; then
		print_info "执行 macOS 安装脚本..."
		source "$dotfiles_dir/scripts/macos_install.sh"
	fi

	# 配置 dotfiles
	setup_dotfiles "$dotfiles_dir"

	# 安装 VSCode 插件
	if [[ "$SKIP_VSCODE" != "true" ]]; then
		install_vscode_extensions "$dotfiles_dir"
	fi
}

# ========================================
# Linux 安装流程（默认无 sudo）
# ========================================
install_linux() {
	local dotfiles_dir="$1"

	print_header "=========================================="
	print_header "Linux 安装流程"
	print_header "模式: $([ "$USE_SUDO" == "true" ] && echo "系统级 (sudo)" || echo "用户级 (nix-user-chroot)")"
	print_header "=========================================="

	if [[ "$DOTFILES_ONLY" != "true" ]]; then
		# 安装 Nix
		print_info "步骤 1/3: 安装 Nix..."
		if [[ "$USE_SUDO" == "true" ]]; then
			bash "$dotfiles_dir/scripts/install_nix.sh" --use-sudo
		else
			bash "$dotfiles_dir/scripts/install_nix.sh"
		fi

		# 安装 Devbox
		print_info "步骤 2/3: 安装 Devbox..."
		bash "$dotfiles_dir/scripts/install_devbox.sh"
	fi

	# 配置 dotfiles
	print_info "步骤 3/3: 配置 Dotfiles..."
	setup_dotfiles "$dotfiles_dir"

	# 安装 VSCode 插件
	if [[ "$SKIP_VSCODE" != "true" ]]; then
		install_vscode_extensions "$dotfiles_dir"
	fi
}

# ========================================
# Dotfiles 配置
# ========================================
setup_dotfiles() {
	local dotfiles_dir="$1"

	print_info "配置 Dotfiles..."

	# 创建 XDG 目录结构
	mkdir -p "$HOME/.config/zsh/plugins"
	mkdir -p "$HOME/.config/kitty"
	mkdir -p "$HOME/.cache/zsh"
	mkdir -p "$HOME/.local/share/zinit"
	mkdir -p "$HOME/.local/bin"
	mkdir -p "$HOME/.local/state"

	# 执行 setup_dotfiles.sh
	if [[ -f "$dotfiles_dir/scripts/setup_dotfiles.sh" ]]; then
		bash "$dotfiles_dir/scripts/setup_dotfiles.sh"
	else
		# 手动复制配置文件
		copy_dotfiles "$dotfiles_dir"
	fi

	print_success "✓ Dotfiles 配置完成"
}

# 复制配置文件
copy_dotfiles() {
	local dotfiles_dir="$1"

	# Zsh 配置
	[[ -f "$dotfiles_dir/.zshrc" ]] && cp "$dotfiles_dir/.zshrc" "$HOME/.zshrc"
	[[ -f "$dotfiles_dir/.zshenv" ]] && cp "$dotfiles_dir/.zshenv" "$HOME/.zshenv"
	[[ -f "$dotfiles_dir/.zprofile" ]] && cp "$dotfiles_dir/.zprofile" "$HOME/.zprofile"

	# Kitty 配置
	if [[ -d "$dotfiles_dir/.config/kitty" ]]; then
		cp -r "$dotfiles_dir/.config/kitty/"* "$HOME/.config/kitty/"
	fi

	# Zsh 插件配置
	if [[ -d "$dotfiles_dir/.config/zsh" ]]; then
		cp -r "$dotfiles_dir/.config/zsh/"* "$HOME/.config/zsh/"
	fi
}

# ========================================
# VSCode 插件安装
# ========================================
install_vscode_extensions() {
	local dotfiles_dir="$1"

	if [[ -f "$dotfiles_dir/scripts/install_vscode_ext.sh" ]]; then
		print_info "安装 VSCode 插件..."
		bash "$dotfiles_dir/scripts/install_vscode_ext.sh" || {
			print_warn "VSCode 插件安装跳过（可能未安装 VSCode）"
		}
	fi
}

# ========================================
# 初始化 Devbox 环境
# ========================================
initialize_devbox() {
	local dotfiles_dir="$1"

	if [[ -f "$dotfiles_dir/devbox.json" ]]; then
		print_info "初始化 Devbox 环境..."

		# 复制整个仓库到 ~/.dotfiles（devbox.json 中的 scripts 需要这些文件）
		if [[ -d "$HOME/.dotfiles" ]]; then
			rm -rf "$HOME/.dotfiles"
		fi
		cp -r "$dotfiles_dir" "$HOME/.dotfiles"

		# 清理不需要的文件
		rm -rf "$HOME/.dotfiles/.git" 2>/dev/null || true

		print_info "Dotfiles 已复制到 ~/.dotfiles/"
		print_info "运行 'cd ~/.dotfiles && devbox shell' 进入开发环境"
	fi
}

# ========================================
# 主函数
# ========================================
main() {
	# 解析参数
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--use-sudo)
			USE_SUDO="true"
			shift
			;;
		--skip-vscode)
			SKIP_VSCODE="true"
			shift
			;;
		--dotfiles-only)
			DOTFILES_ONLY="true"
			shift
			;;
		--branch)
			DOTFILES_BRANCH="$2"
			shift 2
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
	setup_logging "$@"

	local os
	os=$(detect_os)

	print_header "=========================================="
	print_header "🚀 Dotfiles 安装脚本 v${DOTFILES_VERSION}"
	print_header "=========================================="
	print_info "操作系统: $os"
	print_info "架构: $(detect_arch)"
	print_info "用户: $(whoami)"
	print_info "=========================================="
	echo ""

	# 检查 git
	if ! command -v git &>/dev/null && [[ "$os" != "macos" ]]; then
		print_error "需要 git，请先安装"
		exit 1
	fi

	# 检查 curl
	if ! command -v curl &>/dev/null; then
		print_error "需要 curl，请先安装"
		exit 1
	fi

	# 克隆仓库
	local dotfiles_dir
	dotfiles_dir=$(clone_dotfiles)

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

	# 初始化 Devbox 环境
	if [[ "$os" == "linux" && "$DOTFILES_ONLY" != "true" ]]; then
		initialize_devbox "$dotfiles_dir"
	fi

	# 完成
	print_success "=========================================="
	print_success "✅ 安装完成！"
	print_success "=========================================="
	print_info "📝 安装日志: $LOG_FILE"
	echo ""

	if [[ "$os" == "linux" && "$DOTFILES_ONLY" != "true" ]]; then
		print_info "下一步："
		print_info "1. 重新加载 shell: source ~/.zshrc"
		print_info "2. 进入项目目录运行: devbox shell"
		print_info "   （包装脚本会自动处理 nix 环境）"
		echo ""
	fi

	print_info "重新加载 shell 以应用配置:"
	print_info "  exec zsh -l"
}

main "$@"
