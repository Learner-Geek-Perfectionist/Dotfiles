#!/bin/bash

# 一旦错误，就退出
set -e

# 设置国内源
sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list

# 安装 wireshark
sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:wireshark-dev/stable && sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y wireshark

# 安装 fastfetch
sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:zhangsongcui3371/fastfetch && sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y fastfetch

# 取消最小化安装
sudo apt update -y && sudo apt upgrade -y && sudo apt search unminimize 2> /dev/null | grep -q "^unminimize/" && (sudo apt install unminimize -y && yes | sudo unminimize) || echo -e "${RED}unminimize包不可用。${NC}"
# 在 oracular (24.10)  之后的 Ubuntu 发行版才有 eza
sudo apt update -y && sudo apt upgrade -y && sudo apt search eza 2> /dev/null | grep -q "^eza/" && (sudo apt install eza -y) || echo -e "${RED}eza包不可用。${NC}"

# 更新索引
sudo apt update && sudo apt upgrade -y

# 安装必要的工具 🔧
install_packages "packages_ubuntu"

# 安装 eza
cargo install eza

# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null
sudo dpkg-reconfigure --frontend noninteractive tzdata

# 设置地区
sudo locale-gen zh_CN.UTF-8
# 设置默认的语言环境
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8


# 定义 fzf 的安装目录
FZF_DIR="$HOME/.fzf"

# 检查 fzf 是否已安装
if command -v fzf > /dev/null 2>&1; then
    # 目录存在，跳过安装
    echo -e  "${GREEN}fzf 已安装，跳过安装。${NC}"
else
    [[ -d "$FZF_DIR" ]] && rm -rf "$FZF_DIR"

    # 目录不存在，克隆并安装 fzf
    echo -e "${RED}正在安装 fzf...${NC}"
    git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
    yes | $FZF_DIR/install --no-update-rc
    echo -e "${RED}fzf 安装完成。${NC}"
fi

# 设置 Kotlin 的变量
setup_kotlin_environment
# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR

# 搜索可用的 OpenJDK 包并尝试获取最新版本
jdk_version=$(apt search openjdk | grep -oP 'openjdk-\d+-jdk' | sort -V | tail -n1)
[ -z "$jdk_version" ] && echo -e "{RED}没有找到可用的 OpenJDK 版本。${NC}" && exit 1 || echo -e "${GREEN}找到最新的 OpenJDK 版本: ${jdk_version} ${NC}"

# 为了避免 Dockerfile 交互式
if [[ "$AUTO_RUN" == "true" ]]; then
    echo -e "${GREEN}在 Docker 中无需安装 Docker${NC}"
else
    # 调用函数以安装和配置 Docker
    install_and_configure_docker
fi
echo -e "${RED}当前目录: $(pwd) ${NC}"
# 配置 zsh
source ./zsh_install.sh
