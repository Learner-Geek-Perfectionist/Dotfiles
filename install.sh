#!/bin/bash
# Dotfiles 统一安装入口
#
# Linux: Pixi (包管理) + Dotfiles 配置 - 完全 Rootless
# macOS: Homebrew (包管理) + Dotfiles 配置
#
# 支持: Linux (x86_64, aarch64) / macOS (x86_64, arm64)

set -eo pipefail

# ========================================
# 版本和配置
# ========================================
DOTFILES_VERSION="5.0.0"
DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/Learner-Geek-Perfectionist/Dotfiles.git}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-beta}"

# 默认配置
SKIP_VSCODE="${SKIP_VSCODE:-false}"
SKIP_DOTFILES="${SKIP_DOTFILES:-false}"
PIXI_ONLY="${PIXI_ONLY:-false}"
DOTFILES_ONLY="${DOTFILES_ONLY:-false}"
VSCODE_ONLY="${VSCODE_ONLY:-false}"

# 日志目录（日志文件名在参数解析后生成，包含安装模式）
DOTFILES_LOG_DIR="/tmp/dotfiles-logs-$(whoami)/install"

# ========================================
# 工具函数（clone 前必需的最小集合，支持 curl | bash）
# clone 后会 source lib/utils.sh 获取完整函数
# ========================================

# 强制颜色输出（即使在重定向场景下）
export CLICOLOR_FORCE=1

# 确保 TERM 有值且不是 dumb（tput 和进度条需要）
[[ -z "$TERM" || "$TERM" == "dumb" ]] && export TERM="xterm-256color"

# 颜色定义
export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
export BLUE='\033[0;34m' CYAN='\033[0;36m' PURPLE='\033[0;35m' NC='\033[0m'
export DIM='\033[2m' BOLD='\033[1m' WHITE='\033[1;37m'

# 检测是否有 sudo 权限
# 返回 0: root / 免密 sudo / 在 sudo 组中
# 返回 1: 无 sudo 权限或无 sudo 命令
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
	if [[ -n "$prefix" ]]; then
		output="${color}${prefix} ${msg}${NC}"
	else
		output="${color}[${level}] ${msg}${NC}"
	fi
	echo -e "$output"
	# 日志文件可能在参数解析后才设置，避免写入空路径
	[[ -n "$DOTFILES_LOG" ]] && echo -e "$output" >>"$DOTFILES_LOG"
}

# 输出空行到终端和日志
_echo_blank() {
	echo ""
	[[ -n "$DOTFILES_LOG" ]] && echo "" >>"$DOTFILES_LOG"
}

# 打印函数（终端保留颜色，日志去除颜色）
print_info() { _log "INFO" "" "$CYAN" "$1"; }
print_success() { _log "INFO" "✓" "$GREEN" "$1"; }
print_warn() { _log "WARN" "⚠" "$YELLOW" "$1"; }
print_error() { _log "ERROR" "✗" "$RED" "$1"; }
print_header() { _log "INFO" "" "$BLUE" "$1"; }

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
	echo -e "$output"
	[[ -n "$DOTFILES_LOG" ]] && echo -e "$output" >>"$DOTFILES_LOG"
}

# 显示帮助
show_help() {
	cat <<EOF
Dotfiles 安装脚本 v${DOTFILES_VERSION}

用法: curl -fsSL <url> | bash
      bash install.sh [选项]

选项:
    --pixi-only      仅安装 Pixi（跳过 Dotfiles 和 VSCode）
    --dotfiles-only  仅安装 Dotfiles 配置（跳过包管理和 VSCode）
    --vscode-only    仅安装 VSCode/Cursor 插件
    --skip-dotfiles  跳过 Dotfiles 配置
    --skip-vscode    跳过 VSCode 插件安装
    -h, --help       显示帮助
EOF
}

# 设置日志（根据安装模式生成文件名）
setup_logging() {
	mkdir -p "$DOTFILES_LOG_DIR"

	# 根据模式生成日志文件名后缀
	local mode_suffix=""
	if [[ "$PIXI_ONLY" == "true" ]]; then
		mode_suffix="-pixi-only"
	elif [[ "$DOTFILES_ONLY" == "true" ]]; then
		mode_suffix="-dotfiles-only"
	elif [[ "$VSCODE_ONLY" == "true" ]]; then
		mode_suffix="-vscode-only"
	elif [[ "$SKIP_DOTFILES" == "true" && "$SKIP_VSCODE" == "true" ]]; then
		mode_suffix="-skip-dotfiles-vscode"
	elif [[ "$SKIP_DOTFILES" == "true" ]]; then
		mode_suffix="-skip-dotfiles"
	elif [[ "$SKIP_VSCODE" == "true" ]]; then
		mode_suffix="-skip-vscode"
	fi

	DOTFILES_LOG="$DOTFILES_LOG_DIR/dotfiles-install-$(whoami)${mode_suffix}-$(date '+%Y%m%d-%H%M%S').log"
	export DOTFILES_LOG

	echo "=== Dotfiles 安装日志 $(date) ===" >"$DOTFILES_LOG"
}

# 检查并安装依赖
check_dependencies() {
	local missing=()

	# 检查所有依赖
	for cmd in git curl zsh; do
		command -v "$cmd" &>/dev/null || missing+=("$cmd")
	done

	# 如果没有缺失的依赖，直接返回
	if [[ ${#missing[@]} -eq 0 ]]; then
		print_success "依赖检查通过"
		return 0
	fi

	print_warn "缺少依赖: ${missing[*]}"

	# macOS: git 通过 xcode-select 安装
	if [[ "$(uname)" == "Darwin" ]]; then
		for cmd in "${missing[@]}"; do
			if [[ "$cmd" == "git" ]]; then
				xcode-select --install 2>/dev/null
				print_info "请在弹窗中点击安装，完成后重新运行"
				exit 0
			fi
		done
	fi

	# Linux: 一次性安装所有缺失的依赖
	if has_sudo; then
		for pm in "apt:apt install -y" "yum:yum install -y" "dnf:dnf install -y" "pacman:pacman -S --noconfirm" "zypper:zypper install -y"; do
			if command -v "${pm%%:*}" &>/dev/null; then
				print_info "安装依赖: ${missing[*]}"
				sudo ${pm#*:} "${missing[@]}" && break
			fi
		done
	fi

	# 重新检查所有依赖
	for cmd in "${missing[@]}"; do
		if ! command -v "$cmd" &>/dev/null; then
			print_error "无法安装依赖: $cmd"
			print_info "请手动安装后重新运行"
			exit 1
		fi
	done

	print_success "依赖检查通过"
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

	# git clone 输出到 stderr，需要捕获并写入日志
	local git_output
	if ! git_output=$(git clone --depth=1 --branch "$branch" --single-branch "$DOTFILES_REPO_URL" "$tmp_dir" 2>&1); then
		echo "$git_output" >>"$DOTFILES_LOG"
		echo "$git_output" >&2
		print_error "克隆仓库失败（分支: ${branch}）" >&2
		exit 1
	fi
	echo "$git_output" >>"$DOTFILES_LOG"

	echo "$tmp_dir"
}

# ========================================
# macOS: 安装 Homebrew 包
# ========================================
install_macos_homebrew() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_section "步骤 ${step_num}: 🍺 安装 Homebrew 包"

	if [[ -f "$dotfiles_dir/scripts/macos_install.sh" ]]; then
		bash "$dotfiles_dir/scripts/macos_install.sh"
	else
		print_warn "未找到 macOS 安装脚本，跳过 Homebrew 包安装"
	fi

	print_success "Homebrew 包安装完成"
}

# ========================================
# Linux: 安装 Pixi
# ========================================
install_pixi_binary() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_section "步骤 ${step_num}: 🦀 安装 Pixi"

	# 确保 pixi 在 PATH 中
	export PATH="$HOME/.pixi/bin:$PATH"

	# 检查是否已安装
	if command -v pixi &>/dev/null; then
		local version
		version=$(pixi --version 2>/dev/null)
		print_warn "Pixi 已安装 ($version)"
	else
		# 安装 Pixi
		if [[ -f "$dotfiles_dir/scripts/install_pixi.sh" ]]; then
			bash "$dotfiles_dir/scripts/install_pixi.sh" --install-only
		else
			print_error "未找到 Pixi 安装脚本"
			exit 1
		fi
		print_success "Pixi 安装完成"
	fi
}

# ========================================
# Linux: 安装 Pixi Home 项目工具包
# ========================================
sync_pixi_tools() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_section "步骤 ${step_num}: 📦 安装 Pixi 工具包"

	export PATH="$HOME/.pixi/bin:$PATH"

	if ! command -v pixi &>/dev/null; then
		print_error "Pixi 未安装"
		return 1
	fi

	# 部署 pixi.toml 到 home 目录
	local manifest_src="$dotfiles_dir/pixi.toml"
	local manifest_dest="$HOME/pixi.toml"

	if [[ -f "$manifest_src" ]]; then
		print_dim "部署配置: $manifest_dest"
		cp "$manifest_src" "$manifest_dest"
	fi

	if [[ -f "$manifest_dest" ]]; then
		# 调用 install_pixi.sh 安装工具包（复用逻辑，避免重复）
		if [[ -f "$dotfiles_dir/scripts/install_pixi.sh" ]]; then
			bash "$dotfiles_dir/scripts/install_pixi.sh" --tools-only || print_warn "部分工具安装失败"
		else
			print_error "未找到 Pixi 安装脚本"
		fi
	else
		print_warn "未找到 Pixi 配置文件: $manifest_dest"
	fi
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

	print_section "步骤 ${step_num}: 📂 安装 Dotfiles 配置"

	if [[ -f "$dotfiles_dir/scripts/install_dotfiles.sh" ]]; then
		# 子脚本会 source lib/utils.sh，自己处理日志，不要用 _run_and_log
		env DOTFILES_DIR="$dotfiles_dir" bash "$dotfiles_dir/scripts/install_dotfiles.sh"
	else
		print_warn "未找到 Dotfiles 安装脚本，跳过"
	fi

	print_success "Dotfiles 配置完成"
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

	print_section "步骤 ${step_num}: 💻 安装 VSCode 插件"

	if [[ -f "$dotfiles_dir/scripts/install_vscode_ext.sh" ]]; then
		# 子脚本会 source lib/utils.sh，自己处理日志
		bash "$dotfiles_dir/scripts/install_vscode_ext.sh" || {
			print_warn "VSCode 插件安装跳过（可能未安装 VSCode）"
		}
	fi
}

# ========================================
# 设置默认 shell 为 zsh
# ========================================
setup_default_shell() {
	local step="$1"
	print_section "步骤 $step: 🐚 设置默认 Shell"

	# 已经是 zsh 就跳过
	if [[ "$(basename "$SHELL")" == "zsh" ]]; then
		print_warn "当前 shell 已经是 zsh，跳过"
		return 0
	fi

	# 检测 zsh
	if ! command -v zsh &>/dev/null; then
		print_warn "未找到 zsh，请先安装: sudo apt install zsh"
		return 0
	fi

	local zsh_path
	zsh_path=$(command -v zsh)
	print_info "检测到 zsh: $zsh_path"

	# 检测权限
	if ! has_sudo; then
		print_warn "无 sudo 权限，请手动运行: chsh -s $zsh_path"
		return 0
	fi

	# 根据是否 root 决定命令前缀
	local SUDO=""
	[[ $EUID -ne 0 ]] && SUDO="sudo"

	# 确保 zsh 在 /etc/shells 中
	if ! grep -Fxq "$zsh_path" /etc/shells 2>/dev/null; then
		print_info "添加 zsh 到 /etc/shells..."
		echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null
	fi

	# 设置默认 shell
	print_info "设置默认 shell 为 zsh..."
	if $SUDO chsh -s "$zsh_path" "$(whoami)"; then
		print_success "默认 shell 已设置为 zsh"
	else
		print_warn "设置失败，请手动运行: chsh -s $zsh_path $(whoami)"
	fi
}

# ========================================
# Linux 安装流程
# ========================================
install_linux() {
	local dotfiles_dir="$1"

	# 仅安装 VSCode 插件模式
	if [[ "$VSCODE_ONLY" == "true" ]]; then
		install_vscode "$dotfiles_dir" "1/1"
		return 0
	fi

	# 仅安装 Dotfiles 模式
	if [[ "$DOTFILES_ONLY" == "true" ]]; then
		setup_dotfiles "$dotfiles_dir" "1/1"
		return 0
	fi

	# 步骤 1: 安装 Pixi
	install_pixi_binary "$dotfiles_dir" "1/5"

	if [[ "$PIXI_ONLY" == "true" ]]; then
		print_success "Pixi 安装完成（仅 Pixi 模式）"
		return 0
	fi

	# 步骤 2: 同步 Pixi 工具包
	sync_pixi_tools "$dotfiles_dir" "2/5"

	# 步骤 3: 安装 Dotfiles 配置
	setup_dotfiles "$dotfiles_dir" "3/5"

	# 步骤 4: 设置默认 shell
	setup_default_shell "4/5"

	# 步骤 5: VSCode 插件
	install_vscode "$dotfiles_dir" "5/5"
}

# ========================================
# macOS 安装流程
# ========================================
install_macos() {
	local dotfiles_dir="$1"

	# 仅安装 VSCode 插件模式
	if [[ "$VSCODE_ONLY" == "true" ]]; then
		install_vscode "$dotfiles_dir" "1/1"
		return 0
	fi

	# 仅安装 Dotfiles 模式
	if [[ "$DOTFILES_ONLY" == "true" ]]; then
		setup_dotfiles "$dotfiles_dir" "1/1"
		return 0
	fi

	# 步骤 1: 安装 Homebrew 包
	install_macos_homebrew "$dotfiles_dir" "1/3"

	# 步骤 2: 安装 Dotfiles 配置（已包含 SSH config）
	setup_dotfiles "$dotfiles_dir" "2/3"

	# 步骤 3: VSCode 插件
	install_vscode "$dotfiles_dir" "3/3"
}

# ========================================
# 主函数
# ========================================
main() {
	# 解析参数
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--pixi-only)
			PIXI_ONLY="true"
			shift
			;;
		--dotfiles-only)
			DOTFILES_ONLY="true"
			shift
			;;
		--vscode-only)
			VSCODE_ONLY="true"
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

	# 显示标题横幅
	_echo_blank
	print_banner "🚀 Dotfiles 安装脚本 v${DOTFILES_VERSION}"
	_echo_blank

	# 检查依赖（需要 git, curl, zsh）
	check_dependencies

	# 克隆仓库（尽早执行，以便后续可以 source lib/utils.sh）
	local dotfiles_dir
	dotfiles_dir=$(clone_dotfiles)
	export DOTFILES_DIR="$dotfiles_dir"

	# 克隆后 source lib/utils.sh，获取完整工具函数（print_dim, print_section 等）
	if [[ -f "$dotfiles_dir/lib/utils.sh" ]]; then
		source "$dotfiles_dir/lib/utils.sh"
	else
		print_error "未找到 lib/utils.sh，仓库可能不完整"
		exit 1
	fi

	local os arch
	os=$(detect_os)
	arch=$(detect_arch)

	# 清除 git clone 进度条残留（进度条以 \r 结尾，可能覆盖后续输出）
	echo ""
	print_dim "操作系统: $os | 架构: $arch | 用户: $(whoami)"
	if [[ "$os" == "macos" ]]; then
		print_dim "安装方式: Homebrew + Dotfiles"
	else
		print_dim "安装方式: Pixi + Dotfiles (Rootless)"
	fi
	_echo_blank

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

	# 更新 tldr 缓存（macOS 和 Linux 通用）
	# 支持不同客户端的缓存路径：tldr-c-client (~/.tldrc)、tldr-python (~/.cache/tldr)
	if command -v tldr &>/dev/null; then
		_echo_blank
		if [[ -d ~/.tldrc/tldr ]] || [[ -d ~/.cache/tldr/pages ]]; then
			print_success "tldr 缓存已存在，跳过更新"
		else
			print_info "更新 tldr 缓存..."
			tldr --update &>/dev/null && print_success "tldr 缓存更新完成"
		fi
	fi

	# 完成提示
	_echo_blank
	print_divider
	print_success "安装完成！"
	_echo_blank
	print_dim "📝 日志: $DOTFILES_LOG"
	_echo_blank
	print_info "下一步:"
	print_dim "1. 重新打开终端（或 source ~/.zshrc）"

	if [[ "$os" == "linux" ]]; then
		print_dim "2. 查看工具: cd ~ && pixi list"
	else
		print_dim "2. 验证安装: brew list"
	fi
	_echo_blank
}

main "$@"
