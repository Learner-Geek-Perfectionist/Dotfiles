#!/bin/bash
# 工具函数库 - 简化版
# 主要用于 macOS 安装和通用工具函数

# ========================================
# 颜色定义
# ========================================
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export PURPLE='\033[0;35m'
export MAGENTA='\033[0;35m'
export ORANGE='\033[0;93m'
export NC='\033[0m'

# ========================================
# 版本信息
# ========================================
export DOTFILES_VERSION="${DOTFILES_VERSION:-2.0.0}"
export DOTFILES_LOG="${DOTFILES_LOG:-/tmp/dotfiles-install-$(whoami).log}"

# ========================================
# 打印函数
# ========================================
print_info() { echo -e "${CYAN}$1${NC}"; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_warn() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_header() { echo -e "${BLUE}$1${NC}"; }

# 带边框的消息（简化版，不依赖 gum）
print_msg() {
	local msg="$1"
	local color="${2:-$CYAN}"
	local width=60
	local border=$(printf '=%.0s' $(seq 1 $width))

	echo -e "${color}${border}${NC}"
	echo -e "${color}  ${msg}${NC}"
	echo -e "${color}${border}${NC}"
}

# ========================================
# 日志函数
# ========================================
log_msg() {
	local msg="$1"
	local show_stdout="${2:-true}"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo "[$timestamp] $msg" >>"$DOTFILES_LOG"

	if [[ "$show_stdout" == "true" ]]; then
		echo -e "$msg"
	fi
}

log_error() { log_msg "${RED}ERROR: $1${NC}"; }
log_success() { log_msg "${GREEN}$1${NC}"; }

# ========================================
# 检测函数
# ========================================
detect_os() {
	case "$(uname -s)" in
	Darwin) echo "macos" ;;
	Linux) echo "linux" ;;
	*) echo "unknown" ;;
	esac
}

detect_arch() {
	case "$(uname -m)" in
	x86_64) echo "x86_64" ;;
	aarch64) echo "aarch64" ;;
	arm64) echo "aarch64" ;;
	*) echo "$(uname -m)" ;;
	esac
}

detect_package_manager() {
	if command -v brew &>/dev/null; then
		echo "brew"
	elif command -v apt &>/dev/null; then
		echo "apt"
	elif command -v dnf &>/dev/null; then
		echo "dnf"
	else
		echo "unsupported"
	fi
}

# ========================================
# Homebrew 包安装（macOS）
# ========================================
install_packages() {
	local package_group_name="$1"
	local brew_package_type="${2:-formula}"

	if [[ -z "$package_group_name" ]]; then
		print_error "未指定包组名称"
		return 1
	fi

	local pkg_manager
	pkg_manager=$(detect_package_manager)

	if [[ "$pkg_manager" != "brew" ]]; then
		print_warn "此函数仅支持 Homebrew (macOS)"
		print_warn "Linux 请使用 devbox"
		return 1
	fi

	# 获取包列表
	local packages=()
	eval "packages=(\"\${${package_group_name}[@]}\")"

	if [[ ${#packages[@]} -eq 0 ]]; then
		print_warn "包组 ${package_group_name} 为空，跳过"
		return 0
	fi

	# 获取已安装的包
	local installed_packages=""
	if [[ "$brew_package_type" == "cask" ]]; then
		installed_packages="$(brew list --cask 2>/dev/null || true)"
	else
		installed_packages="$(brew list --formula 2>/dev/null || true)"
	fi

	# 筛选未安装的包
	local uninstalled_packages=()
	for package in "${packages[@]}"; do
		[[ -z "$package" ]] && continue
		if ! grep -Fqx "$package" <<<"$installed_packages"; then
			uninstalled_packages+=("$package")
		fi
	done

	if [[ ${#uninstalled_packages[@]} -eq 0 ]]; then
		print_success "✓ 包组 $package_group_name 中的所有包已安装"
		return 0
	fi

	print_info "安装 ${#uninstalled_packages[@]} 个包..."
	for package in "${uninstalled_packages[@]}"; do
		echo "  - $package"
	done

	if [[ "$brew_package_type" == "cask" ]]; then
		brew install --cask "${uninstalled_packages[@]}"
	else
		brew install "${uninstalled_packages[@]}"
	fi

	print_success "✓ 包安装完成"
}

# ========================================
# 字体安装
# ========================================
install_fonts() {
	# 非交互模式跳过
	if [[ ! -t 0 ]]; then
		print_warn "跳过字体安装（非交互模式）"
		return 0
	fi

	echo -ne "${GREEN}是否需要下载字体？(y/n): ${NC}"
	read -r download_confirm

	if [[ "$download_confirm" != 'y' ]]; then
		print_info "跳过字体下载"
		return 0
	fi

	local font_source="/tmp/Fonts/"

	print_info "下载字体..."
	git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Fonts.git "$font_source"

	local font_dest
	if [[ "$(uname)" == "Darwin" ]]; then
		font_dest="$HOME/Library/Fonts"
	else
		font_dest="$HOME/.local/share/fonts/"
	fi

	print_info "安装字体到 $font_dest..."
	mkdir -p "$font_dest"

	find "$font_source" -type f \( -iname "*.ttf" -o -iname "*.otf" \) ! -iname "README*" \
		-exec cp {} "$font_dest" \;

	# Linux 刷新字体缓存
	if [[ "$(uname)" != "Darwin" ]]; then
		fc-cache -fv 2>/dev/null || true
	fi

	print_success "✓ 字体安装完成"

	# 清理
	rm -rf "$font_source"
}
