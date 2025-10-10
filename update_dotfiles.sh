#!/bin/bash

# 设置脚本在遇到错误时退出
set -e

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
ORANGE='\033[0;93m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_BLUE='\033[1;34m'
DARK_RED='\033[1;31m'
NC='\033[0m' # 没有颜色

# 定义临时目录路径
TMP_DIR="/tmp/Dotfiles"

sudo rm -rf "$TMP_DIR"
sudo rm -rf /tmp/Fonts/
echo -e "${GREEN}🚀 Starting script...${NC}"

# 先安装 git，再 clone
echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
	echo "Failed to clone repository"
	exit 1
}

# ================================= 开始安装 dotfiles =================================

# Ensure XDG base directories exist
mkdir -p "$HOME/.config/zsh/plugins" "${HOME}/.config/kitty" "$HOME/.cache/zsh" "${HOME}/.local/share/zinit" "$HOME/.local/state"

# 定义配置列表
configs=(".zshenv" ".zprofile" ".zshrc" ".config/kitty" ".config/zsh")

# 删除旧配置和复制新配置
echo -e "${YELLOW}🔍 Checking and removing old configuration files if they exist...${NC}"
for config in "${configs[@]}"; do
	if [[ -f "${HOME}/${config}" ]] || [[ -d "${HOME}/${config}" ]]; then
		echo -e "${RED}🗑️ Removing old ${HOME}/${config} ${NC}"
		sudo rm -rf "${HOME}/$config"
	fi
	echo -e "${PURPLE}📋 Moving new ${config} to ${HOME}/${config} ${NC}"
	cp -r "${TMP_DIR}/${config}" "${HOME}/${config}"
done

# 针对 macOS 的配置,
# 在文件中添加以下代码
[[ "$(uname)" == "Darwin" ]] && cp -r "$TMP_DIR/sh-script/" "$HOME/sh-script/"

# 添加 .hammerspoon 文件夹
if [[ "$(uname)" == "Darwin" ]]; then
	if [[ -d "${HOME}/.hammerspoon" ]]; then
		echo -e "${RED}🗑️ Removing old .hammerspoon...${NC}"
		sudo rm -rf "${HOME}/.hammerspoon"
	fi
	echo -e "${PURPLE}📋 Copying new .hammerspoon to "${HOME}/.hammerspoon"...${NC}"
	cp -r "${TMP_DIR}/.hammerspoon" "${HOME}/.hammerspoon"
fi

# 添加 karabiner 的配置文件：karabiner.json
if [[ "$(uname)" == "Darwin" ]]; then
	if [[ -f "${HOME}/.config/karabiner/karabiner.json" ]]; then
		echo -e "${RED}🗑️ Removing old karabiner.json....${NC}"
		sudo rm -rf "${HOME}/.config/karabiner/karabiner.json"
	fi
	echo -e "${PURPLE}📋 Copying new karabiner.json to "${HOME}/.config/karabiner/karabiner.json"...${NC}"
	cp -r "${TMP_DIR}/.config/karabiner/karabiner.json" "${HOME}/.config/karabiner/karabiner.json"
fi

echo -e "${GREEN}🧹 Old configuration files removed and new ones copied.${NC}"
echo -e "${GREEN}✔️ New configuration files copied.${NC}"

# 清理临时目录
echo -e "${YELLOW}🧼 Cleaning up temporary files...${NC}"
sudo rm -rf "$TMP_DIR"
sudo rm -rf /tmp/Fonts/

echo -e "${GREEN}✔️ Temporary files removed.${NC}"
echo -e "${GREEN}✅ Script completed successfully. Files have been successfully copied to the user's home directory.${NC}"

# 安装 zsh 插件
~/.config/zsh/plugins/zinit-plugin.zsh

rm -rf $HOME/.zcompdump $HOME/.zsh_history

# ================================= 结束安装 dotfiles =================================
