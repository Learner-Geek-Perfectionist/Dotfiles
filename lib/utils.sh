#!/bin/bash
# 工具函数库
# 所有脚本共用的函数和常量

# ========================================
# 颜色配置（强制颜色输出，即使在重定向场景下）
# ========================================
export CLICOLOR_FORCE=1

# Fallback 颜色定义（当 gum 不可用时使用）
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
# 检测 gum 是否可用
# ========================================
_has_gum() {
	command -v gum &>/dev/null
}

# ========================================
# 打印函数（自动选择 gum 或 fallback）
# ========================================
print_info() {
	if _has_gum; then
		gum log --level info --level.foreground 14 --message.foreground 14 "$1" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		echo -e "${CYAN}$1${NC}" | tee -a "$DOTFILES_LOG"
	fi
}

print_success() {
	if _has_gum; then
		gum log --level info --prefix "✓" --level.foreground 10 --prefix.foreground 10 --message.foreground 10 "$1" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		echo -e "${GREEN}✓ $1${NC}" | tee -a "$DOTFILES_LOG"
	fi
}

print_warn() {
	if _has_gum; then
		gum log --level warn --level.foreground 11 --message.foreground 11 "$1" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$DOTFILES_LOG"
	fi
}

print_error() {
	if _has_gum; then
		gum log --level error --level.foreground 9 --message.foreground 9 "$1" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		echo -e "${RED}✗ $1${NC}" | tee -a "$DOTFILES_LOG"
	fi
}

print_header() {
	if _has_gum; then
		gum style --bold --foreground 212 "$1" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		echo -e "${BLUE}$1${NC}" | tee -a "$DOTFILES_LOG"
	fi
}

print_step() {
	if _has_gum; then
		gum log --level debug --prefix "→" --level.foreground 13 --prefix.foreground 13 --message.foreground 13 "$1" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		echo -e "${PURPLE}→ $1${NC}" | tee -a "$DOTFILES_LOG"
	fi
}

print_section() {
	local title="$1"
	if _has_gum; then
		local width
		width=$(tput cols 2>/dev/null || echo 80)
		
		local line
		printf -v line "%*s" "$width" ""
		line="${line// /━}"
		
		gum style --foreground 13 "$line" 2>&1 | tee -a "$DOTFILES_LOG"
		gum style --width "$width" --align center --foreground 13 "$title" 2>&1 | tee -a "$DOTFILES_LOG"
		gum style --foreground 13 "$line" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		print_step "========================================"
		print_step "$title"
		print_step "========================================"
	fi
}

# 带边框的消息
print_msg() {
	local msg="$1"
	if _has_gum; then
		gum style --border double --margin "1" --padding "1 2" "$msg" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		local color="${2:-$CYAN}"
		local width=60
		local border=$(printf '=%.0s' $(seq 1 $width))
		echo -e "${color}${border}${NC}" | tee -a "$DOTFILES_LOG"
		echo -e "${color}  ${msg}${NC}" | tee -a "$DOTFILES_LOG"
		echo -e "${color}${border}${NC}" | tee -a "$DOTFILES_LOG"
	fi
}

# ========================================
# 日志函数（同时输出到终端和文件，保留颜色）
# ========================================
log_msg() {
	local msg="$1"
	local show_stdout="${2:-true}"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo -e "[$timestamp] $msg" >>"$DOTFILES_LOG"

	if [[ "$show_stdout" == "true" ]]; then
		echo -e "$msg"
	fi
}

log_error() {
	if _has_gum; then
		gum log --level error "$1" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		log_msg "${RED}ERROR: $1${NC}"
	fi
}

log_success() {
	if _has_gum; then
		gum log --level info --prefix "✓" "$1" 2>&1 | tee -a "$DOTFILES_LOG"
	else
		log_msg "${GREEN}$1${NC}"
	fi
}

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
