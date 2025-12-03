#!/bin/bash
# 工具函数库
# 所有脚本共用的函数和常量

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
export DOTFILES_VERSION="${DOTFILES_VERSION:-4.0.0}"
export DOTFILES_LOG="${DOTFILES_LOG:-/tmp/dotfiles-install-$(whoami).log}"

# ========================================
# 打印函数
# ========================================
print_info() { echo -e "${CYAN}$1${NC}"; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_warn() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_header() { echo -e "${BLUE}$1${NC}"; }
print_step() { echo -e "${PURPLE}$1${NC}"; }

# 带边框的消息
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
	aarch64 | arm64) echo "aarch64" ;;
	*) echo "$(uname -m)" ;;
	esac
}
