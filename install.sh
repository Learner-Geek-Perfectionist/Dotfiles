#!/bin/bash

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

echo "操作完成，请按任意键继续。"
read -n 1  # 等待用户按任意键
