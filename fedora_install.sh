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


sudo dnf install -y --setopt=tsflags= coreutils coreutils-common man-pages man-db && sudo dnf group install -y --setopt=strict=0 "c-development"

# 安装必要的工具 🔧
install_packages "packages_fedora"

# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null

# 设置语言环境变量
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
# 设置地区
sudo localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8


# 设置 Kotlin 的变量
setup_kotlin_environment
# 安装 Kotlin/Native 和 Kotlin-Complier
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR

download_and_extract_kotlin $KOTLIN_COMPILER_URL $COMPILER_INSTALL_DIR

# 为了避免 Dockerfile 交互式
if [[ "$AUTO_RUN" == "true" ]]; then
    echo -e "${GREEN}在 Docker 中无需安装 Docker${NC}"
else
    # 调用函数以安装和配置 Docker
    install_and_configure_docker
fi

sudo dnf clean all && sudo dnf makecache

# 安装缺失的手册，并且更新手册页的数据库
packages_to_reinstall=$(rpm -qads --qf "PACKAGE: %{NAME}\n" | sed -n -E '/PACKAGE: /{s/PACKAGE: // ; h ; b }; /^not installed/ { g; p }' | uniq)
if [ -z "$packages_to_reinstall" ]; then
    echo -e "${GREEN}没有找到需要重新安装的手册包。${NC}"
else
    sudo dnf -y reinstall $packages_to_reinstall && sudo mandb -c
fi
echo -e "${RED}当前目录: $(pwd) ${NC}"
# 配置 zsh
source ./zsh_install.sh
