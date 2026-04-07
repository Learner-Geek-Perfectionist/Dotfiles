#!/bin/bash
# shellcheck disable=SC2088
# Pixi 安装脚本
# 基于 conda-forge 的现代包管理器
# 完全 Rootless，支持 x86_64 和 arm64
#
# 文档: https://pixi.sh/

set -euo pipefail

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

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
	[[ -x "$PIXI_BIN" ]] && export PATH="$PIXI_HOME/bin:$PATH"
	[[ -x "$PIXI_BIN" ]]
}

# ========================================
# 安装 Pixi
# ========================================
install_pixi() {
	print_info "🦀 安装 Pixi..."
	print_dim "安装目录: $PIXI_HOME"

	if check_pixi_installed; then
		local version
		version=$("$PIXI_BIN" --version 2>/dev/null)
		print_success "Pixi 已安装 ($version)"
		return 0
	fi

	# 使用官方安装脚本
	print_dim "下载 Pixi..."
	if curl -fsSL https://pixi.sh/install.sh | bash; then
		export PATH="$PIXI_HOME/bin:$PATH"
		print_dim "Pixi 已可用: $(pixi --version 2>/dev/null)"
	else
		print_error "Pixi 安装失败"
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
# 安装 Home 项目工具包
# ========================================
install_home_tools() {
	print_info "📦 安装 Home 项目工具包..."

	export PATH="$PIXI_HOME/bin:$PATH"

	if ! command -v pixi &>/dev/null; then
		print_warn "Pixi 未找到，跳过工具包安装"
		return 0
	fi

	# 检查是否有 pixi.toml 文件
	local manifest="$HOME/pixi.toml"

	if [[ ! -f "$manifest" ]]; then
		print_error "未找到 Pixi 配置文件: $manifest"
		print_info "请先运行 install.sh 部署配置文件"
		exit 1
	fi

	# 执行 pixi install
	print_dim "配置文件: $manifest"
	print_info "安装工具包（预编译，无需本地编译）..."

	if _run_and_log pixi install --manifest-path "$HOME/pixi.toml"; then
		print_success "工具包安装完成"
	else
		print_error "Pixi 工具包安装失败"
		print_dim "请检查网络，随后运行: pixi install --manifest-path ~/pixi.toml"
		exit 1
	fi

	# 显示已安装的顶层工具
	_echo_blank
	print_info "已安装的顶层工具:"
	(cd "$HOME" && _run_and_log pixi list --explicit 2>/dev/null) || print_dim "运行 'pixi list --explicit --manifest-path ~/pixi.toml' 查看"
}

# ========================================
# 显示帮助
# ========================================
show_help() {
	cat <<HELP_EOF
Pixi 安装脚本 — 一键安装 pixi + shell 集成 + 工具包

用法: $0 [选项]

选项:
    --help, -h          显示帮助信息

环境变量:
    PIXI_HOME           Pixi 安装目录 (默认: ~/.pixi)

常用 pixi 命令:
    pixi add <pkg>       - 添加包到 ~/pixi.toml
    pixi remove <pkg>    - 从 ~/pixi.toml 移除包
    pixi list            - 列出已安装的包
    pixi update          - 升级所有包
    pixi shell           - 进入 pixi 环境

说明:
    首次安装时，~/pixi.toml 默认由 Dotfiles 托管。
    若你手动修改该文件，下次 install.sh 会自动跳过覆盖，视为你已接管维护。
HELP_EOF
}

# ========================================
# 主函数
# ========================================
main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
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

	install_pixi
	setup_shell_integration
	install_home_tools

	# 独立运行时显示提示，被 install.sh 调用时不显示（避免重复）
	if [[ -z "${DOTFILES_DIR:-}" ]]; then
		local rc_file="~/.bashrc"
		[[ "$SHELL" == *zsh ]] && rc_file="~/.zshrc"
		_echo_blank
		print_success "Pixi 设置完成！"
		print_dim "下一步: source $rc_file 或重新打开终端"
		print_dim "验证: cd ~ && pixi list"
		_echo_blank
	fi
}

main "$@"
