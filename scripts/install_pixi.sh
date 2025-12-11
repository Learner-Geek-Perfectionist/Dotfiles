#!/bin/bash
# Pixi 安装脚本
# 基于 conda-forge 的现代包管理器
# 完全 Rootless，支持 x86_64 和 arm64
#
# 文档: https://pixi.sh/

set -e

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../lib/utils.sh" ]]; then
	source "$SCRIPT_DIR/../lib/utils.sh"
fi

# ========================================
# 配置
# ========================================
PIXI_HOME="${PIXI_HOME:-$HOME/.pixi}"
PIXI_BIN="$PIXI_HOME/bin/pixi"

# ========================================
# 检查 Pixi 是否已安装（静默检查）
# ========================================
check_pixi_installed() {
	# 先尝试添加 pixi 到 PATH（非交互式 shell 可能没有）
	[[ -d "$HOME/.pixi/bin" ]] && export PATH="$HOME/.pixi/bin:$PATH"
	command -v pixi &>/dev/null
}

# ========================================
# 安装 Pixi
# ========================================
install_pixi() {
	print_info "🦀 安装 Pixi..."
	print_dim "安装目录: $PIXI_HOME"

	# 检查是否已安装
	if check_pixi_installed; then
		local version
		version=$(pixi --version 2>/dev/null)
		print_warn "Pixi 已安装 ($version)，跳过安装"
		return 0
	fi

	# 使用官方安装脚本
	print_info "下载并安装 Pixi..."

	if curl -fsSL https://pixi.sh/install.sh | bash; then
		print_success "Pixi 安装成功"
	else
		print_error "Pixi 安装失败"
		exit 1
	fi

	# 验证安装
	export PATH="$PIXI_HOME/bin:$PATH"
	if command -v pixi &>/dev/null; then
		print_success "Pixi 已可用: $(pixi --version)"
	else
		print_error "Pixi 安装验证失败"
		exit 1
	fi
}

# ========================================
# 配置 Shell 集成
# ========================================
setup_shell_integration() {
	print_info "🔧 配置 Shell 集成..."

	local shell_name
	shell_name=$(basename "$SHELL")

	# PATH 配置
	local path_export='export PATH="$HOME/.pixi/bin:$PATH"'

	case "$shell_name" in
	zsh)
		local zshrc="$HOME/.zshrc"
		touch "$zshrc"

		# 添加 PATH（如果不存在）
		if ! grep -q '\.pixi/bin' "$zshrc" 2>/dev/null; then
			echo "" >>"$zshrc"
			echo "# Pixi: 添加到 PATH" >>"$zshrc"
			echo "$path_export" >>"$zshrc"
			print_success "已添加 Pixi PATH 到 .zshrc"
		else
			print_warn "Pixi PATH 已存在于 .zshrc"
		fi
		;;
	bash)
		local bashrc="$HOME/.bashrc"
		touch "$bashrc"

		if ! grep -q '\.pixi/bin' "$bashrc" 2>/dev/null; then
			echo "" >>"$bashrc"
			echo "# Pixi: 添加到 PATH" >>"$bashrc"
			echo "$path_export" >>"$bashrc"
			print_success "已添加 Pixi PATH 到 .bashrc"
		else
			print_warn "Pixi PATH 已存在于 .bashrc"
		fi
		;;
	*)
		print_warn "未知 Shell: $shell_name"
		print_info "请手动添加以下内容到你的 shell 配置文件:"
		print_info "  $path_export"
		;;
	esac

	# 让当前 shell 立即生效
	export PATH="$HOME/.pixi/bin:$PATH"
}

# ========================================
# 安装全局工具包
# ========================================
install_global_tools() {
	print_info "📦 安装全局工具包..."

	export PATH="$PIXI_HOME/bin:$PATH"

	if ! command -v pixi &>/dev/null; then
		print_error "Pixi 未找到，无法安装工具包"
		return 1
	fi

	# 检查是否有 manifest 文件
	local manifest="$HOME/.pixi/manifests/pixi-global.toml"

	if [[ ! -f "$manifest" ]]; then
		print_error "未找到 Pixi 配置文件: $manifest"
		print_info "请先运行 install.sh 部署配置文件"
		exit 1
	fi

	# 使用 pixi global sync 同步 manifest 中定义的所有 env
	print_dim "配置文件: $manifest"
	print_info "同步工具包（预编译，无需本地编译）..."

	if pixi global sync; then
		print_success "工具包同步完成"
	else
		print_error "Pixi 工具包同步失败"
		print_dim "请检查网络，随后运行: pixi global sync"
		exit 1
	fi

	# 显示简洁的工具列表
	echo ""
	print_info "已安装的工具:"
	pixi global list 2>/dev/null | grep -E '^\s*─ exposes:' | sed 's/.*exposes: /   /' || pixi global list
}

# ========================================
# 显示帮助
# ========================================
show_help() {
	cat <<HELP_EOF
Pixi 安装脚本

用法: $0 [选项]

选项:
    --install-only      仅安装 pixi，不安装工具包
    --tools-only        仅安装工具包（假设 pixi 已安装）
    --shell-only        仅配置 shell 集成
    --help, -h          显示帮助信息

环境变量:
    PIXI_HOME           Pixi 安装目录 (默认: ~/.pixi)

示例:
    # 完整安装
    $0

    # 仅安装 pixi
    $0 --install-only

常用 pixi 命令:
    pixi global install <pkg>  - 全局安装包
    pixi global list           - 列出已安装的包
    pixi global upgrade        - 升级所有包
    pixi global remove <pkg>   - 移除包
HELP_EOF
}

# ========================================
# 主函数
# ========================================
main() {
	local action="full"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--install-only)
			action="install"
			shift
			;;
		--tools-only)
			action="tools"
			shift
			;;
		--shell-only)
			action="shell"
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

	case "$action" in
	full)
		install_pixi
		setup_shell_integration
		install_global_tools
		;;
	install)
		install_pixi
		setup_shell_integration
		;;
	tools)
		install_global_tools
		;;
	shell)
		setup_shell_integration
		;;
	esac

	# 检测 shell 配置文件
	local rc_file="~/.bashrc"
	[[ "$SHELL" == *zsh ]] && rc_file="~/.zshrc"

	echo ""
	print_success "Pixi 设置完成！"
	echo ""
	print_dim "下一步: source $rc_file 或重新打开终端"
	print_dim "验证安装: pixi global list"
	echo ""
}

main "$@"
