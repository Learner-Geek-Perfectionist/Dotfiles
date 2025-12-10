#!/bin/bash
# Dotfiles 统一安装入口
#
# Linux: Pixi (包管理) + Dotfiles 配置 - 完全 Rootless
# macOS: Homebrew (包管理) + Dotfiles 配置
#
# 支持: Linux (x86_64, aarch64) / macOS (x86_64, arm64)

set -e

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

# 日志文件（与 lib/utils.sh 保持一致）
DOTFILES_LOG_DIR="/tmp/dotfiles-logs/install"
DOTFILES_LOG="${DOTFILES_LOG:-$DOTFILES_LOG_DIR/dotfiles-install-$(whoami)-$(date '+%Y%m%d-%H%M%S').log}"

# 临时 gum 安装目录（用于解决鸡生蛋问题：脚本需要 gum，但 gum 通过 pixi 安装）
TEMP_GUM_DIR=""

# ========================================
# 工具函数（install.sh 需要自包含，因为 curl | bash 时还没 clone 仓库）
# ========================================

# 强制颜色输出（即使在重定向场景下）
export CLICOLOR_FORCE=1

# 确保 TERM 有值（tput 需要）
export TERM="${TERM:-xterm}"

# Fallback 颜色定义（当 gum 不可用时使用）
export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
export BLUE='\033[0;34m' CYAN='\033[0;36m' PURPLE='\033[0;35m' NC='\033[0m'

# 检测 gum 是否可用
_has_gum() { command -v gum &>/dev/null; }

# 检测是否有 sudo 权限（而非 sudo 命令是否存在）
has_sudo() {
	command -v sudo &>/dev/null || return 1 # 先检查有没有 sudo 命令
	[[ $EUID -eq 0 ]] && return 0           # root 用户，无需 sudo
	sudo -n true 2>/dev/null && return 0    # 有免密 sudo 权限
	return 1
}

# 去除 ANSI 颜色代码（用于写入日志）
_strip_ansi() {
	sed 's/\x1b\[[0-9;]*m//g'
}

# 运行命令并同时输出到终端和日志（日志去除颜色）
_run_and_log() {
	"$@" 2>&1 | while IFS= read -r line; do
		echo "$line"
		echo "$line" | _strip_ansi >>"$DOTFILES_LOG"
	done
}

# 输出空行到终端和日志
_echo_blank() {
	echo ""
	echo "" >>"$DOTFILES_LOG"
}

# 打印函数（终端保留颜色，日志去除颜色）
print_info() {
	local msg
	if _has_gum; then
		msg=$(gum log --level info --level.foreground 14 --message.foreground 14 "$1" 2>&1)
	else
		msg=$(echo -e "${CYAN}$1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
}
print_success() {
	local msg
	if _has_gum; then
		msg=$(gum log --level info --prefix "✓" --level.foreground 10 --prefix.foreground 10 --message.foreground 10 "$1" 2>&1)
	else
		msg=$(echo -e "${GREEN}✓ $1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
}
print_warn() {
	local msg
	if _has_gum; then
		msg=$(gum log --level warn --level.foreground 11 --message.foreground 11 "$1" 2>&1)
	else
		msg=$(echo -e "${YELLOW}⚠ $1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
}
print_error() {
	local msg
	if _has_gum; then
		msg=$(gum log --level error --level.foreground 9 --message.foreground 9 "$1" 2>&1)
	else
		msg=$(echo -e "${RED}✗ $1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
}
print_header() {
	local msg
	if _has_gum; then
		msg=$(gum style --bold --foreground 212 "$1" 2>&1)
	else
		msg=$(echo -e "${BLUE}$1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
}
print_step() {
	local msg
	if _has_gum; then
		msg=$(gum log --level debug --prefix "→" --level.foreground 13 --prefix.foreground 13 --message.foreground 13 "$1" 2>&1)
	else
		msg=$(echo -e "${PURPLE}→ $1${NC}")
	fi
	echo "$msg"
	echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
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
		echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
		msg=$(gum style --width "$width" --align center --foreground 13 "$title" 2>&1)
		echo "$msg"
		echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
		msg=$(gum style --foreground 13 "$line" 2>&1)
		echo "$msg"
		echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
	else
		print_step "========================================"
		print_step "$title"
		print_step "========================================"
	fi
}

detect_os() {
	case "$(uname -s)" in Darwin) echo "macos" ;; Linux) echo "linux" ;; *) echo "unknown" ;; esac
}
detect_arch() {
	case "$(uname -m)" in x86_64) echo "x86_64" ;; aarch64 | arm64) echo "aarch64" ;; *) echo "$(uname -m)" ;; esac
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

# 设置日志
setup_logging() {
	mkdir -p "$DOTFILES_LOG_DIR"
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
				xcode-select --install 2>/dev/null || true
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

# 临时安装 gum（静默，解决鸡生蛋问题）
setup_temp_gum() {
	# 如果 gum 已经可用，不需要临时安装
	command -v gum &>/dev/null && return 0

	local os arch gum_version="0.14.5"
	os=$(uname -s)
	arch=$(uname -m)

	# 转换架构名称
	case "$arch" in
	x86_64) arch="x86_64" ;;
	aarch64 | arm64) arch="arm64" ;;
	*) return 0 ;;
	esac

	# 转换系统名称
	case "$os" in
	Darwin) os="Darwin" ;;
	Linux) os="Linux" ;;
	*) return 0 ;;
	esac

	# 创建临时目录并下载
	TEMP_GUM_DIR="/tmp/gum-temp-$(whoami)"
	mkdir -p "$TEMP_GUM_DIR"

	local gum_url="https://github.com/charmbracelet/gum/releases/download/v${gum_version}/gum_${gum_version}_${os}_${arch}.tar.gz"

	if curl -fsSL "$gum_url" 2>/dev/null | tar -xz -C "$TEMP_GUM_DIR" 2>/dev/null; then
		# 找到 gum 二进制（可能在顶层或子目录中）
		local gum_bin
		gum_bin=$(find "$TEMP_GUM_DIR" -name "gum" -type f 2>/dev/null | head -1)
		if [[ -n "$gum_bin" && -x "$gum_bin" ]]; then
			export PATH="$(dirname "$gum_bin"):$PATH"
		else
			TEMP_GUM_DIR=""
		fi
	else
		TEMP_GUM_DIR=""
	fi
}

# 清理临时 gum（静默）
cleanup_temp_gum() {
	[[ -n "$TEMP_GUM_DIR" && -d "$TEMP_GUM_DIR" ]] && rm -rf "$TEMP_GUM_DIR"
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
		echo "$git_output" | _strip_ansi >>"$DOTFILES_LOG"
		echo "$git_output" >&2
		print_error "克隆仓库失败（分支: ${branch}）" >&2
		exit 1
	fi
	echo "$git_output" | _strip_ansi >>"$DOTFILES_LOG"

	echo "$tmp_dir"
}

# ========================================
# macOS: 安装 Homebrew 包
# ========================================
install_macos_homebrew() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_section "步骤 ${step_num}: 安装 Homebrew 包"

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

	print_section "步骤 ${step_num}: 安装 Pixi (包管理器)"

	# 安装 Pixi 二进制
	if [[ -f "$dotfiles_dir/scripts/install_pixi.sh" ]]; then
		bash "$dotfiles_dir/scripts/install_pixi.sh" --install-only
	else
		print_error "未找到 Pixi 安装脚本"
		exit 1
	fi

	# 确保 pixi 在 PATH 中
	export PATH="$HOME/.pixi/bin:$PATH"

	print_success "Pixi 安装完成"
}

# ========================================
# Linux: 同步 Pixi 工具包
# ========================================
sync_pixi_tools() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_section "步骤 ${step_num}: 同步 Pixi 工具包"

	export PATH="$HOME/.pixi/bin:$PATH"

	if ! command -v pixi &>/dev/null; then
		print_error "Pixi 未安装"
		return 1
	fi

	# 部署 pixi manifest
	local manifest_src="$dotfiles_dir/.pixi/manifests/pixi-global.toml"
	local manifest_dest="$HOME/.pixi/manifests/pixi-global.toml"

	if [[ -f "$manifest_src" ]]; then
		print_info "部署 Pixi 配置..."
		mkdir -p "$(dirname "$manifest_dest")"
		cp "$manifest_src" "$manifest_dest"
	fi

	if [[ -f "$manifest_dest" ]]; then
		print_info "同步工具包（这可能需要几分钟）..."
		print_info "所有包都是预编译的，无需本地编译"
		_echo_blank

		if _run_and_log pixi global sync; then
			print_success "工具包同步完成"
		else
			print_warn "部分工具同步失败"
			print_info "可以稍后运行: pixi global sync"
		fi

		# 使用 pixi 原生验证
		_echo_blank
		print_info "已安装的工具:"
		_run_and_log pixi global list
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

	print_section "步骤 ${step_num}: 安装 Dotfiles 配置"

	if [[ -f "$dotfiles_dir/scripts/install_dotfiles.sh" ]]; then
		_run_and_log env DOTFILES_DIR="$dotfiles_dir" bash "$dotfiles_dir/scripts/install_dotfiles.sh"
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

	print_section "步骤 ${step_num}: 安装 VSCode 插件"

	if [[ -f "$dotfiles_dir/scripts/install_vscode_ext.sh" ]]; then
		_run_and_log bash "$dotfiles_dir/scripts/install_vscode_ext.sh" || {
			print_warn "VSCode 插件安装跳过（可能未安装 VSCode）"
		}
	fi
}

# ========================================
# 配置 SSH
# ========================================
setup_ssh() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_section "步骤 ${step_num}: 配置 SSH"

	if [[ -f "$dotfiles_dir/.ssh/config" ]]; then
		mkdir -p "$HOME/.ssh"
		chmod 700 "$HOME/.ssh"

		if [[ -f "$HOME/.ssh/config" ]]; then
			cp "$HOME/.ssh/config" "$HOME/.ssh/config.bak"
			print_info "已备份旧的 SSH 配置"
		fi

		cp "$dotfiles_dir/.ssh/config" "$HOME/.ssh/config"
		chmod 600 "$HOME/.ssh/config"
		print_success "SSH 配置完成"
	else
		print_warn "未找到 SSH 配置文件，跳过"
	fi
}

# ========================================
# 设置默认 shell 为 zsh
# ========================================
setup_default_shell() {
	local step="$1"
	print_section "步骤 $step: 设置默认 Shell"

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

	# 检查依赖（需要 git, curl, zsh）
	check_dependencies

	# 静默安装临时 gum，脚本结束时自动清理
	setup_temp_gum
	trap cleanup_temp_gum EXIT

	# 克隆仓库（尽早执行，以便后续可以 source lib/utils.sh）
	local dotfiles_dir
	dotfiles_dir=$(clone_dotfiles)
	export DOTFILES_DIR="$dotfiles_dir"

	# 克隆后 source lib/utils.sh，复用工具函数
	if [[ -f "$dotfiles_dir/lib/utils.sh" ]]; then
		source "$dotfiles_dir/lib/utils.sh"
	fi

	local os arch
	os=$(detect_os)
	arch=$(detect_arch)

	_echo_blank
	local msg
	if _has_gum; then
		msg=$(gum style --width "$(tput cols)" --align center --background 99 --foreground 255 --bold " 🚀 Dotfiles 安装脚本 v${DOTFILES_VERSION} " 2>&1)
		echo "$msg"
		echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
	else
		print_header "=== 🚀 Dotfiles 安装脚本 v${DOTFILES_VERSION} ==="
	fi
	_echo_blank
	print_info "操作系统: $os"
	print_info "架构: $arch"
	print_info "用户: $(whoami)"

	if [[ "$os" == "macos" ]]; then
		print_info "安装方式: Homebrew + Dotfiles 配置"
	else
		print_info "安装方式: Pixi + Dotfiles 配置 (完全 Rootless)"
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
	if command -v tldr &>/dev/null; then
		print_info "更新 tldr 缓存..."
		tldr --update &>/dev/null && print_success "tldr 缓存更新完成"
	fi

	# 完成
	_echo_blank
	local msg
	if _has_gum; then
		msg=$(gum style --width "$(tput cols)" --align center --background 10 --foreground 0 --bold " ✅ 安装完成！ " 2>&1)
		echo "$msg"
		echo "$msg" | _strip_ansi >>"$DOTFILES_LOG"
	else
		print_success "=== ✅ 安装完成！ ==="
	fi
	_echo_blank
	print_info "📝 安装日志: $DOTFILES_LOG"
	_echo_blank
	print_info "下一步:"
	print_info "  1. 重新打开终端（或运行: source ~/.zshrc）"

	if [[ "$os" == "linux" ]]; then
		print_info "  2. 查看已安装工具: pixi global list"
		_echo_blank
		print_info "常用命令:"
		print_info "  pixi global install <pkg>  - 安装包"
		print_info "  pixi global upgrade        - 升级所有包"
	else
		print_info "  2. 验证安装: brew list"
		_echo_blank
		print_info "常用命令:"
		print_info "  brew update && brew upgrade - 更新所有包"
	fi

	_echo_blank
}

main "$@"
