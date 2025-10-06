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
# 安装 maczip
brew install --cask maczip
# 安装 RD280U 显示器的软件
brew install --cask display-pilot
# 安装 github 桌面版
brew install --cask github@beta
# 添加 Mihomo Party 的 Tap
brew tap mihomo-party-org/mihomo-party
# 安装 mihomo Party
brew install --cask mihomo-party

# 将「当前登录用户」添加到 wheel 组中。在很多 Unix 和 Linux 系统中，wheel 组的成员通常具有执行 sudo 命令的权限
sudo dseditgroup -o edit -a "$(whoami)" -t user wheel

print_centered_message "${GREEN}图形界面安装完成✅${NC}" "false" "false"

brew cleanup --prune=all

# =================================开始安装 Rust 工具=================================
if command -v rustc >/dev/null 2>&1; then
	print_centered_message "${GREEN}rustc 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 rustc...${NC}" "true" "false"

	# 1. 创建系统级安装目录并设置权限
	sudo mkdir -p /opt/rust/{cargo,rustup}
	sudo chmod -R a+rw /opt/rust/
	export CARGO_HOME=/opt/rust/cargo
	export RUSTUP_HOME=/opt/rust/rustup

	# 2. 安装 rustup（工具链管理器）、rustc（Rust 编译器）、cargo（包管理与构建工具）在 CARGO_HOME 和 RUSTUP_HOME 中。
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

	# 安装 cargo-binstall
	wget -qO- https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash

	# 3. 链接 cargo、rustc、rustup cargo-binstall 到系统的 PATH 中
	sudo ln -snf /opt/rust/cargo/bin/* /usr/local/bin/
	# 4. -E 保持了环境变量
	sudo -E rustup update
	# 5. 初始化 rustup 环境
	rustup default stable
	# .rustup 目录安装在 RUSTUP_HOME；cargo、rustc、rustup、eza、rg、fd 都安装在 CARGO_HOME（但是它们符号链接在 /usr/local/bin/）
	print_centered_message "${GREEN} rustc 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 Rust 工具=================================

# =================================开始安装 Kotlin/Native =================================
# 设置 Kotlin 的变量
setup_kotlin_environment
# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR
# =================================结束安装 Kotlin/Native =================================

print_centered_message "${GREEN}所有应用安装完成。🎉${NC}" "false" "true"
echo -e "${RED}当前目录: $(pwd) ${NC}"
