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
# 统一日志输出函数
# - stdout: 带颜色
# - 日志文件: 无颜色
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
	echo -e "$output" | _strip_ansi >>"$DOTFILES_LOG"
}

# ========================================
# 运行命令并同时输出到终端和日志（日志去除颜色）
# ========================================
_run_and_log() {
	"$@" 2>&1 | while IFS= read -r line; do
		echo "$line"
		echo "$line" | _strip_ansi >>"$DOTFILES_LOG"
	done
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
print_step() { _log "DEBUG" "→" "$PURPLE" "$1"; }

# 脚本标题横幅（背景色填充，文字居中）
print_banner() {
	local msg="$1"
	local width=$(tput cols)
	# 计算显示宽度（wc -L 考虑宽字符）
	local display_width=$(echo -n "$msg" | wc -L | tr -d ' ')
	local padding=$(((width - display_width) / 2))
	local left_pad=$(printf "%${padding}s" "")
	local right_pad=$(printf "%$((width - padding - display_width))s" "")
	# 终端：带紫色背景
	echo -e "\033[45m${left_pad}${msg}${right_pad}\033[0m"
	# 日志：纯文本居中
	echo "${left_pad}${msg}${right_pad}" >>"$DOTFILES_LOG"
}

# 步骤分隔线（无 [INFO] 前缀）
print_section() {
	local title="$1"
	local width=$(tput cols)
	local line
	printf -v line "%*s" "$width" ""
	line="${line// /━}"
	# 终端：带颜色
	echo -e "${PURPLE}${line}${NC}"
	echo -e "${PURPLE}$(printf '%*s' $(((${#title} + width) / 2)) "$title")${NC}"
	echo -e "${PURPLE}${line}${NC}"
	# 日志：纯文本
	echo "$line" >>"$DOTFILES_LOG"
	echo "$(printf '%*s' $(((${#title} + width) / 2)) "$title")" >>"$DOTFILES_LOG"
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
