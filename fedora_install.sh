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
sudo usermod -aG wireshark $USER

# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null

# 设置语言环境变量
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

sudo localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8

# 安装 Kotlin/Native 和 Kotlin
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR
download_and_extract_kotlin $KOTLIN_COMPILER_URL $COMPILER_INSTALL_DIR

# 调用函数以安装和配置 Docker
install_and_configure_docker

sudo dnf clean all && sudo dnf makecache
# 安装缺失的手册，并且更新手册页的数据库
packages_to_reinstall=$(rpm -qads --qf "PACKAGE: %{NAME}\n" | sed -n -E '/PACKAGE: /{s/PACKAGE: // ; h ; b }; /^not installed/ { g; p }' | uniq)
[ -z "$packages_to_reinstall" ] && echo "没有找到需要重新安装的手册包。" || sudo dnf -y reinstall $packages_to_reinstall && sudo mandb -c
