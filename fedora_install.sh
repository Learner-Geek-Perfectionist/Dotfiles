#!/bin/bash

# 一旦错误，就退出
set -e

# 注释 tsflags=nodocs，从而安装 manual 手册
    sudo sed -i '/tsflags=nodocs/s/^/#/' /etc/dnf/dnf.conf

    # 设置国内源
    sudo sed -e 's|^metalink=|#metalink=|g' \
      -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
      -i.bak \
      /etc/yum.repos.d/fedora.repo \
      /etc/yum.repos.d/fedora-updates.repo

    # 安装必要的工具 🔧
    sudo dnf -y update && sudo dnf install -y "${packages_fedora[@]}"
    sudo dnf install -y --setopt=tsflags= coreutils coreutils-common man-pages man-db && sudo dnf group install -y --setopt=strict=0 "c-development"


    # 设置 wireshark 权限
    # 1. 将 dumpcap 设置为允许 wireshark 组的成员执行：
    sudo chgrp wireshark /usr/bin/dumpcap
    sudo chmod 4755 /usr/bin/dumpcap
    sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap
    # 2.将用户添加到 wireshark 组：
    sudo usermod -aG wireshark $username



    # 设置时区
    sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null

    # 设置语言环境变量
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8

    sudo localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8

    # 检查 SDKMAN 是否已经安装
    if [ ! -d "$HOME/.sdkman" ]; then
        echo "SDKMAN not found, installing..."

        # 下载并安装SDKMAN
        /bin/bash -c "$(curl -fsSL https://get.sdkman.io)"

        echo "SDKMAN installed successfully."
    else
        echo "SDKMAN is already installed."
    fi


    # 初始化SDKMAN环境
    source "$HOME/.sdkman/bin/sdkman-init.sh"

    # 安装 kotlin
    command -v kotlin >/dev/null && echo "Kotlin已安装，无需再次安装。" || (echo "Kotlin未安装，现在开始安装。" && sdk install kotlin)


    # 安装 Kotlin/Native
    install_kotlin_native "linux"


    # 调用函数以安装和配置 Docker
    install_and_configure_docker

    sudo dnf clean all && sudo dnf makecache
    # 安装缺失的手册，并且更新手册页的数据库
    packages_to_reinstall=$(rpm -qads --qf "PACKAGE: %{NAME}\n" | sed -n -E '/PACKAGE: /{s/PACKAGE: // ; h ; b }; /^not installed/ { g; p }' | uniq); [ -z "$packages_to_reinstall" ] && echo "没有找到需要重新安装的手册包。" || sudo dnf -y reinstall $packages_to_reinstall && sudo mandb -c
