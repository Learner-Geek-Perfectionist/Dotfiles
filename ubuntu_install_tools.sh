# =================================开始安装 cmake=================================
if command -v cmake >/dev/null 2>&1; then
    print_centered_message "${GREEN}cmake 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 cmake... ${NC}" "true" "false"
    # 动态添加仓库
    sudo mkdir -p /etc/apt/keyrings
    sudo wget -qO- https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo gpg --dearmor -o /etc/apt/keyrings/kitware.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kitware.gpg] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
    
    # 安装 CMake
    sudo apt update && sudo apt install -y cmake
    print_centered_message "${GREEN} cmake 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 cmake=================================

# =================================开始安装 fastfetch=================================
if command -v fastfetch >/dev/null 2>&1; then
    print_centered_message "${GREEN} fastfetch 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 fastfetch${NC}" "false" "false"
    git clone https://github.com/fastfetch-cli/fastfetch
    cd fastfetch
    mkdir build && cd build
    cmake ..
    # 编译源码（启用多线程加速）
    make "-j$(nproc)" && sudo make install
    # 清理整个项目目录，包括源码和编译目录
    cd ../.. && sudo rm -rf fastfetch
    
    print_centered_message "${GREEN} fastfetch 安装完成 ✅${NC}" "false" "false"
    
fi
# =================================结束安装 fastfetch=================================

# =================================开始安装 kitty=================================
if command -v kitty >/dev/null 2>&1; then
    print_centered_message "${GREEN} kitty 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 kitty... ${NC}" "true" "false"
    sudo mkdir -p /opt/kitty && sudo chmod -R a+rw /opt/kitty
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n dest=/opt/kitty
    
    # 定义基础 URL
    BASE_URL="http://kr.archive.ubuntu.com/ubuntu/pool/universe/k/kitty/"
    
    # 使用 curl 获取页面内容，并解析出最新的 kitty-terminfo .deb 文件的版本号
    TERMINFO_LATEST_VERSION=$(curl -s "$BASE_URL" | grep -oP 'href="kitty-terminfo_[^"]*\.deb"' | sed -E 's|.*kitty-terminfo_([^"]*)\.deb.*|\1|' | sort -V | tail -1)
    DOCS_LATEST_VERSION=$TERMINFO_LATEST_VERSION
    # 如果找不到文件，则退出
    if [ -z "$TERMINFO_LATEST_VERSION" ]; then
        echo -e "${RED}Failed to find the kitty-terminfo .deb file.${NC}"
        exit 1
    fi
    
    # 构建完整的 .deb 文件下载 URL（kitty-terminfo）
    TERMINFO_URL="${BASE_URL}kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"
    DOC_URL="${BASE_URL}kitty-doc_${DOCS_LATEST_VERSION}.deb"
    
    # 下载和安装包（kitty-terminfo）
    echo -e "Downloading ${RED}kitty-terminfo${NC} version ${GREEN}${TERMINFO_LATEST_VERSION}${NC}"
    
    curl -s -O "$TERMINFO_URL" || echo -e "${RED}Download failed.${NC}"
    echo "Installing kitty-terminfo..."
    sudo dpkg -i "./kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb" || (echo -e "${RED}Installation failed.${NC}" && exit 1)
    echo -e "${GREEN}kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb 安装完成 ${NC}"
    
    # 下载和安装包（kitty-doc）
    echo -e "Downloading ${RED}kitty-doc${NC} version ${GREEN}${DOCS_LATEST_VERSION}${NC}"
    
    curl -s -O "$DOC_URL" || echo -e "${RED}Download failed.${NC}"
    echo "Installing kitty-doc..."
    sudo dpkg -i "./kitty-doc_${DOCS_LATEST_VERSION}.deb" || echo -e "${RED}Installation failed.${NC}"
    echo -e "${GREEN}kitty-doc_${DOCS_LATEST_VERSION}.deb 安装完成 ${NC}"

    # 清理下载的文件
    sudo rm -rf "kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb" "kitty-docs_${DOCS_LATEST_VERSION}.deb"
    
    # 检查是否在 WSL2 中运行或在自动化脚本环境中
    if grep -qi microsoft /proc/version || [[ "$AUTO_RUN" == "true" ]]; then
        print_centered_message "${RED}在 WSL2 中或者 Docker 中不需要安装 kitty 桌面图标${NC}" "false" "false"
    else
        mkdir -p ~/.local/share/applications/
        # For Application Launcher:
        sudo cp /opt/kitty/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
        sudo cp /opt/kitty/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
        # Add Icon:
        sudo sed -i "s|Icon=kitty|Icon=/opt/kitty/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
        sudo sed -i "s|Exec=kitty|Exec=/opt/kitty/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
        touch ~/.config/xdg-terminals.list
        # Make xdg-terminal-exec (and hence desktop environments that support it use kitty)
        echo 'kitty.desktop' >~/.config/xdg-terminals.list
    fi
    # 将 kitty 二进制文件复制到标准的系统路径
    sudo ln -s /opt/kitty/kitty.app/bin/* /usr/bin/
    print_centered_message "${GREEN} kitty 安装完成 ✅${NC}" "false" "true"
    
fi

# =================================结束安装 kitty=================================

# =================================开始安装 fzf=================================
if command -v fzf >/dev/null 2>&1; then
    print_centered_message "${GREEN}fzf 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 fzf... ${NC}" "false" "false"
    [[ -d "/tmp/.fzf" ]] && sudo rm -rf "/tmp/.fzf"
    [[ -f "/usr/bin/fzf" ]] && sudo rm -rf "/usr/bin/fzf"
    
    git clone --depth=1 https://github.com/junegunn/fzf.git "/tmp/.fzf"
    yes | /tmp/.fzf/install --no-update-rc
    sudo cp "/tmp/.fzf/bin/fzf" /usr/bin/fzf
    
    # 清理安装目录
    sudo rm -rf "/tmp/.fzf"
    print_centered_message "${GREEN} fzf 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 fzf=================================

export CARGO_HOME=/opt/rust/cargo
export RUSTUP_HOME=/opt/rust/rustup
# =================================开始安装 rustc=================================
if command -v rustc >/dev/null 2>&1; then
    print_centered_message "${GREEN}rustc 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 rustc...${NC}" "true" "false"
    # 安装 rustup
    
    # 1. 创建系统级安装目录并设置权限
    sudo mkdir -p /opt/rust/{cargo,rustup}
    sudo chmod -R a+rw /opt/rust/
    
    # 2. 通过 rustup 脚本安装并指定系统目录
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    # 3. 链接 cargo、rustc、rustup 到系统的PATH 中
    sudo ln -s /opt/rust/cargo/bin/* /usr/bin/
    # 4. -E 保持了环境变量
    sudo -E rustup update
    # 5. 初始化 rustup 环境
    rustup default stable
    # .rustup目录 安装在 RUSTUP_HOME；cargo、rustc、rustup、eza、rg、fd 都安装在 CARGO_HOME（但是它们符号链接在 /usr/bin/）
    print_centered_message "${GREEN} rustc 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 rustc=================================

# =================================开始安装 eza=================================
if command -v eza >/dev/null 2>&1; then
    print_centered_message "${GREEN}eza 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 eza... ${NC}" "false" "false"
    
    # 安装 eza
    cargo install eza
    sudo ln -s /opt/rust/cargo/bin/eza /usr/bin/
    print_centered_message "${GREEN} eza 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 eza=================================

# =================================开始安装 fd=================================

if command -v fd >/dev/null 2>&1; then
    print_centered_message "${GREEN}fd 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 fd... ${NC}" "true" "false"
    cargo install fd-find
    sudo ln -s /opt/rust/cargo/bin/fd /usr/bin/
    print_centered_message "${GREEN} fd 安装完成 ✅${NC}" "false" "true"
fi

# =================================结束安装 fd=================================

# =================================开始安装 rg=================================

if command -v rg >/dev/null 2>&1; then
    print_centered_message "${GREEN}rg 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 rg... ${NC}" "false" "false"
    cargo install ripgrep
    sudo ln -s /opt/rust/cargo/bin/rg /usr/bin/
    print_centered_message "${GREEN} rg 安装完成 ✅${NC}" "false" "false"
fi

# =================================结束安装 rg=================================

# =================================开始安装 bat=================================

if command -v bat >/dev/null 2>&1; then
    print_centered_message "${GREEN}bat 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 bat... ${NC}" "true" "false"
    cargo install bat
    sudo ln -s /opt/rust/cargo/bin/bat /usr/bin/
    print_centered_message "${GREEN} bat 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 bat=================================

# =================================开始安装 lua=================================

if command -v lua >/dev/null 2>&1; then
    print_centered_message "${GREEN}lua 已安装，跳过安装。${NC}" "false" "true"
else
    print_centered_message "${GREEN}开始安装 lua... ${NC}" "false" "false"
    LUA_LATEST_VERSION=$(curl -s https://www.lua.org/ftp/ | grep -o 'lua-[0-9]*\.[0-9]*\.[0-9]*\.tar\.gz' | sort -V | tail -n 1)
    curl -O "https://www.lua.org/ftp/$LUA_LATEST_VERSION"
    tar -xzvf "$LUA_LATEST_VERSION"
    cd "${LUA_LATEST_VERSION%.tar.gz}"
    make "-j$(nproc)" && sudo make install
    cd .. && sudo rm -rf "${LUA_LATEST_VERSION%.tar.gz}" "$LUA_LATEST_VERSION"
    
    print_centered_message "${GREEN} lua 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 lua=================================
