#!/usr/bin/env sh

# 判断操作系统
OS_TYPE=$(uname)
if [[ "$OS_TYPE" == "Darwin" ]]; then
    # macOS 逻辑
    echo "检测到 macOS 系统"

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
elif [[ "$OS_TYPE" == "Linux" ]]; then
    # Linux 逻辑
    echo "检测到 Linux 系统"

    # 设置环境变量
    export TZ=Asia/Shanghai

    # 设置时区
    echo $TZ > /etc/timezone && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime

    # 设置中科大镜像
    sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
        -i.bak \
        /etc/yum.repos.d/fedora.repo \
        /etc/yum.repos.d/fedora-updates.repo

    # 更新软件源缓存
    dnf makecache

    # 安装必要的软件
    dnf update -y && \
    dnf install -y \
    openssh-server \
    iproute \
    net-tools \
    fd-find \
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
    dnf group install -y "C Development Tools and Libraries" && \
    dnf clean all

    # 首先询问是否要创建用户
    read -p "是否需要创建用户？(y/n): " create_confirm

    if [[ $create_confirm == 'y' ]]; then
        # 提示输入用户名
        read -p "请输入你想创建的用户名: " username

        # 检查用户是否存在
        if id "$username" &>/dev/null; then
            echo "用户 $username 已存在。"
            # 检查密码是否已设置
            if ! sudo passwd -S "$username" | grep -q ' P ' ; then
                echo "用户 $username 的密码未设置，现在将设置密码为 '1'。"
                echo "$username:1" | sudo chpasswd
                echo "密码已设置。"
            else
                echo "用户 $username 的密码已经存在。"
            fi
        else
            sudo useradd -m "$username"  # 创建用户
            echo "$username:1" | sudo chpasswd  # 设置密码
            echo "用户 $username 已创建，密码设置为 '1'。"
            # 配置用户无需 sudo 密码
            sudo usermod -aG wheel "$username"
            echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
            echo "已配置用户 $username 无需 sudo 密码。"
        fi
    else
        echo "不创建用户，脚本结束。"
    fi

else
    echo "未知的操作系统类型"
fi

echo "操作完成，请按任意键继续。"
read -n 1  # 等待用户按任意键
