# macOS 逻辑
print_centered_message "${CYAN}检测到操作系统为: macOS${NC}" "true" "false"

if ! xcode-select --version &>/dev/null; then
    print_centered_message "${RED}⚠️ Xcode 命令行工具未安装${NC}" "true" "false"
    xcode-select --install 2>/dev/null
    print_centered_message "${RED}请手动点击屏幕中的弹窗，选择"安装"，安装完成之后再次运行脚本(提示命令通常在终端的背面)${NC}" "false" "false"
    echo -e "${RED}脚本命令: ${NC}"
    print_centered_message "${RED}/bin/zsh -c \"$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh)\"${NC}" "false" "true"
    exit 1
fi

sudo xcode-select --reset

# 检查 Homebrew 是否已安装
if command -v brew >/dev/null 2>&1; then
    print_centered_message "${GREEN}Homebrew 已经安装${NC}" "true" "false"
else
    print_centered_message "${GREEN}正在安装 Homebrew...${NC}" "true" "false"
    /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
    print_centered_message "${GREEN}重新加载 .zprofile 文件以启用 brew 环境变量 ${NC}" "false" "true"
    # 刷新 brew 配置，启用 brew 环境变量
    source ${HOME}/.zprofile
fi

# 提示开启代理
echo -e "${YELLOW}为了能顺利安装 Homebrew 的 cask 包，请打开代理软件，否则下载速度很慢（推荐选择香港 🇭🇰 或者 新加坡 🇸🇬 节点，如果速度还是太慢，可以通过客户端查看代理情况）${NC}"

print_centered_message "${RED}正在安装 macOS 常用的开发工具......${NC}" "true" "false"

# 安装 brew_formulas 包
install_packages "brew_formulas"

print_centered_message "${GREEN}开发工具安装完成✅${NC}" "false" "true"

print_centered_message "${RED}正在安装 macOS 常用的带图形用户界面的应用程序......${NC}" "false" "false"

# 安装 brew_casks 包
install_packages "brew_casks"

# 安装 wireshark --cask 工具，因为 wireshark 既有命令行版本又有 cask 版本，因此手动加上 --cask 参数
brew install --cask wireshark
# 安装 wireshark
brew install --cask maczip
## 安装 squirrel 输入法
#brew install --cask squirrel

# 设置 tcpdump 等权限。将 /dev/bpf* 的设备修改为当前用户所拥有，并且属于 admin 组（macos 的内置组，通过 dscacheutil -q group -a name admin 查看组的成员）。
sudo chown "$(whoami)":admin /dev/bpf*

# =================================开始安装 rustc=================================
if command -v rustc >/dev/null 2>&1; then
    print_centered_message "${GREEN}rustc 已安装，跳过安装。${NC}" "false" "false"
else
    print_centered_message "${GREEN}开始安装 rustc...${NC}" "false" "false"
    # 安装 rustup

    # 1. 创建系统级安装目录并设置权限
    sudo mkdir -p /opt/rust/{cargo,rustup}
    sudo chmod -R a+rw /opt/rust/cargo /opt/rust/rustup # 开放所有用户读写权限
    export CARGO_HOME=/opt/rust/cargo
    export RUSTUP_HOME=/opt/rust/rustup

    # 2. 通过 rustup 脚本安装并指定系统目录
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    # 3. 链接 cargo、rustc、rustup 到系统的PATH 中
    sudo ln -snf /opt/rust/cargo/bin/* /usr/local/bin/
    # 4. -E 保持了环境变量
    sudo -E rustup update
    # 5. 初始化 rustup 环境
    rustup default stable
    # .rustup目录 安装在 RUSTUP_HOME；cargo、rustc、rustup、eza、rg、fd 都安装在 CARGO_HOME（但是它们符号链接在 /usr/bin/ 或者 /usr/local/bin/）
    print_centered_message "${GREEN} rustc 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 rustc=================================

# 添加 Mihomo Party 的 Tap
brew tap mihomo-party-org/mihomo-party
# 安装
brew install --cask mihomo-party

print_centered_message "${GREEN}图形界面安装完成✅${NC}" "false" "false"

brew cleanup --prune=all

# =================================开始安装 Kotlin/Native =================================
# 设置 Kotlin 的变量
setup_kotlin_environment
# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR
# =================================结束安装 Kotlin/Native =================================

## 安装 白霜拼音 词库
#git clone --depth 1 https://github.com/gaboolic/rime-frost /tmp/rime-frost
#mv /tmp/rime-frost/* ${HOME}/Library/Rime

print_centered_message "${GREEN}所有应用安装完成。🎉${NC}" "false" "true"
echo -e "${RED}当前目录: $(pwd) ${NC}"

