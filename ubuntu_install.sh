#!/bin/bash

# 一旦错误，就退出
set -e

# 设置国内源
sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list && sudo apt update 

# =================================开始安装 wireshark=================================
if ! command -v wireshark >/dev/null 2>&1; then
    print_centered_message   "${GREEN}开始安装 wireshark${NC}" "true" "false"
    sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:wireshark-dev/stable
    sudo DEBIAN_FRONTEND=noninteractive apt install -y wireshark
else
    print_centered_message   "${GREEN}Wireshark 已安装，跳过安装。${NC}" "false" "false"
fi
# =================================结束安装 wireshark=================================


# =================================开始安装 fastfetch=================================
if ! command -v fastfetch > /dev/null 2>&1; then
    print_centered_message   "${GREEN}开始安装 fastfetch${NC}" "true" "false"
    sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:zhangsongcui3371/fastfetch &&  sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y fastfetch
    
else
     print_centered_message   "${GREEN} fastfetch 已安装，跳过安装。${NC}" "true" "false"
fi
# =================================结束安装 fastfetch=================================


# =================================开始安装 kitty=================================
if ! command -v kitty > /dev/null 2>&1; then
    print_centered_message  "${RED}开始安装 kitty... ${NC}" "true" "false"
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
    echo -e  "${GREEN}kitty 安装完成 ✅" 
    # 检查是否在 WSL2 中运行或在自动化脚本环境中
    if grep -qi microsoft /proc/version || [[ "$AUTO_RUN" == "true" ]]; then
        print_centered_message  "${RED}在 WSL2 中或者 Dockerfile 中不需要安装 kitty 桌面图标${NC}" "false" "false"
    else
        sudo ln -s ~/.local/kitty.app/bin/kitty /usr/local/bin/
        # For Application Launcher:
        cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
        cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
        # Add Icon:
        sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
        sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
        # Allow-launching of the shortcut:
        DESKTOP_PATH=$(xdg-user-dir DESKTOP)
        gio set ${DESKTOP_PATH}/kitty*.desktop metadata::trusted true
        chmod a+x ~/Desktop/kitty*.desktop
    fi
else
    print_centered_message   "${GREEN} kitty 已安装，跳过安装。${NC}" "true" "false"
fi

# =================================结束安装 kitty=================================


# =================================开始安装 fzf=================================
if command -v fzf > /dev/null 2>&1; then
    print_centered_message  "${GREEN}fzf 已安装，跳过安装。${NC}"  "false" "true"
else
    print_centered_message  "${RED}开始安装 fzf... ${NC}" "true" "false"
    [[ -d "$HOME/.fzf" ]] && rm -rf "$HOME/.fzf"

    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    yes | $HOME/.fzf/install --no-update-rc
    print_centered_message "${GREEN} fzf 安装完成 ✅${NC}" "false" "true"
fi 
# =================================结束安装 fzf=================================


# 更新索引
sudo apt update && sudo apt upgrade -y
# 安装必要的工具 🔧
install_packages "packages_ubuntu"

# 取消最小化安装
sudo apt update -y && sudo apt upgrade -y && sudo apt search unminimize 2> /dev/null | grep -q "^unminimize/" && (sudo apt install unminimize -y && yes | sudo unminimize) || echo -e "${RED}unminimize包不可用。${NC}"


# =================================开始安装 eza=================================
if command -v eza > /dev/null 2>&1; then
    print_centered_message  "${GREEN}eza 已安装，跳过安装。${NC}"  "true" "true"
else
    print_centered_message  "${RED}开始安装 eza... ${NC}" "true" "false"
    # 安装 eza, 在 oracular (24.10)  之后的 Ubuntu 发行版才有 eza
    cargo install eza
    print_centered_message "${GREEN} eza 安装完成 ✅" "true" "false"
fi 
# =================================结束安装 eza=================================


# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null
sudo dpkg-reconfigure --frontend noninteractive tzdata

# 设置地区
sudo locale-gen zh_CN.UTF-8
# 设置默认的语言环境
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8


# 设置 Kotlin 的变量
setup_kotlin_environment
# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR

# 搜索可用的 OpenJDK 包并尝试获取最新版本
jdk_version=$(apt search openjdk | grep -oP 'openjdk-\d+-jdk' | sort -V | tail -n1)
sudo apt install -y $jdk_version && print_centered_message  "${GREEN}成功安装 ${jdk_version}${NC}" "true" "false"


# 为了避免 Dockerfile 交互式
if [[ "$AUTO_RUN" == "true" ]]; then
    echo -e "${GREEN}在 Docker 中无需安装 Docker${NC}"
else
    # 调用函数以安装和配置 Docker
    install_and_configure_docker
fi
echo -e "${RED}当前目录: $(pwd) ${NC}"
