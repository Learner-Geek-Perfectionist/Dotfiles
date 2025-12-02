#!/bin/bash
# Devbox 安装脚本 - 在 Nix 环境中安装 Devbox
# 支持无 sudo 权限环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
NIX_USER_CHROOT_BIN="${NIX_USER_CHROOT_BIN:-$HOME/.local/bin/nix-user-chroot}"
DEVBOX_BIN_DIR="$HOME/.local/bin"

# 检测是否在 Nix 环境中
in_nix_env() {
	[[ -n "$NIX_PROFILES" ]] || [[ -d "/nix/store" ]]
}

# 执行 Nix 命令（自动处理 nix-user-chroot）
nix_exec() {
	if in_nix_env; then
		# 已经在 Nix 环境中
		"$@"
	elif [[ -x "$NIX_USER_CHROOT_BIN" ]]; then
		# 使用 nix-user-chroot
		"$NIX_USER_CHROOT_BIN" "$NIX_DIR" bash -l -c '
            source ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || true
            "$@"
        ' -- "$@"
	else
		print_error "未找到 Nix 环境，请先运行 install_nix.sh"
		exit 1
	fi
}

# 检查 Devbox 是否已安装（检查 nix-profile 中的真正 devbox，而不是包装脚本）
check_devbox_installed() {
	# 检查 nix-profile 中的 devbox（真正的 devbox）
	if [[ -x "$HOME/.nix-profile/bin/devbox" ]]; then
		return 0
	fi
	# 如果在 nix 环境中，检查 devbox 命令
	if in_nix_env && command -v devbox >/dev/null 2>&1; then
		return 0
	fi
	return 1
}

# 使用 Nix 安装 Devbox
install_devbox_via_nix() {
	print_info "通过 Nix 安装 Devbox..."

	if in_nix_env; then
		# 直接在 Nix 环境中安装
		nix-env -iA nixpkgs.devbox
	elif [[ -x "$NIX_USER_CHROOT_BIN" ]]; then
		# 使用 nix-user-chroot 环境安装
		"$NIX_USER_CHROOT_BIN" "$NIX_DIR" bash -l -c '
            source ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || true
            nix-env -iA nixpkgs.devbox
        '
	else
		print_error "未找到 Nix 环境"
		exit 1
	fi
}

# 使用官方安装器安装 Devbox
install_devbox_via_installer() {
	print_info "通过官方安装器安装 Devbox..."

	mkdir -p "$DEVBOX_BIN_DIR"

	# Jetify 官方安装脚本
	curl -fsSL https://get.jetify.com/devbox | bash -s -- -f

	# 确保 devbox 在 PATH 中
	if [[ -x "$HOME/.local/share/devbox/bin/devbox" ]]; then
		ln -sf "$HOME/.local/share/devbox/bin/devbox" "$DEVBOX_BIN_DIR/devbox"
	fi
}

# 创建 Devbox 包装脚本（用于 nix-user-chroot 环境）
# 直接命名为 devbox，这样用户可以直接 `devbox shell`
create_devbox_wrapper() {
	print_info "创建 Devbox 包装脚本..."

	mkdir -p "$DEVBOX_BIN_DIR"

	# 包装脚本直接命名为 devbox，放在 ~/.local/bin（优先于 nix 中的 devbox）
	cat >"$DEVBOX_BIN_DIR/devbox" <<'WRAPPER_EOF'
#!/bin/bash
# Devbox 包装脚本 - 自动处理 nix-user-chroot 环境
# 用户可以直接 `devbox shell`，无需先 nix-enter

NIX_DIR="${NIX_DIR:-$HOME/.nix}"
NIX_USER_CHROOT="${NIX_USER_CHROOT_BIN:-$HOME/.local/bin/nix-user-chroot}"

# 动态检测 devbox 的实际位置
find_real_devbox() {
    # 优先检查 nix-profile（通过 nix 安装）
    if [[ -x "$HOME/.nix-profile/bin/devbox" ]]; then
        echo "$HOME/.nix-profile/bin/devbox"
        return 0
    fi
    # 检查 Jetify 官方安装器位置
    if [[ -x "$HOME/.local/share/devbox/bin/devbox" ]]; then
        echo "$HOME/.local/share/devbox/bin/devbox"
        return 0
    fi
    # 检查系统路径（有 sudo 安装的情况）
    if command -v devbox >/dev/null 2>&1; then
        command -v devbox
        return 0
    fi
    return 1
}

# 检查是否已在 Nix 环境中
if [[ -n "$NIX_PROFILES" ]] || [[ -d "/nix/store" ]]; then
    # 已在 Nix 环境中，找到真正的 devbox 执行
    REAL_DEVBOX=$(find_real_devbox)
    if [[ -n "$REAL_DEVBOX" && -x "$REAL_DEVBOX" ]]; then
        exec "$REAL_DEVBOX" "$@"
    else
        echo "错误: 未找到 devbox"
        exit 1
    fi
fi

# 使用 nix-user-chroot 执行
if [[ -x "$NIX_USER_CHROOT" ]]; then
    exec "$NIX_USER_CHROOT" "$NIX_DIR" bash -l -c '
        source ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || true
        # 动态查找 devbox
        if [[ -x "$HOME/.nix-profile/bin/devbox" ]]; then
            exec "$HOME/.nix-profile/bin/devbox" "$@"
        elif [[ -x "$HOME/.local/share/devbox/bin/devbox" ]]; then
            exec "$HOME/.local/share/devbox/bin/devbox" "$@"
        else
            echo "错误: 未找到 devbox"
            exit 1
        fi
    ' -- "$@"
else
    # 没有 nix-user-chroot，尝试直接找 devbox
    REAL_DEVBOX=$(find_real_devbox)
    if [[ -n "$REAL_DEVBOX" && -x "$REAL_DEVBOX" ]]; then
        exec "$REAL_DEVBOX" "$@"
    else
        echo "错误: 未找到 nix-user-chroot 或 devbox"
        exit 1
    fi
fi
WRAPPER_EOF
	chmod +x "$DEVBOX_BIN_DIR/devbox"

	print_success "✓ Devbox 包装脚本已创建: $DEVBOX_BIN_DIR/devbox"
	print_info "现在可以直接使用 'devbox shell' 命令"
}

# 验证安装
verify_installation() {
	print_info "验证 Devbox 安装..."

	local version=""

	if in_nix_env; then
		# 已在 nix 环境中，直接执行
		version=$(devbox version 2>/dev/null || echo "")
	elif [[ -x "$NIX_USER_CHROOT_BIN" ]]; then
		# 使用 nix-user-chroot 执行
		version=$("$NIX_USER_CHROOT_BIN" "$NIX_DIR" bash -l -c '
			source ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null || true
			devbox version 2>/dev/null
		' 2>/dev/null || echo "")
	fi

	if [[ -n "$version" ]]; then
		print_success "✓ Devbox 安装成功，版本: $version"
		return 0
	else
		print_error "✗ Devbox 安装验证失败"
		return 1
	fi
}

# 显示使用帮助
show_help() {
	cat <<HELP_EOF
Devbox 安装脚本

用法: $0 [选项]

选项:
    --via-nix       通过 Nix 安装 Devbox（默认）
    --via-installer 通过 Jetify 官方安装器安装
    --help          显示帮助信息

环境变量:
    NIX_DIR              Nix 存储目录（默认: ~/.nix）
    NIX_USER_CHROOT_BIN  nix-user-chroot 路径

示例:
    # 默认安装
    $0

    # 使用官方安装器
    $0 --via-installer
HELP_EOF
}

# 主函数
main() {
	local install_method="nix"

	# 解析参数
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--via-nix)
			install_method="nix"
			shift
			;;
		--via-installer)
			install_method="installer"
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

	print_info "=========================================="
	print_info "Devbox 安装脚本"
	print_info "=========================================="
	print_info "安装方式: $install_method"
	print_info "=========================================="

	# 检查是否已安装
	if check_devbox_installed; then
		print_warn "Devbox 已安装"
		verify_installation
		return 0
	fi

	# 安装 Devbox
	case "$install_method" in
	nix)
		install_devbox_via_nix
		;;
	installer)
		install_devbox_via_installer
		;;
	esac

	# 创建包装脚本（针对 nix-user-chroot 环境）
	if [[ -x "$NIX_USER_CHROOT_BIN" ]]; then
		create_devbox_wrapper
	fi

	# 验证安装
	verify_installation

	print_success "=========================================="
	print_success "Devbox 安装完成！"
	print_success "=========================================="
	print_info ""
	print_info "下一步："
	print_info "1. 重新加载 shell 或运行: source ~/.zshrc"
	print_info "2. 进入项目目录运行: devbox shell"
	print_info "   （无需先 nix-enter，包装脚本会自动处理）"
	print_info ""
}

main "$@"
