#!/bin/bash
# Dotfiles 卸载脚本

set -euo pipefail

# ========================================
# 日志配置
# ========================================
export DOTFILES_LOG_DIR="/tmp/dotfiles-logs/uninstall"
export DOTFILES_LOG="${DOTFILES_LOG:-$DOTFILES_LOG_DIR/dotfiles-uninstall-$(whoami)-$(date '+%Y%m%d-%H%M%S').log}"

# ========================================
# 内嵌工具函数（避免路径依赖）
# ========================================
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置日志
setup_logging() {
	mkdir -p "$DOTFILES_LOG_DIR"
	echo "=== Dotfiles 卸载日志 $(date) ===" >"$DOTFILES_LOG"
}

# 尝试加载 lib/utils.sh，如果失败则使用内嵌函数
if [[ -f "$_SCRIPT_DIR/lib/utils.sh" ]]; then
	source "$_SCRIPT_DIR/lib/utils.sh"
else
	# Fallback: 内嵌必要的函数
	export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
	export BLUE='\033[0;34m' CYAN='\033[0;36m' DIM='\033[2m' NC='\033[0m'

	print_info() { echo -e "${CYAN}[INFO] $1${NC}" | tee -a "$DOTFILES_LOG"; }
	print_success() { echo -e "${GREEN}✓ $1${NC}" | tee -a "$DOTFILES_LOG"; }
	print_warn() { echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$DOTFILES_LOG"; }
	print_error() { echo -e "${RED}✗ $1${NC}" | tee -a "$DOTFILES_LOG"; }
	print_dim() { echo -e "${DIM}   $1${NC}" | tee -a "$DOTFILES_LOG"; }
fi

REMOVE_PIXI=false
REMOVE_DOTFILES=false
FORCE=false

show_help() {
	cat <<'EOF'
用法: ./uninstall.sh [选项]

选项:
    --pixi       仅删除 Pixi (~/.pixi 等)
    --dotfiles   仅删除 Dotfiles 配置
    --all        同时删除两者
    -f, --force  跳过确认
    -h, --help   显示帮助
EOF
}

confirm() {
	[[ "$FORCE" == "true" ]] && return 0
	read -r -p "$1 [y/N]: " ans
	[[ "$ans" =~ ^[Yy] ]]
}

rm_path() {
	local p="$1"
	[[ -z "$p" || "$p" == "/" ]] && return
	if [[ -e "$p" || -L "$p" ]]; then
		rm -rf "$p" && print_dim "✓ $p"
	fi
}

remove_pixi() {
	print_info "🧹 删除 Pixi 及其安装的所有工具..."

	# 显示将要删除的包（如果 pixi 存在）
	if command -v pixi &>/dev/null; then
		print_dim "已安装的工具环境:"
		pixi global list 2>/dev/null
	fi

	# 删除 pixi 主目录（包含 bin、envs、manifests）
	# ~/.pixi/bin - pixi 本身和所有 exposed 的命令
	# ~/.pixi/envs - 所有安装的环境和包
	rm_path ~/.pixi

	# 删除 pixi/rattler 缓存和数据目录（包下载缓存在这里）
	for p in ~/.cache/pixi ~/.cache/rattler ~/.local/share/pixi ~/.local/state/pixi ~/.rattler; do
		rm_path "$p"
	done

	# 如果设置了 XDG_CACHE_HOME，也检查那里
	if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
		rm_path "$XDG_CACHE_HOME/rattler"
		rm_path "$XDG_CACHE_HOME/pixi"
	fi

	print_success "Pixi 及所有工具已删除"
}

remove_dotfiles() {
	print_info "🗑️ 删除 Dotfiles..."

	# 通用配置
	for p in ~/.zshrc ~/.zprofile ~/.zshenv ~/.config/{zsh,kitty} ~/.ssh/config ~/.pixi/manifests; do
		rm_path "$p"
	done

	# 删除 zinit 相关目录（插件、补全、缓存等）
	for p in ~/.local/share/zinit ~/.cache/zinit; do
		rm_path "$p"
	done

	# 删除 p10k 缓存
	for p in ~/.cache/p10k-instant-prompt-*.zsh; do
		[[ -e "$p" ]] && rm -f "$p" && print_success "已删除: $p"
	done

	# 删除 ~/.cache/zsh 目录（但保留 .zsh_history）
	if [[ -d ~/.cache/zsh ]]; then
		print_dim "清理 ~/.cache/zsh（保留历史记录）"
		# 备份 history 文件
		local history_file=~/.cache/zsh/.zsh_history
		local history_backup=""
		if [[ -f "$history_file" ]]; then
			history_backup=$(mktemp)
			cp "$history_file" "$history_backup"
		fi
		# 删除整个目录
		rm -rf ~/.cache/zsh
		# 恢复 history 文件
		if [[ -n "$history_backup" && -f "$history_backup" ]]; then
			mkdir -p ~/.cache/zsh
			mv "$history_backup" "$history_file"
			print_dim "✓ 已保留: $history_file"
		fi
	fi

	# 根据操作系统区分 VSCode/Cursor 配置路径
	# 注意：只删除 settings.json，不删除整个 User 目录（避免误删用户其他配置）
	if [[ "$(uname -s)" == "Darwin" ]]; then
		# macOS: Library 路径 + macOS 专属工具
		for p in ~/"Library/Application Support"/{Code,Cursor}/User/settings.json ~/.config/karabiner ~/.hammerspoon; do
			rm_path "$p"
		done
	else
		# Linux: .config 路径
		for p in ~/.config/{Code,Cursor}/User/settings.json; do
			rm_path "$p"
		done
	fi
}

# 解析参数
while (($#)); do
	case "$1" in
	--pixi) REMOVE_PIXI=true ;;
	--dotfiles) REMOVE_DOTFILES=true ;;
	--all)
		REMOVE_PIXI=true
		REMOVE_DOTFILES=true
		;;
	-f | --force) FORCE=true ;;
	-h | --help)
		show_help
		exit 0
		;;
	*)
		print_error "未知选项: $1"
		exit 1
		;;
	esac
	shift
done

# 初始化日志
setup_logging

# 交互菜单
if [[ "$REMOVE_PIXI" == "false" && "$REMOVE_DOTFILES" == "false" ]]; then
	echo -e "\n请选择:\n  1) Pixi\n  2) Dotfiles\n  3) 全部\n  4) 退出"
	read -r -p "输入 1-4: " c
	case "$c" in
	1) REMOVE_PIXI=true ;;
	2) REMOVE_DOTFILES=true ;;
	3)
		REMOVE_PIXI=true
		REMOVE_DOTFILES=true
		;;
	*) exit 0 ;;
	esac
fi

# 执行删除
[[ "$REMOVE_PIXI" == "true" ]] && confirm "确认删除 Pixi?" && remove_pixi
[[ "$REMOVE_DOTFILES" == "true" ]] && confirm "确认删除 Dotfiles?" && remove_dotfiles

echo ""
print_success "卸载完成！"
print_dim "📝 日志: $DOTFILES_LOG"
