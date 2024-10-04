#!/bin/zsh

# 检查 Xcode 命令行工具是否已安装
xcode-select --print-path &>/dev/null
if [[ $? -ne 0 ]]; then
    echo "Xcode 命令行工具未安装，现在将进行安装..."
    xcode-select --install
    # 等待用户完成 Xcode 命令行工具的安装
    read -p "请按回车继续..."
fi

# 检查 Git 是否已安装
if ! type git &>/dev/null; then
    echo "Git 未安装，现在将通过 Xcode 命令行工具安装 Git..."
    # 使用 Xcode 自带的 Git
    sudo xcode-select --reset
fi

# 安装 Homebrew
echo "正在安装 Homebrew..."
/bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
