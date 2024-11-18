#!/bin/bash

# 一旦错误，就退出
set -e

[ -d "/tmp/Dotfiles/" ] && rm -rf /tmp/Dotfiles/

# 安装 git、sudo
if grep -q 'ID=ubuntu' /etc/os-release; then
    sudo apt update -y && sudo apt install -y git
elif grep -q 'ID=fedora' /etc/os-release; then
    sudo dnf update -y && sudo dnf install -y git
fi

echo "Cloning Dotfiles repository..."
git clone --depth=1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git /tmp/Dotfiles && cd /tmp/Dotfiles && echo "Changed directory to Dotfiles."

# 执行安装脚本
source ./main.sh
