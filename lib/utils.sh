#!/bin/bash
# 工具函数库 — 所有脚本共用的函数和常量
# 注意: 本文件作为库被 source，不设置 set -e 以避免影响调用方控制流
# 约定: return 0 = 已处理（含条件不满足），return 1 = 真正的错误（调用方需 if/|| 保护）

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

# 确保日志目录存在并限制权限（仅属主可读写，防止多用户系统泄漏）
mkdir -p "$DOTFILES_LOG_DIR"
chmod 700 "$DOTFILES_LOG_DIR"

# ========================================
# 检测是否有 sudo 权限
# 返回值:
#   0 - 有 sudo 权限（root / 免密 sudo / 在 sudo 组中）
#   1 - 无 sudo 权限或无 sudo 命令
#
# 使用场景:
#   - has_sudo: 用于判断用户是否有 sudo 权限（可能需要密码输入）
# ========================================
has_sudo() {
	[[ $EUID -eq 0 ]] && return 0                              # root 用户
	command -v sudo &>/dev/null || return 1                    # 无 sudo 命令
	sudo -n true 2>/dev/null && return 0                       # 免密 sudo
	# 检查用户是否在 sudo/wheel/admin 组中（有 sudo 权限但需要密码）
	groups 2>/dev/null | grep -qwE 'sudo|wheel|admin' && return 0
	return 1
}

# ========================================
# 统一日志输出函数
# - stdout 和日志文件都保留 ANSI 颜色
# ========================================
_log() {
	local level="$1" prefix="$2" color="$3" msg="$4"
	local output
	# 格式: 2空格缩进 + [LEVEL]/prefix + message（在 section 标题下形成层次感）
	if [[ -n "$prefix" ]]; then
		output="  ${color}${prefix} ${msg}${NC}"
	else
		output="  ${color}[${level}] ${msg}${NC}"
	fi
	printf '%b\n' "$output"
	printf '%b\n' "$output" >>"$DOTFILES_LOG"
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

# 次要信息（灰色，无前缀，带缩进 — 比 _log 多一级）
print_dim() {
	local msg="$1"
	local output="${DIM}     ${msg}${NC}"
	printf '%b\n' "$output"
	printf '%b\n' "$output" >>"$DOTFILES_LOG"
}

# 列表项（用于工具列表等）
print_item() {
	local msg="$1"
	local output="${DIM}     • ${msg}${NC}"
	printf '%b\n' "$output"
	printf '%b\n' "$output" >>"$DOTFILES_LOG"
}

# 计算字符串显示宽度（跨平台，考虑中文/emoji）
# 注意：Pixi 环境可能覆盖 wc 命令，导致 wc -m 返回字节数
# 使用 LC_ALL=C.UTF-8 bash 强制正确的 UTF-8 字符计数
_display_width() {
	local str="$1"
	# 强制 UTF-8 locale 获取真实字符数（避免 Pixi 环境污染）
	local char_count
	char_count=$(LC_ALL=C.UTF-8 bash -c 'echo ${#1}' _ "$str")
	# ASCII 字符数
	local ascii_count
	ascii_count=$(printf '%s' "$str" | LC_ALL=C tr -cd '\0-\177' | wc -c | tr -d ' ')
	# 非 ASCII 字符数 (中文/emoji 等，显示宽度为 2)
	local non_ascii_count=$((char_count - ascii_count))
	# 显示宽度 = ASCII 字符数 + 非 ASCII 字符数 * 2
	echo $((ascii_count + non_ascii_count * 2))
}

# 脚本标题横幅（背景色填充，文字居中）
print_banner() {
	local msg="$1"
	# 获取终端宽度：优先从 /dev/tty 获取真实宽度，避免 tput 默认值问题
	local width
	# 1. 尝试从 /dev/tty 获取（最可靠，直接查询终端驱动）
	if [[ -e /dev/tty ]]; then
		width=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
	fi
	# 2. 如果失败，尝试 COLUMNS（交互式 shell 中可用）
	[[ -z "$width" || "$width" -le 0 ]] 2>/dev/null && [[ "${COLUMNS:-0}" -gt 0 ]] && width="$COLUMNS"
	# 3. 最后尝试 tput cols
	[[ -z "$width" || "$width" -le 0 ]] 2>/dev/null && width="$(tput cols 2>/dev/null)"
	local display_width=$(_display_width "$msg")
	local padding=$(((width - display_width) / 2))
	[[ $padding -lt 0 ]] && padding=0
	local left_pad=$(printf "%${padding}s" "")
	local right_pad=$(printf "%$((width - padding - display_width))s" "")
	[[ ${#right_pad} -lt 0 ]] && right_pad=""
	local output="\033[45m${left_pad}${msg}${right_pad}\033[0m"
	printf '%b\n' "$output"
	printf '%b\n' "$output" >>"$DOTFILES_LOG"
}

# 步骤标题（轻量箭头样式）
print_section() {
	local title="$1"
	local output="${BOLD}${WHITE}▶ ${title}${NC}"
	echo ""
	printf '%b\n' "$output"
	echo "" >>"$DOTFILES_LOG"
	printf '%b\n' "$output" >>"$DOTFILES_LOG"
}

# 分隔线（仅用于重要分隔）
print_divider() {
	local width
	[[ "${COLUMNS:-0}" -gt 0 ]] && width="$COLUMNS" || width="$(tput cols 2>/dev/null)"
	[[ -z "$width" || "$width" -le 0 ]] 2>/dev/null && width=80
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

# 检测是否在远程服务器环境（VSCode/Cursor Remote SSH）
is_remote_server() {
	[[ -n "$VSCODE_IPC_HOOK_CLI" ]] && [[ -n "$SSH_CONNECTION" ]]
}

# ========================================
# GitHub Release 版本管理
# ========================================

# 获取 GitHub 仓库最新 release 的 tag_name
# 参数: $1 = owner/repo (例如 fwcd/kotlin-language-server)
github_latest_release() {
	local repo="$1"
	curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
		| jq -r '.tag_name // empty' 2>/dev/null
}

# 检查 GitHub Release 是否有更新
# 参数: $1=显示名 $2=owner/repo $3=版本记录目录
# 输出: 设置 _GITHUB_LATEST（最新版本号）供调用方使用
# 返回: 0=有更新 1=已最新或检查失败（调用方应 return 0 跳过安装）
check_github_update() {
	local name="$1" repo="$2" install_dir="$3"

	_GITHUB_LATEST=$(github_latest_release "$repo") || true
	if [[ -z "$_GITHUB_LATEST" ]]; then
		print_warn "$name: 无法获取最新版本，跳过"
		return 1
	fi

	local local_ver
	local_ver=$(get_local_version "$install_dir")
	if [[ "$local_ver" == "$_GITHUB_LATEST" ]]; then
		print_success "$name 已是最新版本 ($_GITHUB_LATEST)"
		return 1
	fi

	print_dim "版本: ${local_ver:-无} -> $_GITHUB_LATEST"
	return 0
}

# 获取本地已安装的版本
# 参数: $1 = 安装目录（版本文件存储在 $1/.version）
get_local_version() {
	local version_file="$1/.version"
	if [[ -f "$version_file" ]]; then
		<"$version_file" read -r version && echo "$version"
	else
		echo ""
	fi
}

# 保存本地版本记录
# 参数: $1 = 安装目录, $2 = 版本号
save_local_version() {
	mkdir -p "$1"
	echo "$2" >"$1/.version"
}

# ========================================
# 从 URL 下载并解压到指定目录
# 参数: $1=下载URL $2=目标目录 $3=解压格式(tar.gz|zip|gz)
# 返回: 0=成功 1=失败
# 成功后目标目录会被替换为新内容
# ========================================
download_and_extract() {
	local url="$1" dest="$2" format="${3:-tar.gz}"
	local tmp_dir filename
	tmp_dir=$(mktemp -d)
	filename=$(basename "$url")

	if ! curl -fsSL "$url" -o "$tmp_dir/$filename"; then
		rm -rf "$tmp_dir"
		return 1
	fi

	case "$format" in
		tar.gz)
			mkdir -p "$tmp_dir/staging"
			if ! tar -xzf "$tmp_dir/$filename" -C "$tmp_dir/staging"; then
				rm -rf "$tmp_dir"
				return 1
			fi
			rm -rf "$dest"
			mv "$tmp_dir/staging" "$dest"
			;;
		zip)
			mkdir -p "$tmp_dir/staging"
			if ! unzip -qo "$tmp_dir/$filename" -d "$tmp_dir/staging"; then
				rm -rf "$tmp_dir"
				return 1
			fi
			rm -rf "$dest"
			mv "$tmp_dir/staging" "$dest"
			;;
		gz)
			local base="${filename%.gz}"
			if ! gunzip "$tmp_dir/$filename"; then
				rm -rf "$tmp_dir"
				return 1
			fi
			chmod +x "$tmp_dir/$base"
			mkdir -p "$(dirname "$dest")"
			mv "$tmp_dir/$base" "$dest"
			;;
	esac

	rm -rf "$tmp_dir"
	return 0
}

# ========================================
# 检测编辑器真实类型（code 命令可能实际是 Cursor）
# 参数: $1 = 命令名（code 或 cursor）
# 输出: "vscode" 或 "cursor"
# ========================================
# ========================================
# 获取 Rust 风格的平台 triple（如 aarch64-apple-darwin）
# 参数: $1 = OS (macos/linux), $2 = ARCH (aarch64/x86_64)
# ========================================
get_platform_triple() {
	local os="$1" arch="$2"
	if [[ "$os" == "macos" ]]; then
		echo "${arch}-apple-darwin"
	else
		echo "${arch}-unknown-linux-gnu"
	fi
}

detect_editor_type() {
	local cmd="$1"
	if "$cmd" --help 2>&1 | head -1 | grep -qi "cursor"; then
		echo "cursor"
	else
		echo "vscode"
	fi
}
