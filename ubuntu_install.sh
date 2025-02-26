#!/bin/bash

# 一旦错误，就退出
set -e

# 设置国内源
sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list

# 添加PPA并更新
sudo add-apt-repository -y ppa:wireshark-dev/stable
echo "wireshark-common wireshark-common/install-setuid boolean false" | sudo debconf-set-selections
echo "wireshark-common wireshark-common/install-setuid seen true" | sudo debconf-set-selections
sudo apt update && sudo apt upgrade -y

# =================================开始安装 Kotlin/Native =================================
# 设置 Kotlin 的变量
setup_kotlin_environment
# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR
download_and_extract_kotlin $KOTLIN_COMPILER_URL $COMPILER_INSTALL_DIR
# =================================结束安装 Kotlin/Native =================================

# 安装 ubuntu 包
install_packages "packages_ubuntu"

# 取消最小化安装
sudo apt update -y && sudo apt upgrade -y && sudo apt search unminimize 2>/dev/null | grep -q "^unminimize/" && (sudo apt install unminimize -y && yes | sudo unminimize) || echo -e "${RED}unminimize包不可用。${NC}"

# =================================开始安装 fastfetch=================================
if command -v fastfetch >/dev/null 2>&1; then
    print_centered_message "${GREEN} fastfetch 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 fastfetch${NC}" "true" "false"
    git clone https://github.com/fastfetch-cli/fastfetch ~/fastfetch
    cd ~/fastfetch
    mkdir build && cd build
    cmake ..
    # 编译源码（启用多线程加速）
    make -j$(nproc)
    sudo make install
    # 清理整个项目目录，包括源码和编译目录
    cd ~
    rm -rf ~/fastfetch

    print_centered_message "${GREEN} fastfetch 安装完成 ✅${NC}" "false" "true"

fi
# =================================结束安装 fastfetch=================================

# =================================开始安装 kitty=================================
if command -v kitty >/dev/null 2>&1; then
    print_centered_message "${GREEN} kitty 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 kitty... ${NC}" "false" "false"
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n

    # 定义基础 URL
    BASE_URL="http://kr.archive.ubuntu.com/ubuntu/pool/universe/k/kitty/"

    # 使用 curl 获取页面内容，并解析出最新的 kitty-terminfo .deb 文件的版本号
    TERMINFO_LATEST_VERSION=$(curl -s "$BASE_URL" | grep -oP 'href="kitty-terminfo_[^"]*\.deb"' | sed -E 's|.*kitty-terminfo_([^"]*)\.deb.*|\1|' | sort -V | tail -1)

    # 如果找不到文件，则退出
    if [ -z "$TERMINFO_LATEST_VERSION" ]; then
        echo -e "${RED}Failed to find the kitty-terminfo .deb file.${NC}"
        exit 1
    fi

    # 构建完整的 .deb 文件下载 URL（kitty-terminfo）
    TERMINFO_URL="${BASE_URL}kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"

    # 下载和安装包（kitty-terminfo）
    echo -e "Downloading ${RED}kitty-terminfo${NC} version ${GREEN}${TERMINFO_LATEST_VERSION}${NC}"
    if curl -s -O "$TERMINFO_URL"; then
        echo "Installing kitty-terminfo..."
        if sudo dpkg -i "kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"; then
            echo -e "${GREEN}kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb 安装完成 ${NC}"
        else
            echo -e "${RED}Installation failed.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Download failed.${NC}"
        exit 1
    fi

    # 清理下载的文件
    sudo rm -rf "kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"

    # 检查是否在 WSL2 中运行或在自动化脚本环境中
    if grep -qi microsoft /proc/version || [[ "$AUTO_RUN" == "true" ]]; then
        print_centered_message "${RED}在 WSL2 中或者 Dockerfile 中不需要安装 kitty 桌面图标${NC}" "false" "false"
    else
        mkdir -p /usr/local/bin/ ~/.local/share/applications/
        sudo ln -s ~/.local/kitty.app/bin/kitty /usr/local/bin/
        # For Application Launcher:
        sudo cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
        sudo cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
        # Add Icon:
        sudo sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
        sudo sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
        sudo chmod a+x $HOME/.local/kitty.app/share/applications/kitty-open.desktop $HOME/.local/kitty.app/share/applications/kitty.desktop $HOME/.local/share/applications/kitty-open.desktop $HOME/.local/share/applications/kitty.desktop
    fi
    # 将 kitty 二进制文件复制到标准的系统路径
    sudo cp -r "$HOME/.local/kitty.app/bin" /usr/local/bin/
    print_centered_message "${GREEN} kitty 安装完成 ✅${NC}" "false" "false"

fi

# =================================结束安装 kitty=================================

# =================================开始安装 fzf=================================
if command -v fzf >/dev/null 2>&1; then
    print_centered_message "${GREEN}fzf 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 fzf... ${NC}" "true" "false"
    [[ -d "$HOME/.fzf" ]] && rm -rf "$HOME/.fzf"

    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    yes | $HOME/.fzf/install --no-update-rc

    # 将 fzf 二进制文件复制到标准的系统路径
    sudo cp "$HOME/.fzf/bin/fzf" /usr/local/bin/

    # 清理安装目录
    rm -rf "$HOME/.fzf"
    print_centered_message "${GREEN} fzf 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 fzf=================================

# =================================开始安装 rustc=================================
if command -v rustc >/dev/null 2>&1; then
    print_centered_message "${GREEN}rustc 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 rustc...${NC}" "false" "false"
    # 安装 rustup，这使得 rustc 的版本是最新的。

    # 1. 创建系统级安装目录并设置权限
    sudo mkdir -p /opt/rust/{cargo,rustup}
    sudo chmod -R a+rw /opt/rust/cargo /opt/rust/rustup # 开放所有用户读写权限
    export CARGO_HOME=/opt/rust/cargo
    export RUSTUP_HOME=/opt/rust/rustup

    # 2. 通过 rustup 脚本安装并指定系统目录
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

    # 3. 将二进制文件链接到系统 PATH 目录
    sudo ln -s /opt/rust/cargo/bin/* /usr/local/bin/
    # 4. 更新工具链到最新版本
    sudo -E rustup update # -E：保留环境变量（确保 CARGO_HOME 和 RUSTUP_HOME 生效）。

    print_centered_message "${GREEN} rustc 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 rustc=================================

# =================================开始安装 eza=================================
if command -v eza >/dev/null 2>&1; then
    print_centered_message "${GREEN}eza 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 eza... ${NC}" "true" "false"

    # 安装 eza
    cargo install eza
    print_centered_message "${GREEN} eza 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 eza=================================

# =================================开始安装 fd=================================

if command -v fd >/dev/null 2>&1; then
    print_centered_message "${GREEN}fd 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 fd... ${NC}" "false" "false"
    cargo install fd-find
    sudo ln -s $(which fd-find) /usr/local/bin/fd
    print_centered_message "${GREEN} fd 安装完成 ✅${NC}" "false" "false"
fi

# =================================结束安装 fd=================================

# =================================开始安装 rg=================================

if command -v rg >/dev/null 2>&1; then
    print_centered_message "${GREEN}rg 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 rg... ${NC}" "true" "false"
    cargo install ripgrep
    print_centered_message "${GREEN} rg 安装完成 ✅${NC}" "false" "true"
fi

# =================================结束安装 rg=================================

# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone >/dev/null
sudo dpkg-reconfigure --frontend noninteractive tzdata

# 1.生成 UTF-8 字符集的 Locale（locale-gen 适用于 Debian 及其衍生系统，localedef 存在于几乎所有的 Linux 发行版中）
sudo locale-gen zh_CN.UTF-8

# 2.设置中文语言输出信息
echo "LANG=zh_CN.UTF-8" | sudo tee /etc/default/locale
echo "LC_ALL=zh_CN.UTF-8" | sudo tee -a /etc/default/locale

# 搜索可用的 OpenJDK 包并尝试获取最新版本
jdk_version=$(apt search openjdk | grep -oP 'openjdk-\d+-jdk' | sort -V | tail -n1)
sudo apt install -y $jdk_version && print_centered_message "${GREEN}成功安装✅ ${jdk_version}${NC}" "false" "true"

# 安装最新的 lua
sudo apt install -y $(apt search '^lua[0-9.]*$' --names-only | grep -oP 'lua\d+\.\d+' | sort -V | tail -n 1)

# 为了避免 Dockerfile 交互式
if [[ "$AUTO_RUN" == "true" ]]; then
    echo -e "${GREEN}在 Docker 中无需安装 Docker${NC}"
else
    # 调用函数以安装和配置 Docker
    install_and_configure_docker
fi

sudo apt clean

echo -e "${RED}当前目录: $(pwd) ${NC}"
