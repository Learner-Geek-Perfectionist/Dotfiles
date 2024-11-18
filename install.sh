#!/bin/bash

# 一旦错误，就退出
set -e

[ -d "/tmp/Dotfiles/" ] && rm -rf /tmp/Dotfiles

# 安装 git、sudo
if grep -q 'ID=ubuntu' /etc/os-release; then
    apt update -y && apt install -y git sudo
elif grep -q 'ID=fedora' /etc/os-release; then
    dnf update -y && dnf install -y git sudo
fi

echo "Cloning Dotfiles repository..."
git clone --depth=1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git /tmp/Dotfiles && cd /tmp/Dotfiles && echo "Changed directory to Dotfiles."

# 执行安装脚本
source ./main.sh
