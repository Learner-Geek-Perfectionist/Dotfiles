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
# 运行命令并同时输出到终端和日志（使用 script 伪造 PTY 保留进度条/颜色）
# 不用 tee/管道：很多程序检测到非 TTY 会关闭颜色和进度条
# 支持复杂引号命令，如: _run_and_log zsh -c "ZINIT_SYNC=1 source '~/.zshrc'"
# ========================================
_run_and_log() {
	if [[ "$(uname)" == "Darwin" ]]; then
		# macOS: script -q -a logfile command args...
		script -q -a "$DOTFILES_LOG" "$@"
	else
		# Linux script 不支持直接传命令参数，必须用 -c "string"
		# printf %q 对每个参数做 shell 转义后拼接，经 -c 重新解析可还原原始参数
		# 注：实际调用参数均为 ASCII 路径/命令，不受 locale 边缘情况影响
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

# 脚本标题横幅（背景色填充，文字居中）
print_banner() {
	local msg="$1"
	local width=$(tput cols 2>/dev/null || echo 80)
	# 显示宽度：非 ASCII（中文/emoji）占 2 列，纯 bash 无需 fork
	local ascii="${msg//[^[:ascii:]]/}"
	local dw=$(( 2 * ${#msg} - ${#ascii} ))
	local pad=$(( (width - dw) / 2 ))
	[[ $pad -lt 0 ]] && pad=0
	local right=$(( width - pad - dw ))
	[[ $right -lt 0 ]] && right=0
	local output="\033[45m$(printf "%${pad}s")${msg}$(printf "%${right}s")\033[0m"
	printf '%b\n' "$output"
	printf '%b\n' "$output" >>"$DOTFILES_LOG"
}

# 安装汇总报告（通用）
# 用法: print_install_summary <label> <installed> <skipped> <failed>
print_install_summary() {
	local label="$1" installed="$2" skipped="$3" failed="$4"
	if [[ $installed -eq 0 && $failed -eq 0 ]]; then
		print_success "所有${label}已就绪 ($skipped 个)"
	elif [[ $failed -eq 0 ]]; then
		print_success "${label}: 新增 $installed, 跳过 $skipped"
	else
		print_warn "${label}: 新增 $installed, 跳过 $skipped, 失败 $failed"
	fi
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
	[[ -n "${VSCODE_IPC_HOOK_CLI:-}" ]] && [[ -n "${SSH_CONNECTION:-}" ]]
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

# ========================================
# 检测编辑器真实类型（code 命令可能实际是 Cursor）
# 参数: $1 = 命令路径或命令名
# 输出: "vscode" 或 "cursor"
# ========================================
detect_editor_type() {
	local cmd="$1"
	if "$cmd" --help 2>&1 | head -1 | grep -qi "cursor"; then
		echo "cursor"
	else
		echo "vscode"
	fi
}

# 枚举可用的编辑器 CLI 路径
# 优先使用 PATH，其次回退到 macOS App bundle 内置 CLI
editor_cli_candidates() {
	local candidate

	if command -v code &>/dev/null; then
		command -v code
	fi
	if command -v cursor &>/dev/null; then
		command -v cursor
	fi

	if [[ "$(uname -s)" == "Darwin" ]]; then
		for candidate in \
			"/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
			"$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
			"/Applications/Cursor.app/Contents/Resources/app/bin/cursor" \
			"$HOME/Applications/Cursor.app/Contents/Resources/app/bin/cursor"; do
			[[ -x "$candidate" ]] && echo "$candidate"
		done
	fi
}

# 按真实类型查找编辑器 CLI
# 参数: $1 = vscode 或 cursor
find_editor_cli() {
	local target_type="$1"
	local candidate resolved_type bin_path
	local seen_paths=""

	while IFS= read -r candidate; do
		[[ -z "$candidate" ]] && continue
		bin_path=$(realpath "$candidate" 2>/dev/null || echo "$candidate")
		case $'\n'"$seen_paths" in
		*$'\n'"$bin_path"$'\n'*) continue ;;
		esac
		seen_paths+="${bin_path}"$'\n'

		resolved_type=$(detect_editor_type "$candidate" 2>/dev/null || true)
		[[ "$resolved_type" == "$target_type" ]] || continue
		echo "$candidate"
		return 0
	done < <(editor_cli_candidates)

	return 1
}

# ========================================
# macOS pmset 状态保存/恢复
# ========================================
pmset_state_file() {
	echo "$HOME/.local/state/dotfiles/macos-pmset.env"
}

save_pmset_state() {
	command -v pmset &>/dev/null || return 1

	local state_file tmp
	state_file="$(pmset_state_file)"
	[[ -f "$state_file" ]] && return 0

	mkdir -p "$(dirname "$state_file")"
	tmp="$(mktemp)"

	{
		echo "# Saved by Dotfiles install on $(date)"
		pmset -g custom | awk '
			/^Battery Power:/ { scope="BATTERY"; next }
			/^AC Power:/ { scope="AC"; next }
			/^UPS Power:/ { scope="UPS"; next }
			($1 == "sleep" || $1 == "tcpkeepalive") && scope != "" {
				printf "%s_%s=%s\n", scope, toupper($1), $2
			}
		'
	} >"$tmp" || {
		rm -f "$tmp"
		return 1
	}

	if ! grep -q '^[A-Z_]\+=' "$tmp"; then
		rm -f "$tmp"
		return 1
	fi

	chmod 600 "$tmp"
	mv "$tmp" "$state_file"
	return 0
}

restore_pmset_state() {
	command -v pmset &>/dev/null || return 1
	has_sudo || return 1

	local state_file
	state_file="$(pmset_state_file)"
	[[ -f "$state_file" ]] || return 1

	# shellcheck disable=SC1090
	source "$state_file"

	local restored=0
	local scope_flag scope_name sleep_value tcpkeepalive_value
	for scope_flag in "-b" "-c" "-u"; do
		case "$scope_flag" in
		-b)
			scope_name="电池"
			sleep_value="${BATTERY_SLEEP:-}"
			tcpkeepalive_value="${BATTERY_TCPKEEPALIVE:-}"
			;;
		-c)
			scope_name="交流电"
			sleep_value="${AC_SLEEP:-}"
			tcpkeepalive_value="${AC_TCPKEEPALIVE:-}"
			;;
		-u)
			scope_name="UPS"
			sleep_value="${UPS_SLEEP:-}"
			tcpkeepalive_value="${UPS_TCPKEEPALIVE:-}"
			;;
		esac

		[[ -z "$sleep_value" && -z "$tcpkeepalive_value" ]] && continue
		[[ -n "$sleep_value" ]] && sudo pmset "$scope_flag" sleep "$sleep_value"
		[[ -n "$tcpkeepalive_value" ]] && sudo pmset "$scope_flag" tcpkeepalive "$tcpkeepalive_value"
		print_dim "✓ 已恢复 ${scope_name} pmset 配置"
		restored=1
	done

	[[ $restored -eq 1 ]]
}

# ========================================
# Pixi manifest 托管状态
# ========================================
pixi_manifest_path() {
	echo "$HOME/pixi.toml"
}

pixi_lock_path() {
	echo "$HOME/pixi.lock"
}

pixi_manifest_state_file() {
	echo "$HOME/.local/state/dotfiles/pixi-manifest.env"
}

file_fingerprint() {
	local file="$1"
	[[ -f "$file" ]] || return 1

	if command -v shasum &>/dev/null; then
		shasum -a 256 "$file" | awk '{print $1}'
	elif command -v sha256sum &>/dev/null; then
		sha256sum "$file" | awk '{print $1}'
	elif command -v openssl &>/dev/null; then
		openssl dgst -sha256 "$file" | awk '{print $NF}'
	elif command -v cksum &>/dev/null; then
		cksum "$file" | awk '{print $1 "-" $2}'
	else
		return 1
	fi
}

read_managed_pixi_manifest_hash() {
	local state_file
	state_file="$(pixi_manifest_state_file)"
	[[ -f "$state_file" ]] || return 1
	awk -F= '/^MANAGED_SHA256=/{print $2; exit}' "$state_file"
}

write_managed_pixi_manifest_state() {
	local managed_hash="$1"
	local state_file tmp
	state_file="$(pixi_manifest_state_file)"

	mkdir -p "$(dirname "$state_file")"
	tmp="$(mktemp)"
	{
		echo "# Managed by Dotfiles on $(date)"
		echo "MANAGED_SHA256=$managed_hash"
	} >"$tmp"
	chmod 600 "$tmp"
	mv "$tmp" "$state_file"
}

clear_managed_pixi_manifest_state() {
	rm -f "$(pixi_manifest_state_file)"
}

pixi_manifest_is_managed() {
	local manifest="${1:-$(pixi_manifest_path)}"
	local current_hash managed_hash

	[[ -f "$manifest" ]] || return 1
	current_hash=$(file_fingerprint "$manifest") || return 1
	managed_hash=$(read_managed_pixi_manifest_hash) || return 1
	[[ -n "$managed_hash" && "$current_hash" == "$managed_hash" ]]
}

# 同步 Dotfiles 托管的 pixi.toml。
# - 未存在时：创建并纳入托管
# - 仍处于托管状态时：允许覆盖更新
# - 已被用户修改时：自动脱管并跳过覆盖
# - 与仓库内容重新一致时：重新纳入托管
sync_managed_pixi_manifest() {
	local src="$1"
	local dest="${2:-$(pixi_manifest_path)}"
	local src_hash dest_hash managed_hash

	[[ -f "$src" ]] || return 1
	src_hash=$(file_fingerprint "$src") || return 1
	managed_hash=$(read_managed_pixi_manifest_hash 2>/dev/null || true)

	if [[ ! -f "$dest" ]]; then
		mkdir -p "$(dirname "$dest")"
		cp "$src" "$dest"
		write_managed_pixi_manifest_state "$src_hash"
		print_dim "部署托管配置: ~/pixi.toml"
		return 0
	fi

	dest_hash=$(file_fingerprint "$dest") || return 1

	if [[ "$dest_hash" == "$src_hash" ]]; then
		write_managed_pixi_manifest_state "$src_hash"
		print_dim "pixi.toml 与仓库一致，保持托管"
		return 0
	fi

	if [[ -n "$managed_hash" && "$dest_hash" == "$managed_hash" ]]; then
		cp "$src" "$dest"
		write_managed_pixi_manifest_state "$src_hash"
		print_dim "更新托管配置: ~/pixi.toml"
		return 0
	fi

	if [[ -n "$managed_hash" ]]; then
		clear_managed_pixi_manifest_state
		print_warn "检测到本地修改的 ~/pixi.toml，已脱管，跳过覆盖"
	else
		print_warn "检测到用户自维护的 ~/pixi.toml，跳过覆盖"
	fi

	return 3
}
