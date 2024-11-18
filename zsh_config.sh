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

echo -e "${GREEN}🚀 Starting script...${NC}"
cd $HOME

# 定义临时目录路径
TMP_DIR="/tmp/Dotfiles/"

if [[ ! -d /tmp/Dotfiles ]]; then
    # 浅克隆仓库到临时目录
    echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
    git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
        echo "Failed to clone repository"
        exit 1
    }
    echo -e "${GREEN}✔️ Repository cloned.${NC}"
fi

# 定义配置列表
configs=(".zshenv" ".zprofile" ".zshrc" ".config")

# 删除旧配置和复制新配置
echo -e "${YELLOW}🔍 Checking and removing old configuration files if they exist...${NC}"
for config in "${configs[@]}"; do
    if [ -f "$HOME/$config" ] || [ -d "$HOME/$config" ]; then
        echo -e "${RED}🗑️ Removing old $config...${NC}"
        rm -rf "$HOME/$config"
    fi
    echo -e "${PURPLE}📋 Copying new $config to $HOME...${NC}"
    cp -r "$TMP_DIR/$config" "$HOME/$config"
done
echo -e "${GREEN}🧹 Old configuration files removed and new ones copied.${NC}"

# 在文件中添加以下代码
[[ "$(uname)" == "Darwin" ]] && cp -r "$TMP_DIR/sh-script/" "$HOME/sh-script/"

echo -e "${GREEN}✔️ New configuration files copied.${NC}"

# 清理临时目录
echo -e "${YELLOW}🧼 Cleaning up temporary files...${NC}"
rm -rf "$TMP_DIR"
rm -rf /tmp/Fonts/

echo -e "${GREEN}✔️ Temporary files removed.${NC}"
echo -e "${GREEN}✅ Script completed successfully. Files have been successfully copied to the user's home directory.${NC}"
