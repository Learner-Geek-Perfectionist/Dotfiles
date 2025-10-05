# =================================开始安装 cmake=================================
# 检查 cmake 是否已安装
if command -v cmake >/dev/null 2>&1; then
	print_centered_message "${GREEN}cmake 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 cmake... ${NC}" "true" "false"

	# 获取当前Ubuntu版本代号
	CURRENT_VERSION=$(lsb_release -cs)

	# 清理旧密钥（如果存在）
	[[ -f /etc/apt/keyrings/kitware.gpg ]] && sudo rm -rf /etc/apt/keyrings/kitware.gpg

	# 创建密钥存储目录（适用于所有Ubuntu版本）
	sudo mkdir -p /etc/apt/keyrings

	# 下载并导入Kitware密钥（使用gpg --dearmor处理，适用于新老版本）
	sudo wget -qO- https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo gpg --dearmor -o /etc/apt/keyrings/kitware.gpg

	# 添加仓库源（根据当前系统版本动态生成）
	echo "deb [signed-by=/etc/apt/keyrings/kitware.gpg] https://apt.kitware.com/ubuntu/ $CURRENT_VERSION main" | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null

	# 更新仓库并安装CMake
	sudo apt update && sudo apt install -y cmake

	# 最终验证
	if command -v cmake >/dev/null 2>&1; then
		print_centered_message "${GREEN}cmake 安装完成 ✅ 版本: $(cmake --version | head -n1 | awk '{print $3}')${NC}" "false" "true"
	else
		print_centered_message "${RED}cmake 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 cmake=================================

# =================================开始安装 clangd=================================

# 1. 清理可能存在的旧密钥（避免冲突）
[[ -f /etc/apt/keyrings/llvm.gpg ]] && sudo rm -f /etc/apt/keyrings/llvm.gpg

# 2. 创建密钥存储目录（老版本 Ubuntu 可能没有，手动创建）
sudo mkdir -p /etc/apt/keyrings

# 3. 下载 LLVM 密钥并存储为独立文件（而非全局密钥环）
sudo wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/llvm.gpg

# 4. 添加 LLVM 仓库，并显式指定使用上面的密钥文件验证（关键：避免全局信任）
echo "deb [signed-by=/etc/apt/keyrings/llvm.gpg] http://apt.llvm.org/bionic/ llvm-toolchain-bionic main" | sudo tee /etc/apt/sources.list.d/llvm.list >/dev/null

# 5. 更新并安装 clangd
sudo apt update && sudo apt install -y clangd

# =================================结束安装 clangd=================================

# =================================开始安装 fastfetch=================================
if command -v fastfetch >/dev/null 2>&1; then
	print_centered_message "${GREEN} fastfetch 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 fastfetch${NC}" "true" "false"
	[[ -d "~/fastfetch" ]] && sudo rm -rf "~/fastfetch"
	git clone https://github.com/fastfetch-cli/fastfetch
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

# =================================开始安装 kitty=================================
if command -v kitty >/dev/null 2>&1; then
	print_centered_message "${GREEN} kitty 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 kitty... ${NC}" "true" "false"
	sudo mkdir -p /opt/kitty && sudo chmod -R a+rw /opt/kitty
	curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n dest=/opt/kitty

	# 将 kitty 二进制文件复制到标准的系统路径
	sudo ln -snf /opt/kitty/kitty.app/bin/* /usr/local/bin/

	# 安装 terminfo
	sudo mv ~/.local/kitty.app/share/terminfo/x/xterm-kitty /lib/terminfo/x/

	# 安装 man 手册
	sudo cp -r ~/.local/kitty.app/share/man/* /usr/share/man/
	sudo mandb

	# 安装 icons 图标
	sudo cp -r ~/.local/kitty.app/share/icons/* /usr/share/icons/
	sudo update-icon-caches /usr/share/icons/*

	print_centered_message "${GREEN} kitty 安装完成 ✅${NC}" "false" "true"

fi

# =================================结束安装 kitty=================================

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

# =================================开始安装 rustc=================================
if command -v rustc >/dev/null 2>&1; then
	print_centered_message "${GREEN}rustc 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 rustc...${NC}" "true" "false"
	# 安装 rustup

	# 1. 创建系统级安装目录并设置权限
	sudo mkdir -p /opt/rust/{cargo,rustup}
	sudo chmod -R a+rw /opt/rust/
	export CARGO_HOME=/opt/rust/cargo
	export RUSTUP_HOME=/opt/rust/rustup

	# 2. 安装 rustup（工具链管理器）、rustc（Rust 编译器）、cargo（包管理与构建工具）在 CARGO_HOME 和 RUSTUP_HOME 中。
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
	# 3. 链接 cargo、rustc、rustup 到系统的 PATH 中
	sudo ln -snf /opt/rust/cargo/bin/* /usr/local/bin/
	# 4. -E 保持了环境变量
	sudo -E rustup update
	# 5. 初始化 rustup 环境
	rustup default stable
	# .rustup 目录安装在 RUSTUP_HOME；cargo、rustc、rustup、eza、rg、fd 都安装在 CARGO_HOME（但是它们符号链接在 /usr/local/bin/）
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
	sudo ln -snf /opt/rust/cargo/bin/eza /usr/local/bin/
	print_centered_message "${GREEN} eza 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 eza=================================

# =================================开始安装 fd=================================

if command -v fd >/dev/null 2>&1; then
	print_centered_message "${GREEN}fd 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 fd... ${NC}" "true" "false"
	cargo install fd-find
	sudo ln -snf /opt/rust/cargo/bin/fd /usr/local/bin/
	print_centered_message "${GREEN} fd 安装完成 ✅${NC}" "false" "true"
fi

# =================================结束安装 fd=================================

# =================================开始安装 rg=================================

if command -v rg >/dev/null 2>&1; then
	print_centered_message "${GREEN}rg 已安装，跳过安装。${NC}" "false" "false"
else
	print_centered_message "${GREEN}开始安装 rg... ${NC}" "false" "false"
	cargo install ripgrep
	sudo ln -snf /opt/rust/cargo/bin/rg /usr/local/bin/
	print_centered_message "${GREEN} rg 安装完成 ✅${NC}" "false" "false"
fi

# =================================结束安装 rg=================================

# =================================开始安装 bat=================================

if command -v bat >/dev/null 2>&1; then
	print_centered_message "${GREEN}bat 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 bat... ${NC}" "true" "false"
	cargo install bat
	sudo ln -snf /opt/rust/cargo/bin/bat /usr/local/bin/
	print_centered_message "${GREEN} bat 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 bat=================================

# =================================开始安装 lua=================================

if command -v lua >/dev/null 2>&1; then
	print_centered_message "${GREEN}lua 已安装，跳过安装。${NC}" "false" "true"
else
	print_centered_message "${GREEN}开始安装 lua... ${NC}" "false" "false"
	LUA_LATEST_VERSION=$(curl -s https://www.lua.org/ftp/ | grep -o 'lua-[0-9]*\.[0-9]*\.[0-9]*\.tar\.gz' | sort -V | tail -n 1)
	[[ -e "$LUA_LATEST_VERSION" ]] && sudo rm -rf "$LUA_LATEST_VERSION"
	[[ -e "${LUA_LATEST_VERSION%.tar.gz}" ]] && sudo rm -rf "${LUA_LATEST_VERSION%.tar.gz}"
	curl -O "https://www.lua.org/ftp/$LUA_LATEST_VERSION"
	tar -xzvf "$LUA_LATEST_VERSION"
	cd "${LUA_LATEST_VERSION%.tar.gz}"
	make "-j$(nproc)" && sudo make install
	cd .. && sudo rm -rf "${LUA_LATEST_VERSION%.tar.gz}" "$LUA_LATEST_VERSION"

	print_centered_message "${GREEN} lua 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 lua=================================
