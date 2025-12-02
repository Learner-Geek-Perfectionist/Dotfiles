#!/bin/bash
# Dotfiles 配置脚本 - 复制配置文件到用户目录

set -e

# ========================================
# 颜色定义
# ========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ========================================
# 工具函数
# ========================================
print_info() { echo -e "${CYAN}$1${NC}"; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_warn() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }

# ========================================
# 路径检测
# ========================================
# 支持多种调用方式
if [[ -n "$DOTFILES_DIR" ]]; then
	# 已设置 DOTFILES_DIR 环境变量
	:
elif [[ -f "${BASH_SOURCE[0]}" ]]; then
	# 从脚本文件调用
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
	# 默认使用 /tmp/Dotfiles
	DOTFILES_DIR="/tmp/Dotfiles-$(whoami)"
fi

print_info "=========================================="
print_info "Dotfiles 配置"
print_info "=========================================="
print_info "源目录: $DOTFILES_DIR"
print_info "目标目录: $HOME"
print_info "=========================================="
echo ""

# ========================================
# 创建 XDG 目录结构
# ========================================
print_info "创建 XDG 目录结构..."

mkdir -p "$HOME/.config/zsh/plugins"
mkdir -p "$HOME/.config/kitty"
mkdir -p "$HOME/.cache/zsh"
mkdir -p "$HOME/.local/share/zinit"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/state"

print_success "✓ 目录结构已创建"

# ========================================
# 配置文件列表
# ========================================
configs=(
	".zshenv"
	".zprofile"
	".zshrc"
	".config/kitty"
	".config/zsh"
)

# ========================================
# 复制配置文件
# ========================================
print_info "复制配置文件..."

for config in "${configs[@]}"; do
	TARGET="${HOME}/${config}"
	SOURCE="${DOTFILES_DIR}/${config}"

	if [[ -e "$SOURCE" ]]; then
		echo -e "  ${PURPLE}→${NC} ${config}"

		# 创建父目录
		mkdir -p "$(dirname "$TARGET")"

		# 删除旧配置（如果存在）
		[[ -e "$TARGET" || -L "$TARGET" ]] && rm -rf "$TARGET"

		# 复制新配置
		cp -a "$SOURCE" "$TARGET"
	else
		echo -e "  ${YELLOW}⊘${NC} ${config} (源文件不存在)"
	fi
done

print_success "✓ 配置文件已复制"

# ========================================
# macOS 专用配置
# ========================================
if [[ "$(uname)" == "Darwin" ]]; then
	print_info "配置 macOS 专用文件..."

	# sh-script
	if [[ -d "$DOTFILES_DIR/sh-script" ]]; then
		mkdir -p "$HOME/sh-script"
		cp -r "$DOTFILES_DIR/sh-script/"* "$HOME/sh-script/"
		echo -e "  ${PURPLE}→${NC} sh-script"
	fi

	# Hammerspoon
	if [[ -d "$DOTFILES_DIR/.hammerspoon" ]]; then
		[[ -d "$HOME/.hammerspoon" ]] && rm -rf "$HOME/.hammerspoon"
		cp -r "$DOTFILES_DIR/.hammerspoon" "$HOME/.hammerspoon"
		echo -e "  ${PURPLE}→${NC} .hammerspoon"
	fi

	# Karabiner
	if [[ -f "$DOTFILES_DIR/.config/karabiner/karabiner.json" ]]; then
		mkdir -p "$HOME/.config/karabiner"
		[[ -f "$HOME/.config/karabiner/karabiner.json" ]] && rm -f "$HOME/.config/karabiner/karabiner.json"
		cp "$DOTFILES_DIR/.config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
		echo -e "  ${PURPLE}→${NC} karabiner.json"
	fi

	print_success "✓ macOS 配置完成"
fi

# ========================================
# SSH 配置（可选）
# ========================================
if [[ -f "$DOTFILES_DIR/config" ]]; then
	print_info "配置 SSH..."
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"

	# 备份现有配置
	if [[ -f "$HOME/.ssh/config" ]]; then
		cp "$HOME/.ssh/config" "$HOME/.ssh/config.bak"
	fi

	cp "$DOTFILES_DIR/config" "$HOME/.ssh/config"
	chmod 600 "$HOME/.ssh/config"
	echo -e "  ${PURPLE}→${NC} .ssh/config"
	print_success "✓ SSH 配置完成"
fi

# ========================================
# VSCode 配置（可选）
# ========================================
if [[ -f "$DOTFILES_DIR/settings.json" ]]; then
	print_info "配置 VSCode settings..."

	# 检测 VSCode 配置目录
	if [[ "$(uname)" == "Darwin" ]]; then
		VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
	else
		VSCODE_CONFIG_DIR="$HOME/.config/Code/User"
	fi

	if [[ -d "$(dirname "$VSCODE_CONFIG_DIR")" ]]; then
		mkdir -p "$VSCODE_CONFIG_DIR"
		cp "$DOTFILES_DIR/settings.json" "$VSCODE_CONFIG_DIR/settings.json"
		echo -e "  ${PURPLE}→${NC} VSCode settings.json"
		print_success "✓ VSCode 配置完成"
	else
		print_warn "  VSCode 配置目录不存在，跳过"
	fi
fi

# ========================================
# 安装 Zinit 插件
# ========================================
if command -v zsh >/dev/null 2>&1; then
	ZINIT_PLUGIN_SCRIPT="$HOME/.config/zsh/plugins/zinit-plugin.zsh"

	if [[ -f "$ZINIT_PLUGIN_SCRIPT" ]]; then
		print_info "安装 Zinit 插件..."

		# 使用 zsh 执行插件脚本
		if zsh "$ZINIT_PLUGIN_SCRIPT" 2>/dev/null; then
			print_success "✓ Zinit 插件安装完成"
		else
			print_warn "Zinit 插件安装跳过（将在首次启动 zsh 时自动安装）"
		fi
	fi
fi

# ========================================
# 清理旧缓存
# ========================================
print_info "清理旧缓存文件..."

# 清理旧位置的 zsh 缓存文件
rm -f "$HOME/.zcompdump"* 2>/dev/null || true
rm -f "$HOME/.zsh_history" 2>/dev/null || true

print_success "✓ 缓存清理完成"

# ========================================
# 完成
# ========================================
echo ""
print_success "=========================================="
print_success "🎉 Dotfiles 配置完成！"
print_success "=========================================="
echo ""
print_info "运行 'exec zsh -l' 或重新打开终端以应用配置"
