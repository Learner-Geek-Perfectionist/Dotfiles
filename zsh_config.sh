#!/bin/bash

# 设置脚本在遇到错误时退出
set -e

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting script...${NC}"

rm -rf /tmp/dotfiles
# 定义临时目录路径
TMP_DIR="/tmp/dotfiles"

# 浅克隆仓库到临时目录
echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR"
echo -e "${GREEN}✔️ Repository cloned.${NC}"

# 删除当前用户家目录的 .zshenv、.zprofile、.zshrc、.config、sh-script
echo -e "${YELLOW}🔍 Checking and removing old configuration files if they exist...${NC}"
[ -f "$HOME/.zshenv" ] && echo -e "${RED}🗑️ Removing old .zshenv...${NC}" && rm -rf "$HOME/.zshenv"
[ -f "$HOME/.zprofile" ] && echo -e "${RED}🗑️ Removing old .zprofile...${NC}" && rm -rf "$HOME/.zprofile"
[ -f "$HOME/.zshrc" ] && echo -e "${RED}🗑️ Removing old .zshrc...${NC}" && rm -rf "$HOME/.zshrc"
[ -d "$HOME/.config" ] && echo -e "${RED}🗑️ Removing old .config directory...${NC}" && rm -rf "$HOME/.config"
[ -d "$HOME/sh-script" ] && echo -e "${RED}🗑️ Removing old sh-script directory...${NC}" && rm -rf "$HOME/sh-script/"
echo -e "${GREEN}🧹 Old configuration files removed.${NC}"

# 复制新的文件到当前用户的家目录
echo -e "${YELLOW}📋 Copying new configuration files to $HOME...${NC}"
cp "$TMP_DIR/.zshenv" "$HOME/.zshenv"
cp "$TMP_DIR/.zprofile" "$HOME/.zprofile"
cp "$TMP_DIR/.zshrc" "$HOME/.zshrc"
cp -r "$TMP_DIR/.config" "$HOME/.config"
cp -r "$TMP_DIR/sh-script" "$HOME/sh-script"
# 在文件中添加以下代码
if [[ "$OSTYPE" == "darwin"* ]]; then
    # 仅在 macOS 上拷贝
    cp -r "$TMP_DIR/sh-script/" "$HOME/sh-script/"
fi
echo -e "${GREEN}✔️ New configuration files copied.${NC}"


# 清理临时目录
echo -e "${YELLOW}🧼 Cleaning up temporary files...${NC}"
rm -rf "$TMP_DIR"
echo -e "${GREEN}✔️ Temporary files removed.${NC}"

echo -e "${GREEN}✅ Script completed successfully. Files have been successfully copied to the user's home directory.${NC}"
