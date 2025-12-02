#!/bin/bash
# 卸载脚本 - 支持选择卸载 Dotfiles 或全部内容
# Usage: ./uninstall_all.sh [--dotfiles|--all|--force]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
UNINSTALL_MODE=""
FORCE=false

# ========================================
# 参数解析
# ========================================
while [[ $# -gt 0 ]]; do
	case "$1" in
	--dotfiles | -d)
		UNINSTALL_MODE="dotfiles"
		shift
		;;
	--all | -a)
		UNINSTALL_MODE="all"
		shift
		;;
	--force | -f)
		FORCE=true
		shift
		;;
	--help | -h)
		echo "用法: $0 [选项]"
		echo ""
		echo "选项:"
		echo "  --dotfiles, -d    只卸载 Dotfiles 配置"
		echo "  --all, -a         卸载全部（Dotfiles + Nix + Devbox）"
		echo "  --force, -f       跳过确认提示"
		echo "  --help, -h        显示帮助"
		exit 0
		;;
	*)
		echo -e "${RED}未知参数: $1${NC}"
		exit 1
		;;
	esac
done

# ========================================
# 显示标题
# ========================================
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                    卸载脚本                                ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ========================================
# 选择卸载模式
# ========================================
if [[ -z "$UNINSTALL_MODE" ]]; then
	echo -e "${CYAN}请选择卸载模式：${NC}"
	echo ""
	echo -e "  ${GREEN}1)${NC} 仅 Dotfiles - 只删除配置文件（zsh、kitty 等）"
	echo -e "  ${GREEN}2)${NC} 全部卸载   - 删除 Dotfiles + Nix + Devbox"
	echo ""
	echo -n "请输入选项 [1/2]: "
	read -r choice

	case "$choice" in
	1)
		UNINSTALL_MODE="dotfiles"
		;;
	2)
		UNINSTALL_MODE="all"
		;;
	*)
		echo -e "${RED}无效选项，已取消${NC}"
		exit 1
		;;
	esac
fi

# ========================================
# 显示将要删除的内容
# ========================================
echo ""
echo -e "${YELLOW}⚠️  将要删除以下内容：${NC}"
echo ""

echo -e "${CYAN}📁 Dotfiles 配置：${NC}"
echo -e "   • ~/.zshenv, ~/.zprofile, ~/.zshrc"
echo -e "   • ~/.config/zsh, ~/.config/kitty"
echo -e "   • ~/.cache/zsh, ~/.local/share/zinit"

if [[ "$(uname)" == "Darwin" ]]; then
	echo -e "   • ~/sh-script, ~/.hammerspoon"
	echo -e "   • ~/.config/karabiner/karabiner.json"
fi

if [[ "$UNINSTALL_MODE" == "all" ]]; then
	echo ""
	echo -e "${CYAN}📦 Nix 相关：${NC}"
	echo -e "   • ~/.nix, ~/.nix-profile, ~/.nix-defexpr, ~/.nix-channels"
	echo -e "   • ~/.config/nix"
	echo -e "   • ~/.local/bin/nix-user-chroot, nix-enter, nix-shell-wrapper"
	if [[ -d "/nix" ]]; then
		echo -e "   • /nix（系统级）"
	fi

	echo ""
	echo -e "${CYAN}📦 Devbox 相关：${NC}"
	echo -e "   • ~/.cache/devbox, ~/.local/share/devbox"
	echo -e "   • ~/.local/bin/devbox"
	echo -e "   • ~/.dotfiles"
fi

echo ""
echo -e "${YELLOW}⚠️  注意：此操作不可逆！${NC}"
echo ""

# ========================================
# 确认卸载
# ========================================
if [[ "$FORCE" != "true" ]]; then
	echo -n "确定要继续吗？[y/N]: "
	read -r confirm
	if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
		echo -e "${BLUE}已取消卸载${NC}"
		exit 0
	fi
fi

echo ""
echo -e "${BLUE}🗑️  开始卸载...${NC}"
echo ""

# ========================================
# 卸载 Dotfiles 配置
# ========================================
uninstall_dotfiles() {
	echo -e "${CYAN}卸载 Dotfiles 配置...${NC}"

	# Zsh 配置文件
	configs=(".zshenv" ".zprofile" ".zshrc")
	for config in "${configs[@]}"; do
		if [[ -e "$HOME/$config" ]]; then
			echo -e "   删除 ${YELLOW}$HOME/$config${NC}"
			rm -f "$HOME/$config"
		fi
	done

	# Zsh 配置目录
	dirs=(".config/zsh" ".config/kitty" ".cache/zsh" ".local/share/zinit")
	for dir in "${dirs[@]}"; do
		if [[ -d "$HOME/$dir" ]]; then
			echo -e "   删除 ${YELLOW}$HOME/$dir${NC}"
			rm -rf "$HOME/$dir"
		fi
	done

	# Zsh 缓存文件
	rm -f "$HOME/.zcompdump"* "$HOME/.zsh_history" 2>/dev/null || true

	# macOS 特定
	if [[ "$(uname)" == "Darwin" ]]; then
		if [[ -d "$HOME/sh-script" ]]; then
			echo -e "   删除 ${YELLOW}$HOME/sh-script${NC}"
			rm -rf "$HOME/sh-script"
		fi

		if [[ -d "$HOME/.hammerspoon" ]]; then
			echo -e "   删除 ${YELLOW}$HOME/.hammerspoon${NC}"
			rm -rf "$HOME/.hammerspoon"
		fi

		if [[ -f "$HOME/.config/karabiner/karabiner.json" ]]; then
			echo -e "   删除 ${YELLOW}$HOME/.config/karabiner/karabiner.json${NC}"
			rm -f "$HOME/.config/karabiner/karabiner.json"
		fi
	fi

	echo -e "${GREEN}   ✓ Dotfiles 配置已卸载${NC}"
}

# ========================================
# 卸载 Devbox
# ========================================
uninstall_devbox() {
	echo ""
	echo -e "${CYAN}卸载 Devbox...${NC}"

	# Devbox 缓存和数据
	devbox_dirs=(".cache/devbox" ".local/share/devbox" ".dotfiles")
	for dir in "${devbox_dirs[@]}"; do
		if [[ -d "$HOME/$dir" ]]; then
			echo -e "   删除 ${YELLOW}$HOME/$dir${NC}"
			rm -rf "$HOME/$dir"
		fi
	done

	# Devbox 二进制
	if [[ -f "$HOME/.local/bin/devbox" ]]; then
		echo -e "   删除 ${YELLOW}$HOME/.local/bin/devbox${NC}"
		rm -f "$HOME/.local/bin/devbox"
	fi

	echo -e "${GREEN}   ✓ Devbox 已卸载${NC}"
}

# ========================================
# 卸载 Nix
# ========================================
uninstall_nix() {
	echo ""
	echo -e "${CYAN}卸载 Nix...${NC}"

	# nix-user-chroot 相关
	nix_bins=("nix-user-chroot" "nix-enter" "nix-shell-wrapper")
	for bin in "${nix_bins[@]}"; do
		if [[ -f "$HOME/.local/bin/$bin" ]]; then
			echo -e "   删除 ${YELLOW}$HOME/.local/bin/$bin${NC}"
			rm -f "$HOME/.local/bin/$bin"
		fi
	done

	# Nix 用户目录
	nix_dirs=(".nix" ".nix-profile" ".nix-defexpr" ".nix-channels" ".config/nix")
	for dir in "${nix_dirs[@]}"; do
		if [[ -e "$HOME/$dir" ]]; then
			echo -e "   删除 ${YELLOW}$HOME/$dir${NC}"
			rm -rf "$HOME/$dir"
		fi
	done

	# 检查系统级 Nix
	if [[ -d "/nix" ]]; then
		echo -e "${YELLOW}   检测到系统级 Nix (/nix)${NC}"

		# 检测是否有 sudo 权限
		if sudo -n true 2>/dev/null || sudo -v 2>/dev/null; then
			echo -e "   删除 ${YELLOW}/nix${NC}"
			sudo rm -rf /nix

			# 删除系统级配置
			if [[ -d "/etc/nix" ]]; then
				echo -e "   删除 ${YELLOW}/etc/nix${NC}"
				sudo rm -rf /etc/nix
			fi

			if [[ -f "/etc/profile.d/nix.sh" ]]; then
				echo -e "   删除 ${YELLOW}/etc/profile.d/nix.sh${NC}"
				sudo rm -f /etc/profile.d/nix.sh
			fi

			# 删除 Nix daemon 服务（如果存在）
			if [[ -f "/etc/systemd/system/nix-daemon.service" ]]; then
				echo -e "   停止并删除 Nix daemon 服务"
				sudo systemctl stop nix-daemon.service 2>/dev/null || true
				sudo systemctl disable nix-daemon.service 2>/dev/null || true
				sudo rm -f /etc/systemd/system/nix-daemon.service
				sudo rm -f /etc/systemd/system/nix-daemon.socket
			fi

			echo -e "${GREEN}   ✓ 系统级 Nix 已卸载${NC}"
		else
			echo -e "${YELLOW}   ⚠️  无 sudo 权限，跳过系统级 Nix 卸载${NC}"
		fi
	fi

	echo -e "${GREEN}   ✓ Nix 已卸载${NC}"
}

# ========================================
# 清理空目录
# ========================================
cleanup_empty_dirs() {
	echo ""
	echo -e "${CYAN}清理空目录...${NC}"

	empty_dirs=(".config" ".cache" ".local/bin" ".local/share" ".local")
	for dir in "${empty_dirs[@]}"; do
		if [[ -d "$HOME/$dir" ]] && [[ -z "$(ls -A "$HOME/$dir" 2>/dev/null)" ]]; then
			echo -e "   删除空目录 ${YELLOW}$HOME/$dir${NC}"
			rmdir "$HOME/$dir" 2>/dev/null || true
		fi
	done
}

# ========================================
# 执行卸载
# ========================================
uninstall_dotfiles

if [[ "$UNINSTALL_MODE" == "all" ]]; then
	uninstall_devbox
	uninstall_nix
fi

cleanup_empty_dirs

# ========================================
# 完成
# ========================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ 卸载完成！                                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}提示：请重启终端以确保所有更改生效${NC}"
echo ""
