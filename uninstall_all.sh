#!/bin/bash
# 完整卸载脚本 - 卸载 Dotfiles、Nix、Devbox 等所有内容
# Usage: ./uninstall_all.sh [--force]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 参数解析
FORCE=false
if [[ "$1" == "--force" || "$1" == "-f" ]]; then
	FORCE=true
fi

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║           完整卸载脚本 - Uninstall All                     ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ========================================
# 显示将要删除的内容
# ========================================
echo -e "${YELLOW}⚠️  此脚本将删除以下内容：${NC}"
echo ""
echo -e "${CYAN}📁 Dotfiles 配置：${NC}"
echo -e "   • ~/.zshenv, ~/.zprofile, ~/.zshrc"
echo -e "   • ~/.config/zsh, ~/.config/kitty"
echo -e "   • ~/.cache/zsh, ~/.local/share/zinit"

echo ""
echo -e "${CYAN}📦 Nix 相关（用户级）：${NC}"
echo -e "   • ~/.nix (Nix 存储目录)"
echo -e "   • ~/.nix-profile, ~/.nix-defexpr, ~/.nix-channels"
echo -e "   • ~/.config/nix"
echo -e "   • ~/.local/bin/nix-user-chroot"
echo -e "   • ~/.local/bin/nix-enter, ~/.local/bin/nix-shell-wrapper"

echo ""
echo -e "${CYAN}📦 Devbox 相关：${NC}"
echo -e "   • ~/.cache/devbox"
echo -e "   • ~/.local/share/devbox"
echo -e "   • ~/.local/bin/devbox"
echo -e "   • ~/.dotfiles (Devbox 项目目录)"

if [[ "$(uname)" == "Darwin" ]]; then
	echo ""
	echo -e "${CYAN}🍎 macOS 特定：${NC}"
	echo -e "   • ~/sh-script"
	echo -e "   • ~/.hammerspoon"
	echo -e "   • ~/.config/karabiner/karabiner.json"
fi

echo ""
echo -e "${YELLOW}⚠️  注意：此操作不可逆！${NC}"
echo ""

# ========================================
# 确认卸载
# ========================================
if [[ "$FORCE" != "true" ]]; then
	echo -e "${RED}确定要卸载所有内容吗？${NC}"
	echo -n "输入 'yes' 确认: "
	read -r confirm
	if [[ "$confirm" != "yes" ]]; then
		echo -e "${BLUE}已取消卸载${NC}"
		exit 0
	fi
fi

echo ""
echo -e "${BLUE}🗑️  开始卸载...${NC}"
echo ""

# ========================================
# 1. 卸载 Dotfiles 配置
# ========================================
echo -e "${CYAN}[1/4] 卸载 Dotfiles 配置...${NC}"

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

echo -e "${GREEN}   ✓ Dotfiles 配置已卸载${NC}"

# ========================================
# 2. 卸载 Devbox
# ========================================
echo ""
echo -e "${CYAN}[2/4] 卸载 Devbox...${NC}"

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

# ========================================
# 3. 卸载 Nix（用户级）
# ========================================
echo ""
echo -e "${CYAN}[3/4] 卸载 Nix（用户级）...${NC}"

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
		echo -e "${YELLOW}   如需卸载，请以 sudo 运行此脚本${NC}"
	fi
fi

echo -e "${GREEN}   ✓ Nix 已卸载${NC}"

# ========================================
# 4. macOS 特定内容
# ========================================
if [[ "$(uname)" == "Darwin" ]]; then
	echo ""
	echo -e "${CYAN}[4/4] 卸载 macOS 特定内容...${NC}"

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

	echo -e "${GREEN}   ✓ macOS 特定内容已卸载${NC}"
else
	echo ""
	echo -e "${CYAN}[4/4] 跳过 macOS 特定内容（非 macOS 系统）${NC}"
fi

# ========================================
# 清理空目录
# ========================================
echo ""
echo -e "${CYAN}清理空目录...${NC}"

# 清理可能的空目录
empty_dirs=(".config" ".cache" ".local/bin" ".local/share" ".local")
for dir in "${empty_dirs[@]}"; do
	if [[ -d "$HOME/$dir" ]] && [[ -z "$(ls -A "$HOME/$dir" 2>/dev/null)" ]]; then
		echo -e "   删除空目录 ${YELLOW}$HOME/$dir${NC}"
		rmdir "$HOME/$dir" 2>/dev/null || true
	fi
done

# ========================================
# 完成
# ========================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ 卸载完成！                                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}提示：${NC}"
echo -e "  • 请重启终端以确保所有更改生效"
echo -e "  • 如果之前修改了 ~/.bashrc 或 ~/.bash_profile，请手动检查"
echo ""
