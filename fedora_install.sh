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

# =================================开始安装 rustc=================================
if command -v rustc >/dev/null 2>&1; then
    print_centered_message "${GREEN}rustc 已安装，跳过安装。${NC}" "true" "false"
else
    print_centered_message "${GREEN}开始安装 rustc...${NC}" "true" "false"
    # 安装 rustup

    # 1. 创建系统级安装目录并设置权限
    sudo mkdir -p /opt/rust/{cargo,rustup}
    sudo chmod -R a+rw /opt/rust/cargo /opt/rust/rustup # 开放所有用户读写权限
    export CARGO_HOME=/opt/rust/cargo
    export RUSTUP_HOME=/opt/rust/rustup

    # 2. 通过 rustup 脚本安装并指定系统目录
    rustup-init -y
    # 3. 链接 cargo、rustc、rustup 到系统的PATH 中
    sudo ln -s /opt/rust/cargo/bin/* /usr/bin/
    # 4. -E 保持了环境变量
    sudo -E rustup update
    # 5. 初始化 rustup 环境
    rustup default stable
    # .rustup目录 安装在 RUSTUP_HOME；cargo、rustc、rustup、eza、rg、fd 都安装在 CARGO_HOME（但是它们符号链接在 /usr/bin/）
    print_centered_message "${GREEN} rustc 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 rustc=================================

# 安装必要的工具 🔧
install_packages "packages_fedora"

# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone >/dev/null

# 1.生成Locale数据文件（特定地区或文化环境的规则，比如日期和时间的显示格式、数字和货币的格式、文本排序规则、字符编码等)
sudo localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8

# 2.设置中文语言输出信息
echo "LANG=zh_CN.UTF-8" | sudo tee /etc/locale.conf
echo "LC_ALL=zh_CN.UTF-8" | sudo tee -a /etc/locale.conf

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
