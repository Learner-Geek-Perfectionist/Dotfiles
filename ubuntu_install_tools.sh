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
        mkdir -p ~/.local/share/applications/
        # For Application Launcher:
        sudo cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
        sudo cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
        # Add Icon:
        sudo sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
        sudo sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
        sudo chmod a+x $HOME/.local/kitty.app/share/applications/kitty-open.desktop $HOME/.local/kitty.app/share/applications/kitty.desktop $HOME/.local/share/applications/kitty-open.desktop $HOME/.local/share/applications/kitty.desktop
    fi
    # 将 kitty 二进制文件复制到标准的系统路径
    sudo cp -r $HOME/.local/kitty.app/bin/* /usr/bin/
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
    sudo cp "$HOME/.fzf/bin/fzf" /usr/bin/

    # 清理安装目录
    rm -rf "$HOME/.fzf"
    print_centered_message "${GREEN} fzf 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 fzf=================================

export CARGO_HOME=/opt/rust/cargo
export RUSTUP_HOME=/opt/rust/rustup
# =================================开始安装 rustc=================================
if command -v rustc >/dev/null 2>&1; then
    print_centered_message "${GREEN}rustc 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 rustc...${NC}" "false" "false"
    # 安装 rustup

    # 1. 创建系统级安装目录并设置权限
    sudo mkdir -p /opt/rust/{cargo,rustup}
    sudo chmod -R a+rw /opt/rust/cargo /opt/rust/rustup # 开放所有用户读写权限

    # 2. 通过 rustup 脚本安装并指定系统目录
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
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

# =================================开始安装 eza=================================
if command -v eza >/dev/null 2>&1; then
    print_centered_message "${GREEN}eza 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 eza... ${NC}" "true" "false"

    # 安装 eza
    cargo install eza
    sudo ln -s /opt/rust/cargo/bin/eza /usr/bin/
    print_centered_message "${GREEN} eza 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 eza=================================

# =================================开始安装 fd=================================

if command -v fd >/dev/null 2>&1; then
    print_centered_message "${GREEN}fd 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 fd... ${NC}" "false" "false"
    cargo install fd-find
    sudo ln -s /opt/rust/cargo/bin/fd /usr/bin/
    print_centered_message "${GREEN} fd 安装完成 ✅${NC}" "false" "false"
fi

# =================================结束安装 fd=================================

# =================================开始安装 rg=================================

if command -v rg >/dev/null 2>&1; then
    print_centered_message "${GREEN}rg 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 rg... ${NC}" "true" "false"
    cargo install ripgrep
    sudo ln -s /opt/rust/cargo/bin/rg /usr/bin/
    print_centered_message "${GREEN} rg 安装完成 ✅${NC}" "false" "true"
fi

# =================================结束安装 rg=================================

# =================================开始安装 bat=================================

if command -v bat >/dev/null 2>&1; then
    print_centered_message "${GREEN}bat 已安装，跳过安装。${NC}" "false" "true"
else
    print_centered_message "${GREEN}开始安装 bat... ${NC}" "false" "false"
    cargo install bat
    sudo ln -s /opt/rust/cargo/bin/bat /usr/bin/
    print_centered_message "${GREEN} bat 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 bat=================================

