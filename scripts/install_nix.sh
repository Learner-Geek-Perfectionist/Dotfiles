#!/bin/bash
# Nix 安装脚本 - 支持无 sudo 权限环境（默认）和有 sudo 权限环境
# 使用 nix-user-chroot 实现用户级 Nix 安装

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_msg() {
	local msg="$1"
	local color="${2:-$NC}"
	echo -e "${color}${msg}${NC}"
}

print_info() { print_msg "$1" "$CYAN"; }
print_success() { print_msg "$1" "$GREEN"; }
print_warn() { print_msg "$1" "$YELLOW"; }
print_error() { print_msg "$1" "$RED"; }

# 默认配置
NIX_DIR="${NIX_DIR:-$HOME/.nix}"
NIX_USER_CHROOT_DIR="${NIX_USER_CHROOT_DIR:-$HOME/.local/bin}"
NIX_USER_CHROOT_BIN="$NIX_USER_CHROOT_DIR/nix-user-chroot"
USE_SUDO="${USE_SUDO:-false}"

# 检测系统架构
get_arch() {
	local arch
	arch=$(uname -m)
	case "$arch" in
	x86_64) echo "x86_64" ;;
	aarch64) echo "aarch64" ;;
	arm64) echo "aarch64" ;;
	*)
		print_error "不支持的架构: $arch"
		exit 1
		;;
	esac
}

# 检测操作系统
get_os() {
	local os
	os=$(uname -s)
	case "$os" in
	Linux) echo "linux" ;;
	Darwin) echo "darwin" ;;
	*)
		print_error "不支持的操作系统: $os"
		exit 1
		;;
	esac
}

# 检查必要的依赖工具
check_dependencies() {
	print_info "检查必要依赖..."

	local missing=()

	# 检查 xz（解压 Nix tarball 必需）
	if ! command -v xz >/dev/null 2>&1; then
		missing+=("xz")
	fi

	# 检查 tar
	if ! command -v tar >/dev/null 2>&1; then
		missing+=("tar")
	fi

	# 检查 curl
	if ! command -v curl >/dev/null 2>&1; then
		missing+=("curl")
	fi

	if [[ ${#missing[@]} -gt 0 ]]; then
		print_error "✗ 缺少必要的依赖工具: ${missing[*]}"
		print_info ""
		print_info "请先安装这些工具："
		print_info "  Ubuntu/Debian: sudo apt install ${missing[*]}"
		print_info "  CentOS/RHEL:   sudo yum install ${missing[*]}"
		print_info "  Fedora:        sudo dnf install ${missing[*]}"
		print_info "  Alpine:        sudo apk add ${missing[*]}"
		print_info ""
		return 1
	fi

	print_success "✓ 依赖检查通过"
	return 0
}

# 检测是否支持用户命名空间
check_user_namespace() {
	print_info "检测用户命名空间支持..."

	if command -v unshare >/dev/null 2>&1; then
		if unshare --user --pid echo "YES" 2>/dev/null | grep -q "YES"; then
			print_success "✓ 用户命名空间支持正常"
			return 0
		fi
	fi

	# 检查内核配置
	if [[ -f /proc/config.gz ]]; then
		if zgrep -q "CONFIG_USER_NS=y" /proc/config.gz 2>/dev/null; then
			print_warn "⚠ 内核支持用户命名空间，但可能被禁用"
			print_warn "请联系管理员启用: sysctl kernel.unprivileged_userns_clone=1"
			return 1
		fi
	fi

	print_error "✗ 系统不支持用户命名空间"
	print_error "无法在无 sudo 权限下安装 Nix"
	return 1
}

# 检查 Nix 是否已安装
check_nix_installed() {
	if [[ -f "$NIX_DIR/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
		return 0
	fi
	if [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
		return 0
	fi
	if command -v nix >/dev/null 2>&1; then
		return 0
	fi
	return 1
}

# 下载 nix-user-chroot
download_nix_user_chroot() {
	local arch
	arch=$(get_arch)

	print_info "下载 nix-user-chroot ($arch)..."

	# 获取最新版本
	local latest_version
	latest_version=$(curl -fsSL "https://api.github.com/repos/nix-community/nix-user-chroot/releases/latest" 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' || echo "1.2.2")

	local download_url="https://github.com/nix-community/nix-user-chroot/releases/download/${latest_version}/nix-user-chroot-bin-${latest_version}-${arch}-unknown-linux-musl"

	mkdir -p "$NIX_USER_CHROOT_DIR"

	print_info "下载地址: $download_url"

	if curl -fsSL "$download_url" -o "$NIX_USER_CHROOT_BIN"; then
		chmod +x "$NIX_USER_CHROOT_BIN"
		print_success "✓ nix-user-chroot 下载完成: $NIX_USER_CHROOT_BIN"
	else
		print_error "✗ 下载 nix-user-chroot 失败"
		exit 1
	fi
}

# 使用 nix-user-chroot 安装 Nix（无 sudo）
install_nix_user_chroot() {
	print_info "=========================================="
	print_info "使用 nix-user-chroot 安装 Nix（用户级）"
	print_info "=========================================="

	# 检查必要依赖
	if ! check_dependencies; then
		exit 1
	fi

	# 检查用户命名空间支持
	if ! check_user_namespace; then
		exit 1
	fi

	# 创建 Nix 存储目录
	if [[ ! -d "$NIX_DIR" ]]; then
		print_info "创建 Nix 存储目录: $NIX_DIR"
		mkdir -p "$NIX_DIR"
		chmod 0755 "$NIX_DIR"
	fi

	# 下载 nix-user-chroot
	if [[ ! -x "$NIX_USER_CHROOT_BIN" ]]; then
		download_nix_user_chroot
	else
		print_info "nix-user-chroot 已存在: $NIX_USER_CHROOT_BIN"
	fi

	# 在 nix-user-chroot 环境中安装 Nix
	print_info "在用户空间安装 Nix..."

	"$NIX_USER_CHROOT_BIN" "$NIX_DIR" bash -c '
        curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
    '

	print_success "✓ Nix 用户级安装完成"

	# 创建包装脚本
	create_nix_wrapper
}

# 创建 Nix 包装脚本
create_nix_wrapper() {
	print_info "创建 Nix 包装脚本..."

	local wrapper_dir="$HOME/.local/bin"
	mkdir -p "$wrapper_dir"

	# 创建 nix-shell-wrapper
	cat >"$wrapper_dir/nix-shell-wrapper" <<'WRAPPER_EOF'
#!/bin/bash
# Nix User Chroot 包装脚本
NIX_DIR="${NIX_DIR:-$HOME/.nix}"
NIX_USER_CHROOT="${NIX_USER_CHROOT_BIN:-$HOME/.local/bin/nix-user-chroot}"

if [[ ! -x "$NIX_USER_CHROOT" ]]; then
    echo "错误: nix-user-chroot 未找到: $NIX_USER_CHROOT"
    exit 1
fi

exec "$NIX_USER_CHROOT" "$NIX_DIR" bash -l -c "
    source ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || true
    exec \"\$@\"
" -- "$@"
WRAPPER_EOF
	chmod +x "$wrapper_dir/nix-shell-wrapper"

	# 创建进入 Nix 环境的脚本
	cat >"$wrapper_dir/nix-enter" <<ENTER_EOF
#!/bin/bash
# 进入 Nix 用户环境
NIX_DIR="${NIX_DIR:-\$HOME/.nix}"
NIX_USER_CHROOT="\${NIX_USER_CHROOT_BIN:-\$HOME/.local/bin/nix-user-chroot}"

exec "\$NIX_USER_CHROOT" "\$NIX_DIR" bash -l -c '
    source ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || true
    exec zsh -l 2>/dev/null || exec bash -l
'
ENTER_EOF
	chmod +x "$wrapper_dir/nix-enter"

	print_success "✓ 包装脚本已创建"
	print_info "使用 'nix-enter' 进入 Nix 环境"
	print_info "使用 'nix-shell-wrapper <命令>' 在 Nix 环境中执行命令"
}

# 使用官方安装器安装 Nix（需要 sudo）
install_nix_daemon() {
	print_info "=========================================="
	print_info "使用官方安装器安装 Nix（daemon 模式）"
	print_info "=========================================="

	curl -L https://nixos.org/nix/install | sh -s -- --daemon

	print_success "✓ Nix daemon 模式安装完成"
}

# 配置 Nix 镜像源（加速）
configure_nix_mirror() {
	print_info "配置 Nix 镜像源..."

	local nix_conf_dir
	if [[ "$USE_SUDO" == "true" ]]; then
		nix_conf_dir="/etc/nix"
	else
		nix_conf_dir="$HOME/.config/nix"
	fi

	mkdir -p "$nix_conf_dir"

	cat >"$nix_conf_dir/nix.conf" <<'NIX_CONF_EOF'
# Nix 配置
experimental-features = nix-command flakes

# 使用 USTC 镜像加速
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=

# 并行下载
max-jobs = auto
cores = 0
NIX_CONF_EOF

	print_success "✓ Nix 镜像源配置完成"
}

# 显示使用帮助
show_help() {
	cat <<HELP_EOF
Nix 安装脚本 - 支持无 sudo 权限环境

用法: $0 [选项]

选项:
    --use-sudo      使用 sudo 安装（daemon 模式）
    --nix-dir DIR   指定 Nix 存储目录（默认: ~/.nix）
    --help          显示帮助信息

环境变量:
    NIX_DIR         Nix 存储目录
    USE_SUDO        设为 "true" 使用 sudo 安装

示例:
    # 默认无 sudo 安装
    $0

    # 使用 sudo 安装
    $0 --use-sudo

    # 指定自定义目录
    $0 --nix-dir /data/user/.nix
HELP_EOF
}

# 主函数
main() {
	# 解析参数
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--use-sudo)
			USE_SUDO="true"
			shift
			;;
		--nix-dir)
			NIX_DIR="$2"
			shift 2
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

	local os
	os=$(get_os)

	print_info "=========================================="
	print_info "Nix 安装脚本"
	print_info "=========================================="
	print_info "操作系统: $os"
	print_info "架构: $(get_arch)"
	print_info "安装模式: $([ "$USE_SUDO" == "true" ] && echo "daemon (sudo)" || echo "用户级 (nix-user-chroot)")"
	print_info "Nix 目录: $NIX_DIR"
	print_info "=========================================="

	# 检查是否已安装
	if check_nix_installed; then
		print_warn "Nix 已安装，跳过安装步骤"
		configure_nix_mirror
		return 0
	fi

	# macOS 特殊处理
	if [[ "$os" == "darwin" ]]; then
		print_info "macOS 检测到，使用官方安装器..."
		curl -L https://nixos.org/nix/install | sh
		configure_nix_mirror
		return 0
	fi

	# Linux 安装
	if [[ "$USE_SUDO" == "true" ]]; then
		install_nix_daemon
	else
		install_nix_user_chroot
	fi

	configure_nix_mirror

	print_success "=========================================="
	print_success "Nix 安装完成！"
	print_success "=========================================="

	if [[ "$USE_SUDO" != "true" ]]; then
		print_info ""
		print_info "下一步："
		print_info "1. 安装 Devbox 后，直接运行 'devbox shell' 进入开发环境"
		print_info "2. 或运行 'nix-enter' 进入 Nix 交互环境"
		print_info ""
	fi
}

main "$@"
