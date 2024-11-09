#!/bin/bash

# 设置脚本在遇到错误时退出
set -e

echo "Starting script..."

# 定义临时目录路径
TMP_DIR="/tmp/dotfiles"

# 浅克隆仓库到临时目录
echo "Cloning repository into $TMP_DIR..."
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR"
echo "Repository cloned."

# 删除当前用户家目录中的旧文件和目录（如果存在）
echo "Checking and removing old configuration files if they exist..."
[ -f "$HOME/.zprofile" ] && echo "Removing old .zprofile..." && rm "$HOME/.zprofile"
[ -f "$HOME/.zshrc" ] && echo "Removing old .zshrc..." && rm "$HOME/.zshrc"
[ -d "$HOME/.config" ] && echo "Removing old .config directory..." && rm -r "$HOME/.config"
echo "Old configuration files removed."

# 复制新的文件到当前用户的家目录
echo "Copying new configuration files to $HOME..."
cp "$TMP_DIR/.zprofile" "$HOME/.zprofile"
cp "$TMP_DIR/.zshrc" "$HOME/.zshrc"
cp -r "$TMP_DIR/.config" "$HOME/.config"
echo "New configuration files copied."

# 清理临时目录
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"
echo "Temporary files removed."

echo "Script completed successfully. Files have been successfully copied to the user's home directory."
