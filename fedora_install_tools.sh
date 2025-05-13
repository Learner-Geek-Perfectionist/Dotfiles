# =================================开始安装 fastfetch=================================
if command -v fastfetch >/dev/null 2>&1; then
    print_centered_message "${GREEN} fastfetch 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 fastfetch${NC}" "true" "false"
    rm -rf fastfetch && git clone https://github.com/fastfetch-cli/fastfetch
    cd fastfetch
    mkdir build && cd build
    cmake ..
    # 编译源码（启用多线程加速）
    make "-j$(nproc)" && sudo make install
    # 清理整个项目目录，包括源码和编译目录
    cd ../.. && sudo rm -rf fastfetch

    print_centered_message "${GREEN} fastfetch 安装完成 ✅${NC}" "false" "true"

fi
# =================================结束安装 fastfetch=================================

# =================================开始安装 fzf=================================
if command -v fzf >/dev/null 2>&1; then
    print_centered_message "${GREEN}fzf 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 fzf... ${NC}" "false" "false"
    [[ -d "/tmp/.fzf" ]] && sudo rm -rf "/tmp/.fzf"
    [[ -f "/usr/local/bin/fzf" ]] && sudo rm -rf "/usr/local/bin/fzf"

    git clone --depth=1 https://github.com/junegunn/fzf.git "/tmp/.fzf"
    yes | /tmp/.fzf/install --no-update-rc
    sudo cp "/tmp/.fzf/bin/fzf" /usr/local/bin/fzf

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
    sudo chmod -R a+rw /opt/rust/cargo /opt/rust/rustup # 开放所有用户读写权限
    export CARGO_HOME=/opt/rust/cargo
    export RUSTUP_HOME=/opt/rust/rustup

    # 2. 通过 rustup 脚本安装并指定系统目录
    rustup-init -y
    # 3. 链接 cargo、rustc、rustup 到系统的PATH 中
    sudo ln -snf  /opt/rust/cargo/bin/* /usr/local/bin/
    # 4. -E 保持了环境变量
    sudo -E rustup update
    # 5. 初始化 rustup 环境
    rustup default stable
    # .rustup目录安装在 RUSTUP_HOME；cargo、rustc、rustup、eza、rg、fd 都安装在 CARGO_HOME（但是它们符号链接在 /usr/local/bin/）
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
    sudo ln -snf  /opt/rust/cargo/bin/eza /usr/local/bin/
    print_centered_message "${GREEN} eza 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 eza=================================

# =================================开始安装 fd=================================

if command -v fd >/dev/null 2>&1; then
    print_centered_message "${GREEN}fd 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 fd... ${NC}" "true" "false"
    cargo install fd-find
    sudo ln -snf  /opt/rust/cargo/bin/fd /usr/local/bin/
    print_centered_message "${GREEN} fd 安装完成 ✅${NC}" "false" "true"
fi

# =================================结束安装 fd=================================

# =================================开始安装 rg=================================

if command -v rg >/dev/null 2>&1; then
    print_centered_message "${GREEN}rg 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 rg... ${NC}" "false" "false"
    cargo install ripgrep
    sudo ln -snf  /opt/rust/cargo/bin/rg /usr/local/bin/
    print_centered_message "${GREEN} rg 安装完成 ✅${NC}" "false" "false"
fi

# =================================结束安装 rg=================================

# =================================开始安装 bat=================================

if command -v bat >/dev/null 2>&1; then
    print_centered_message "${GREEN}bat 已安装，跳过安装。${NC}" "true" "true"
else
    print_centered_message "${GREEN}开始安装 bat... ${NC}" "true" "false"
    cargo install bat
    sudo ln -snf  /opt/rust/cargo/bin/bat /usr/local/bin/
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

# =================================开始安装 kitty=================================
if ! command -v "kitty" >/dev/null 2>&1; then
    sudo dnf install -y "kitty"
fi
# =================================结束安装 kitty=================================