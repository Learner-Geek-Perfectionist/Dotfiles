#!/bin/bash

# 设置脚本在遇到错误时退出
set -e

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting script...${NC}"

rm -rf /tmp/Dotfiles
# 定义临时目录路径
TMP_DIR="/tmp/Dotfiles"

# 浅克隆仓库到临时目录
echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR"
echo -e "${GREEN}✔️ Repository cloned.${NC}"

# 定义配置列表
configs=(".zshenv" ".zprofile" ".zshrc" ".config")

# 删除旧配置和复制新配置
echo -e "${YELLOW}🔍 Checking and removing old configuration files if they exist...${NC}"
for config in "${configs[@]}"; do
    if [ -f "$HOME/$config" ] || [ -d "$HOME/$config" ]; then
        echo -e "${RED}🗑️ Removing old $config...${NC}"
        rm -rf "$HOME/$config"
    fi
    echo -e "${YELLOW}📋 Copying new $config to $HOME...${NC}"
    cp -r "$TMP_DIR/$config" "$HOME/$config"
done
echo -e "${GREEN}🧹 Old configuration files removed and new ones copied.${NC}"


# 在文件中添加以下代码
[[ "$OSTYPE" == "darwin"* ]] && cp -r "$TMP_DIR/sh-script/" "$HOME/sh-script/"


echo -e "${GREEN}✔️ New configuration files copied.${NC}"


# 清理临时目录
echo -e "${YELLOW}🧼 Cleaning up temporary files...${NC}"
rm -rf "$TMP_DIR"

echo -e "${GREEN}✔️ Temporary files removed.${NC}"
echo -e "${GREEN}✅ Script completed successfully. Files have been successfully copied to the user's home directory.${NC}"
