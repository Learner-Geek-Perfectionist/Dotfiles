#!/bin/bash

# 一旦错误，就退出
set -e

# 设置国内源
sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list

# 取消最小化安装
sudo apt update -y && sudo apt upgrade -y && sudo apt search unminimize 2> /dev/null | grep -q "^unminimize/" && (sudo apt install unminimize -y && yes | sudo unminimize) || echo "unminimize包不可用。"

# 设置 Debconf，允许非root用户捕获数据包
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
# 以非交互模式安装 Wireshark
sudo DEBIAN_FRONTEND=noninteractive apt install -y wireshark

# 安装必要的工具 🔧
sudo apt update && sudo apt upgrade -y
sudo apt install -y "${packages_ubuntu[@]}"

# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null
sudo dpkg-reconfigure --frontend noninteractive tzdata

# 设置地区
sudo locale-gen zh_CN.UTF-8

# 设置默认的语言环境
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

# 设置抓包权限
sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap
sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/tcpdump

# 定义 fzf 的安装目录
FZF_DIR="$HOME/.fzf"

# 检查 fzf 是否已安装
if command -v fzf > /dev/null 2>&1; then
    # 目录存在，跳过安装
    echo "fzf 已安装，跳过安装。"
else
    [ -d "$FZF_DIR" ] && rm -rf "$FZF_DIR"

    # 目录不存在，克隆并安装 fzf
    echo "正在安装 fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
    yes | $FZF_DIR/install --no-update-rc
    echo "fzf 安装完成。"
fi

# 手动安装 fastfetch
# 检查 fastfetch 是否已经安装
if command -v fastfetch > /dev/null 2>&1; then
    echo "fastfetch 已经安装。跳过安装步骤。"
else
    echo "开始安装 fastfetch..."

    # 克隆 fastfetch 源码
    git clone --depth=1 https://github.com/LinusDierheimer/fastfetch.git
    cd fastfetch

    # 创建构建目录并编译项目
    mkdir build && cd build
    cmake ..
    make -j32

    # 安装 fastfetch
    sudo make install

    # 清理（可选）
    cd ../.. && rm -rf fastfetch

    echo "fastfetch 安装完成。"
fi

# 设置 Kotlin 的变量
setup_kotlin_environment
# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR

# 搜索可用的 OpenJDK 包并尝试获取最新版本
jdk_version=$(apt search openjdk | grep -oP 'openjdk-\d+-jdk' | sort -V | tail -n1)
[ -z "$jdk_version" ] && echo "没有找到可用的 OpenJDK 版本。" && exit 1 || echo "找到最新的 OpenJDK 版本: $jdk_version"

# 为了避免 Dockerfile 交互式
if [ "$AUTO_RUN" == "true" ]; then
    echo "在 Docker 中无需安装 Docker"
else
    # 调用函数以安装和配置 Docker
    install_and_configure_docker
fi
echo -e "${RED}当前目录: $(pwd) ${NC}"
# 配置 zsh
source ./zsh_install.sh
