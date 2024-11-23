#!/bin/bash

# 一旦错误，就退出
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

[ -d "/tmp/Dotfiles/" ] && rm -rf /tmp/Dotfiles/

if [[ $(uname -s) == "Linux" ]]; then

    local default_password=1
    if ! sudo passwd -S "$(whoami)" | grep -q ' P '; then
        echo -n "用户 $(whoami) 的密码未设置，现在将密码设置为 「${RED}${default_pass}${NC}」 。"
        echo "$(whoami):${default_password}" | sudo chpasswd
        echo "密码已设置。"
    else
        echo "用户 $user 的密码已经存在。"
    fi
    
    # 将用户添加到 sudoers 文件以免输入密码
    echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
    echo -e  "${LIGHT_BLUE}已配置用户 $(whoami) 无需 sudo 密码。${NC}"
    
    # 安装 git、sudo
    if grep -q 'ID=ubuntu' /etc/os-release; then
        sudo apt update -y && sudo apt install -y git
    elif grep -q 'ID=fedora' /etc/os-release; then
        sudo dnf update -y && sudo dnf install -y git
    fi
fi

echo -e "${BLUE}Cloning Dotfiles repository...${NC}"
git clone --depth=1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git /tmp/Dotfiles && cd /tmp/Dotfiles && echo -e "${GREEN}Changed directory to ${RED}$(pwd).${NC}"

# 执行安装脚本
source ./main.sh
