#!/bin/zsh

# 检查操作系统类型
OS=$(uname)
if [ "$OS" = "Darwin" ]; then
    echo "检测到 macOS 系统。"
    # macOS 特定命令
    xcode-select --print-path &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Xcode 命令行工具未安装，现在将进行安装..."
        xcode-select --install
        read -p "请按回车继续..."
    fi

    if ! type git &>/dev/null; then
        echo "Git 未安装，尝试通过 Xcode 命令行工具安装 Git..."
        sudo xcode-select --reset
    fi

    echo "正在安装 Homebrew..."
    /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
elif [ "$OS" = "Linux" ]; then
    echo "检测到 Linux 系统。"
    # Linux 特定命令
    if ! type git &>/dev​⬤
