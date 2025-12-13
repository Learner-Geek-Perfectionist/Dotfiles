#!/bin/bash
# 工具函数库
# 所有脚本共用的函数和常量

# ========================================
# 颜色配置（强制颜色输出，即使在重定向场景下）
# ========================================
export CLICOLOR_FORCE=1

# 确保 TERM 有值（tput 需要）
export TERM="${TERM:-xterm-256color}"

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export PURPLE='\033[0;35m'
export DIM='\033[2m'
export BOLD='\033[1m'
export WHITE='\033[1;37m'
export NC='\033[0m'

# ========================================
# 版本信息和日志配置
# ========================================
export DOTFILES_VERSION="${DOTFILES_VERSION:-5.0.0}"
# 日志目录和文件可以被外部脚本覆盖（install/uninstall 使用不同子目录）
export DOTFILES_LOG_DIR="${DOTFILES_LOG_DIR:-/tmp/dotfiles-logs-$(whoami)}"
export DOTFILES_LOG="${DOTFILES_LOG:-$DOTFILES_LOG_DIR/dotfiles-$(whoami)-$(date '+%Y%m%d-%H%M%S').log}"

# 确保日志目录存在（任何 source 此文件的脚本都会自动创建）
mkdir -p "$DOTFILES_LOG_DIR"

# ========================================
# 检测是否有 sudo 权限
# 返回值:
#   0 - 有 sudo 权限（root / 免密 sudo / 在 sudo 组中）
#   1 - 无 sudo 权限或无 sudo 命令
#
# 使用场景:
#   - has_sudo: 用于判断用户是否有 sudo 权限（可能需要密码输入）
#   - has_sudo_nopasswd: 用于非交互式脚本，仅检查免密 sudo
# ========================================
has_sudo() {
	[[ $EUID -eq 0 ]] && return 0                              # root 用户
	command -v sudo &>/dev/null || return 1                    # 无 sudo 命令
	sudo -n true 2>/dev/null && return 0                       # 免密 sudo
	# 检查用户是否在 sudo/wheel/admin 组中（有 sudo 权限但需要密码）
	groups 2>/dev/null | grep -qwE 'sudo|wheel|admin' && return 0
	return 1
}

# 检测是否有免密 sudo 权限（适用于非交互式脚本，如 curl | bash）
has_sudo_nopasswd() {
	[[ $EUID -eq 0 ]] && return 0                              # root 用户
	command -v sudo &>/dev/null || return 1                    # 无 sudo 命令
	sudo -n true 2>/dev/null                                   # 免密 sudo
}

# ========================================
# 统一日志输出函数
# - stdout 和日志文件都保留 ANSI 颜色
# ========================================
_log() {
	local level="$1" prefix="$2" color="$3" msg="$4"
	local output
	# 格式: [LEVEL] prefix message
	if [[ -n "$prefix" ]]; then
		output="${color}${prefix} ${msg}${NC}"
	else
		output="${color}[${level}] ${msg}${NC}"
	fi
	echo -e "$output"
	echo -e "$output" >>"$DOTFILES_LOG"
}

# ========================================
# 运行命令并同时输出到终端和日志（使用 script 伪造 TTY 保留进度条）
# 支持复杂引号命令，如: _run_and_log zsh -c "ZINIT_SYNC=1 source '~/.zshrc'"
# ========================================
_run_and_log() {
	if [[ "$(uname)" == "Darwin" ]]; then
		# macOS: script -q -a logfile command args...
		script -q -a "$DOTFILES_LOG" "$@"
	else
		# Linux: 用 printf %q 正确转义每个参数，保留引号
		script -q -a "$DOTFILES_LOG" -c "$(printf '%q ' "$@")"
	fi
}

# ========================================
# 输出空行到终端和日志
# ========================================
_echo_blank() {
	echo ""
	echo "" >>"$DOTFILES_LOG"
}

# ========================================
# 打印函数（终端保留颜色，日志去除颜色）
# ========================================
print_info() { _log "INFO" "" "$CYAN" "$1"; }
print_success() { _log "INFO" "✓" "$GREEN" "$1"; }
print_warn() { _log "WARN" "⚠" "$YELLOW" "$1"; }
print_error() { _log "ERROR" "✗" "$RED" "$1"; }
print_header() { _log "INFO" "" "$BLUE" "$1"; }

# 次要信息（灰色，无前缀，带缩进）
print_dim() {
	local msg="$1"
	local output="${DIM}   ${msg}${NC}"
	echo -e "$output"
	echo -e "$output" >>"$DOTFILES_LOG"
}

# 列表项（用于工具列表等）
print_item() {
	local msg="$1"
	local output="${DIM}   • ${msg}${NC}"
	echo -e "$output"
	echo -e "$output" >>"$DOTFILES_LOG"
}

# 计算字符串显示宽度（跨平台，考虑中文/emoji）
_display_width() {
	local str="$1"
	local char_count=${#str}
	local ascii_count
	ascii_count=$(printf '%s' "$str" | LC_ALL=C tr -cd '\0-\177' | wc -c | tr -d ' ')
	echo $((char_count + char_count - ascii_count))
}

# 脚本标题横幅（背景色填充，文字居中）
print_banner() {
	local msg="$1"
	local width=$(tput cols)
	local display_width=$(_display_width "$msg")
	local padding=$(((width - display_width) / 2))
	[[ $padding -lt 0 ]] && padding=0
	local left_pad=$(printf "%${padding}s" "")
	local right_pad=$(printf "%$((width - padding - display_width))s" "")
	[[ ${#right_pad} -lt 0 ]] && right_pad=""
	local output="\033[45m${left_pad}${msg}${right_pad}\033[0m"
	echo -e "$output"
	echo -e "$output" >>"$DOTFILES_LOG"
}

# 步骤标题（轻量箭头样式）
print_section() {
	local title="$1"
	local output="${BOLD}${WHITE}▶ ${title}${NC}"
	echo ""
	echo -e "$output"
	echo "" >>"$DOTFILES_LOG"
	echo -e "$output" >>"$DOTFILES_LOG"
}

# 分隔线（仅用于重要分隔）
print_divider() {
	local width=$(tput cols)
	local line
	printf -v line "%*s" "$width" ""
	line="${line// /─}"
	echo -e "${DIM}${line}${NC}"
	echo "$line" >>"$DOTFILES_LOG"
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
