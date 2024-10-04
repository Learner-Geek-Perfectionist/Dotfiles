#!/bin/bash

# 获取当前操作系统类型
OS_TYPE=$(uname)

if [[ "$OS_TYPE" == "Darwin" ]]; then
    # macOS 逻辑
    echo "检测到 macOS 系统"
    unzip master.zip
    # 检查 Xcode 命令行工具是否已安装
    xcode-select --print-path &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Xcode 命令行工具未安装，现在将进行安装..."
        xcode-select --install
        # 等待用户完成 Xcode 命令行工具的安装
        read -p "请按回车继续..." < /dev/tty
    fi

    # 检查 Git 是否已安装
    if ! type git &>/dev/null; then
        echo "Git 未安装，现在将通过 Xcode 命令行工具安装 Git..."
        xcode-select --reset
    fi

    # 安装 Homebrew
    echo "正在安装 Homebrew..."
    /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    # Linux 逻辑
    echo "检测到 Linux 系统"

    # 首先询问是否要创建用户
    read -p "是否需要创建用户？(y/n): " create_confirm < /dev/tty

    if [[ $create_confirm == 'y' ]]; then
        # 提示输入用户名
        read -p "请输入你想创建的用户名: " username < /dev/tty

        # 检查用户是否存在
        if id "$username" &>/dev/null; then
            echo "用户 $username 已存在。"
            # 检查密码是否已设置
            if ! sudo passwd -S "$username" | grep -q ' P ' ; then
                echo "用户 $username 的密码未设置，现在将密码设置为 1 "
                echo "$username:1" | sudo chpasswd
                echo "密码已设置。"
            else
                echo "用户 $username 的密码已经存在。"
            fi
        else
            sudo useradd -m "$username"  # 创建用户
            echo "$username:1" | sudo chpasswd  # 设置密码
            echo "用户 $username 已创建，密码设置为 1 "
            # 配置用户无需 sudo 密码
            sudo usermod -aG wheel "$username"
            echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
            echo "已配置用户 $username 无需 sudo 密码。"
        fi
    else
        echo "不创建用户，脚本结束。"
    fi
    
    sudo -v
    # 安装必要的软件
    sudo dnf update -y && \
    sudo dnf install -y \
    openssh-server \
    iproute \
    net-tools \
    fd-find \
    git \
    unzip \
    ripgrep \
    fzf \
    ninja-build \
    neovim \
    ruby \
    kitty \
    cmake \
    nodejs \
    iputils \
    procps-ng \
    htop \
    traceroute \
    fastfetch \
    tree \
    zsh && \
    sudo dnf group install -y "C Development Tools and Libraries" && \
    sudo dnf clean all
else
    echo "未知的操作系统类型"
fi

echo "操作完成，请按任意键继续。"
read -n 1 < /dev/tty  # 等待用户按任意键

cd ./dotfiles-master

# 定义需要复制的文件和目录
files_to_copy=(".zshrc" ".zprofile" ".config")

# 获取用户的 home 目录路径
destination="$HOME"

# 循环遍历每个文件和目录
for item in "${files_to_copy[@]}"; do
    # 检查当前目录中文件或目录是否存在
    if [ -e "$item" ]; then
        echo "正在复制 $item 到 $destination"
        # 复制文件或目录到 home 目录，如果存在则替换
        cp -r "$item" "$destination"
    else
        echo "$item 不存在，跳过复制。"
    fi
done

echo "复制完成。"


# 字体源目录
font_source="./fonts"

# 确认字体源目录存在
if [ ! -d "$font_source" ]; then
    echo "字体目录 '$font_source' 不存在，请确认当前目录下有 'fonts' 文件夹。"
    exit 1
fi

# 复制字体文件到目标目录
echo "正在复制字体文件到 $destination..."
cp -v "$font_source"/* "$destination"

# 更新字体缓存
echo "更新字体缓存..."
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS不需要手动更新字体缓存
    echo "在 macOS 上，字体缓存将自动更新。"
else
    # Linux
    fc-cache -fv
fi

echo "字体安装完成。"


echo "配置 zsh ......"
zsh
