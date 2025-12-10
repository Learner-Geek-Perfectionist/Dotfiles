#!/bin/bash
# 工具函数库
# 所有脚本共用的函数和常量

# ========================================
# 颜色配置（强制颜色输出，即使在重定向场景下）
# ========================================
export CLICOLOR_FORCE=1

# 确保 TERM 有值（tput 需要）
export TERM="${TERM:-xterm}"

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
# 版本信息和日志配置
# ========================================
export DOTFILES_VERSION="${DOTFILES_VERSION:-5.0.0}"
# 日志目录和文件可以被外部脚本覆盖（install/uninstall 使用不同子目录）
export DOTFILES_LOG_DIR="${DOTFILES_LOG_DIR:-/tmp/dotfiles-logs}"
export DOTFILES_LOG="${DOTFILES_LOG:-$DOTFILES_LOG_DIR/dotfiles-$(whoami)-$(date '+%Y%m%d-%H%M%S').log}"

# 确保日志目录存在（任何 source 此文件的脚本都会自动创建）
mkdir -p "$DOTFILES_LOG_DIR"

# ========================================
# 检测 gum 是否可用
# ========================================
_has_gum() {
	command -v gum &>/dev/null
}

# ========================================
# 检测是否有 sudo 权限（而非 sudo 命令是否存在）
# ========================================
has_sudo() {
	# 如果是 root 用户，不需要 sudo
	[[ $EUID -eq 0 ]] && return 0
	# 检查 sudo 命令是否存在
	command -v sudo &>/dev/null || return 1
	# 检查是否有 sudo 权限（非交互式测试）
	sudo -n true 2>/dev/null
}

# ========================================
# 去除 ANSI 颜色代码（用于写入日志）
# ========================================
_strip_ansi() {
	sed 's/\x1b\[[0-9;]*m//g'
}

# ========================================
# 打印函数（终端保留颜色，日志去除颜色）
# ========================================
print_info() {
	local msg
	if _has_gum; then
		msg=$(gum log --level info --level.foreground 14 --message.foreground 14 "$1" 2>&1)
	else
		msg=$(echo -e "${CYAN}$1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
}

print_success() {
	local msg
	if _has_gum; then
		msg=$(gum log --level info --prefix "✓" --level.foreground 10 --prefix.foreground 10 --message.foreground 10 "$1" 2>&1)
	else
		msg=$(echo -e "${GREEN}✓ $1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
}

print_warn() {
	local msg
	if _has_gum; then
		msg=$(gum log --level warn --level.foreground 11 --message.foreground 11 "$1" 2>&1)
	else
		msg=$(echo -e "${YELLOW}⚠ $1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
}

print_error() {
	local msg
	if _has_gum; then
		msg=$(gum log --level error --level.foreground 9 --message.foreground 9 "$1" 2>&1)
	else
		msg=$(echo -e "${RED}✗ $1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
}

print_header() {
	local msg
	if _has_gum; then
		msg=$(gum style --bold --foreground 212 "$1" 2>&1)
	else
		msg=$(echo -e "${BLUE}$1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
}

print_step() {
	local msg
	if _has_gum; then
		msg=$(gum log --level debug --prefix "→" --level.foreground 13 --prefix.foreground 13 --message.foreground 13 "$1" 2>&1)
	else
		msg=$(echo -e "${PURPLE}→ $1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
}

print_section() {
	local title="$1"
	local msg
	if _has_gum; then
		local width
		width=$(tput cols)

		local line
		printf -v line "%*s" "$width" ""
		line="${line// /━}"

		msg=$(gum style --foreground 13 "$line" 2>&1)
		echo "$msg"
		echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
		msg=$(gum style --width "$width" --align center --foreground 13 "$title" 2>&1)
		echo "$msg"
		echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
		msg=$(gum style --foreground 13 "$line" 2>&1)
		echo "$msg"
		echo "$msg" | _strip_ansi >> "$DOTFILES_LOG"
	else
		print_step "========================================"
		print_step "$title"
		print_step "========================================"
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
