#!/bin/bash

# 一旦错误，就退出
set -e

[ -d "Dotfiles" ] && rm -rf Dotfiles
echo "Cloning Dotfiles repository..."
GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone --depth=1 git@github.com:Learner-Geek-Perfectionist/Dotfiles.git && cd Dotfiles && echo "Changed directory to Dotfiles."

# 执行安装脚本
source ./main.sh
