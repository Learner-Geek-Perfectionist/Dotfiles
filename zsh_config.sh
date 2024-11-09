#!/bin/bash

# 设置脚本在遇到错误时退出
set -e

# 定义临时目录路径
TMP_DIR="/tmp/dotfiles"

# 浅克隆仓库到临时目录
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR"

# 删除当前用户家目录中的旧文件和目录（如果存在）
[ -f "$HOME/.zprofile" ] && rm "$HOME/.zprofile"
[ -f "$HOME/.zshrc" ] && rm "$HOME/.zshrc"
[ -d "$HOME/.config" ] && rm -r "$HOME/.config"

# 复制新的文件到当前用户的家目录
cp "$TMP_DIR/.zprofile" "$HOME/.zprofile"
cp "$TMP_DIR/.zshrc" "$HOME/.zshrc"
cp -r "$TMP_DIR/.config" "$HOME/.config"

rm -rf "$TMP_DIR"

echo "Files have been successfully copied to the user's home directory."
