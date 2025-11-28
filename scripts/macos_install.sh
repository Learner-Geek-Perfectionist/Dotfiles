#!/bin/zsh
# macOS Installation Logic

log_msg "Starting macOS installation..." "false"
print_msg "${CYAN}Detected OS: macOS${NC}" "35"

# 1. Check Xcode Command Line Tools
if ! xcode-select --version &>/dev/null; then
	print_msg "${RED}⚠️ Xcode Command Line Tools not installed${NC}" "196"
	xcode-select --install 2>/dev/null
	print_msg "${RED}Please manually click 'Install' in the popup window. After installation, run the script again.${NC}" "196"
	# Provide a helpful command to re-run (assuming curl install)
	echo -e "${RED}Re-run command: ${NC}"
	print_msg "${RED}/bin/zsh -c \"$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh)\"${NC}" "196"
	exit 1
fi

sudo xcode-select --reset

# 2. Check/Install Homebrew
if command -v brew >/dev/null 2>&1; then
	print_msg "${GREEN}Homebrew is already installed${NC}" "35"
else
	print_msg "${GREEN}Installing Homebrew...${NC}" "212"
	# Using HomebrewCN for speed in China, or fallback to official?
	# User used: https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh
	/bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
	print_msg "${GREEN}Reloading .zprofile to enable brew${NC}" "212"
	source "${HOME}/.zprofile"
fi

echo -e "${YELLOW}Note: Please ensure your proxy is active for faster Homebrew downloads.${NC}"

# 3. Install CLI Tools
print_msg "${RED}Installing macOS CLI Tools...${NC}" "212"
install_packages "brew_formulas" "formula"
print_msg "${GREEN}CLI Tools Installed ✅${NC}" "35"

# 4. Install GUI Applications
print_msg "${RED}Installing macOS GUI Applications...${NC}" "212"
# 添加第三方 tap（mihomo-party 需要）
brew tap mihomo-party-org/mihomo-party 2>/dev/null || true
install_packages "brew_casks" "cask"

print_msg "${GREEN}GUI Applications Installed ✅${NC}" "35"

brew cleanup --prune=all

# 5. 配置网络抓包工具权限（免 sudo 执行 tcpdump/wireshark）
# macOS 通过 access_bpf 组控制 BPF 设备访问权限
if dscl . -read /Groups/access_bpf &>/dev/null; then
	if ! dscl . -read /Groups/access_bpf GroupMembership 2>/dev/null | grep -qw "$(whoami)"; then
		print_msg "配置网络工具权限（添加用户到 access_bpf 组）..." "212"
		sudo dseditgroup -o edit -a "$(whoami)" -t user access_bpf
		print_msg "网络工具权限配置完成 ✅ 重启后生效" "35"
	else
		print_msg "用户已在 access_bpf 组，跳过配置" "35"
	fi
else
	print_msg "⚠️ access_bpf 组不存在，请先安装 Wireshark" "214"
fi

# 6. Kotlin Native（Kotlin Compiler 已通过 brew 安装）
setup_kotlin_environment
download_and_extract_kotlin "$KOTLIN_NATIVE_URL" "$INSTALL_DIR"

print_msg "${GREEN}macOS Installation Complete. 🎉${NC}" "35"
echo -e "${RED}Current Directory: $(pwd) ${NC}"
