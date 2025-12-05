#!/bin/bash
# Dotfiles 卸载脚本

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/utils.sh"

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
	[[ -e "$p" || -L "$p" ]] && rm -rf "$p" && print_success "已删除: $p" || print_info "跳过: $p"
}

remove_pixi() {
	print_header "🧹 删除 Pixi"
	for p in ~/.pixi ~/.cache/pixi ~/.local/share/pixi ~/.local/state/pixi; do
		rm_path "$p"
	done
}

remove_dotfiles() {
	print_header "🗑️ 删除 Dotfiles"

	# 通用配置
	for p in ~/.zshrc ~/.zprofile ~/.zshenv ~/.config/{zsh,kitty} ~/.ssh/config ~/.pixi/manifests; do
		rm_path "$p"
	done

	# 删除 zinit 插件目录
	rm_path ~/.local/share/zinit

	# 删除 ~/.cache/zsh 目录（但保留 .zsh_history）
	if [[ -d ~/.cache/zsh ]]; then
		print_info "清理 ~/.cache/zsh（保留历史记录）..."
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
			print_success "已保留: $history_file"
		fi
	fi

	# 根据操作系统区分 VSCode/Cursor 配置路径
	if [[ "$(uname -s)" == "Darwin" ]]; then
		# macOS: Library 路径 + macOS 专属工具
		for p in ~/"Library/Application Support"/{Code,Cursor}/User ~/.config/karabiner ~/.hammerspoon; do
			rm_path "$p"
		done
	else
		# Linux: .config 路径
		for p in ~/.config/{Code,Cursor}/User; do
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

print_success "✅ 完成"
