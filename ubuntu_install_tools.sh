# =================================开始安装 cmake=================================
# 检查 cmake 是否已安装
if command -v cmake >/dev/null 2>&1; then
	print_centered_message "${GREEN}cmake 已安装，跳过安装。版本: $(cmake --version | head -n1 | awk '{print $3}')${NC}" "false" "true"
else
	print_centered_message "${GREEN}开始安装 cmake... ${NC}" "true" "false"

	# 利用 Kitware 的官方 APT 仓库
	# 获取当前 Ubuntu 版本代号
	CURRENT_VERSION_CODE=$(lsb_release -cs)
	CURRENT_VERSION_NUM=$(lsb_release -r | awk '{print $2}')

	# 在临时目录中创建 gpg 专用子目录
	TEMP_DIR=$(mktemp -d)
	GNUPG_TEMP_DIR="$TEMP_DIR/gnupg"
	mkdir -p "$GNUPG_TEMP_DIR"
	chmod 700 "$GNUPG_TEMP_DIR"

	# 清理旧密钥（如果存在）
	[[ -f /etc/apt/keyrings/kitware.gpg ]] && sudo rm -rf /etc/apt/keyrings/kitware.gpg

	# 创建密钥存储目录（适用于所有Ubuntu版本）
	sudo mkdir -p /etc/apt/keyrings

	# 使用 curl 获取 Kitware 支持的版本列表(Noble，Jammy，Focal)
	SUPPORTED_VERSIONS=$(curl -Ls https://apt.kitware.com/ubuntu/ | grep -oP 'For Ubuntu [^<]+' | sed -E 's/For Ubuntu (.*):/\1/' | sort -r | uniq)

	# 提取最新的版本代号（比如 Noble）
	SUPPORTED_VERSION_CODE=$(echo "$SUPPORTED_VERSIONS" | sed -E 's/ .*//g' | tr '[:upper:]' '[:lower:]' | head -n 1) # 只保留版本代号（如 noble, jammy, focal）
	SUPPORTED_VERSION_NUM_MAX=$(echo "$SUPPORTED_VERSIONS" | grep -oP '\d+\.\d+' | sort -V | tail -n 1)
	SUPPORTED_VERSION_NUM_MIN=$(echo "$SUPPORTED_VERSIONS" | grep -oP '\d+\.\d+' | sort -V | head -n 1)

	# 检查当前版本是否支持
	if [[ $(echo "$CURRENT_VERSION_NUM > $SUPPORTED_VERSION_NUM_MAX" | bc -l) -eq 1 ]]; then
		# 如果不支持当前版本（当前版本太高），使用 Kitware 仓库最新的版本
		echo "deb [signed-by=/etc/apt/keyrings/kitware.gpg] https://apt.kitware.com/ubuntu/ $SUPPORTED_VERSION_CODE main" | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
	elif [[ $(echo "$CURRENT_VERSION_NUM < $SUPPORTED_VERSION_NUM_MIN" | bc -l) -eq 1 ]]; then
		# 如果不支持当前版本（当前版本太低），使用当前版本
		echo "deb [signed-by=/etc/apt/keyrings/kitware.gpg] https://apt.kitware.com/ubuntu/ $CURRENT_VERSION_CODE main" | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
	else
		#  如果支持当前版本
		curl -s https://apt.kitware.com/kitware-archive.sh | sudo bash
	fi

	# 下载密钥到临时目录
	curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc -o "$TEMP_DIR/kitware-archive-latest.asc"
	sudo GNUPGHOME="$GNUPG_TEMP_DIR" gpg --dearmor -o /etc/apt/keyrings/kitware.gpg "$TEMP_DIR/kitware-archive-latest.asc"

	# 更新仓库并安装CMake
	sudo apt update && sudo apt install -y cmake

	rm -rf "$TEMP_DIR"

	# 最终验证
	if command -v cmake >/dev/null 2>&1; then
		print_centered_message "${GREEN}cmake 安装完成 ✅ 版本: $(cmake --version | head -n1 | awk '{print $3}')${NC}" "false" "true"
	else
		print_centered_message "${RED}cmake 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 cmake=================================

# =================================开始安装 llvm 套装=================================
# 检查 llvm 套装 是否已安装
if command -v llvm-config >/dev/null 2>&1; then
	print_centered_message "${GREEN}llvm 套装 已安装，跳过安装。版本: $(llvm-config --version)${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 llvm 套装... ${NC}" "true" "false"

	# 获取当前Ubuntu版本代号
	CODENAME=$(lsb_release -cs)
	ARCH="$(dpkg --print-architecture)"
	URL="https://apt.llvm.org/${CODENAME}/dists/llvm-toolchain-${CODENAME}/main/binary-${ARCH}/Packages"
	LLVM_VERSION=$(curl -fsSL "$URL" | grep -oP '^Package: clangd-\K[0-9]+' | sort -Vu | tail -1)
	# 创建临时目录及gpg子目录
	TEMP_DIR=$(mktemp -d)
	GNUPG_TEMP_DIR="$TEMP_DIR/gnupg"
	mkdir -p "$GNUPG_TEMP_DIR"
	chmod 700 "$GNUPG_TEMP_DIR" # gpg要求严格的权限设置

	# 1. 清理可能存在的旧密钥（避免冲突）
	[[ -f /etc/apt/keyrings/llvm.gpg ]] && sudo rm -f /etc/apt/keyrings/llvm.gpg

	# 2. 创建密钥存储目录（老版本 Ubuntu 可能没有，手动创建）
	sudo mkdir -p /etc/apt/keyrings

	# 3. 下载 LLVM 密钥并存储为独立文件，使用临时gpg目录
	wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo GNUPGHOME="$GNUPG_TEMP_DIR" gpg --dearmor -o /etc/apt/keyrings/llvm.gpg
	# 4. 添加 LLVM 仓库，使用动态检测的版本代号
	echo "deb [signed-by=/etc/apt/keyrings/llvm.gpg] http://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME} main" | sudo tee /etc/apt/sources.list.d/llvm.list >/dev/null
	PKG="clang-$LLVM_VERSION lldb-$LLVM_VERSION lld-$LLVM_VERSION clangd-$LLVM_VERSION"
	PKG="$PKG clang-tidy-$LLVM_VERSION clang-format-$LLVM_VERSION clang-tools-$LLVM_VERSION llvm-$LLVM_VERSION-dev lld-$LLVM_VERSION lldb-$LLVM_VERSION llvm-$LLVM_VERSION-tools libomp-$LLVM_VERSION-dev libc++-$LLVM_VERSION-dev libc++abi-$LLVM_VERSION-dev libclang-common-$LLVM_VERSION-dev libclang-$LLVM_VERSION-dev libclang-cpp$LLVM_VERSION-dev liblldb-$LLVM_VERSION-dev libunwind-$LLVM_VERSION-dev"
	if [[ "${LLVM_VERSION:-0}" -gt 14 ]]; then
		PKG="$PKG libclang-rt-$LLVM_VERSION-dev libpolly-$LLVM_VERSION-dev"
	fi
	# 5. 更新并安装 llvm 套装工具
	sudo apt update && sudo apt install -y $PKG

	# 用 alternatives 让无后缀命令指向 $LLVM_VERSION
	tools=(clang clang++ clangd clang-format clang-tidy clang-cpp lld lldb)
	llvm_tools=(llvm-ar llvm-ranlib llvm-objdump llvm-objcopy llvm-nm llvm-readelf llvm-readobj llvm-strip
		llvm-size llvm-as llvm-dis llvm-config llvm-addr2line llvm-cov llvm-profdata llvm-mca llvm-lto)

	for t in "${tools[@]}"; do
		if command -v "/usr/bin/${t}-${LLVM_VERSION}" >/dev/null 2>&1; then
			sudo update-alternatives --install "/usr/bin/${t}" "${t}" "/usr/bin/${t}-${LLVM_VERSION}" "${LLVM_VERSION}"
			sudo update-alternatives --set "${t}" "/usr/bin/${t}-${LLVM_VERSION}" || true
		fi
	done

	for t in "${llvm_tools[@]}"; do
		if command -v "/usr/bin/${t}-${LLVM_VERSION}" >/dev/null 2>&1; then
			sudo update-alternatives --install "/usr/bin/${t}" "${t}" "/usr/bin/${t}-${LLVM_VERSION}" "${LLVM_VERSION}"
			sudo update-alternatives --set "${t}" "/usr/bin/${t}-${LLVM_VERSION}" || true
		fi
	done

	# 清理临时目录
	rm -rf "$TEMP_DIR"

	if command -v llvm-config >/dev/null 2>&1; then
		print_centered_message "${GREEN}llvm 套装安装完成 ✅ 版本: $(llvm-config --version)${NC}" "false" "true"
	else
		print_centered_message "${RED}llvm 套装安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 llvm 套装=================================

# =================================开始安装 fastfetch=================================
if command -v fastfetch >/dev/null 2>&1; then
	print_centered_message "${GREEN}fastfetch 已安装，跳过安装。版本: $(fastfetch --version | head -n1 | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 fastfetch${NC}" "true" "false"
	RELEASES_PAGE=$(curl -s "https://github.com/fastfetch-cli/fastfetch/releases")
	VERSION=$(echo "$RELEASES_PAGE" | grep -oP 'href="/fastfetch-cli/fastfetch/releases/tag/\K(.*?)(?=")' | head -n1)
	# 移除可能存在的前缀"v"
	VERSION=$(echo "$VERSION" | sed 's/^v//')
	ARCH=$(uname -m)
	case $ARCH in
	x86_64)
		BIN_ARCH="amd64"
		;;
	aarch64)
		BIN_ARCH="aarch64"
		;;
	*)
		echo "不支持的架构: $ARCH"
		exit 1
		;;
	esac

	# 定义解压后的目录名称
	UNPACK_DIR="fastfetch-linux-${BIN_ARCH}"
	URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${VERSION}/fastfetch-linux-${BIN_ARCH}.tar.gz"

	TMP_DIR=$(mktemp -d)

	# 下载文件到临时目录
	wget -q -O "${TMP_DIR}/fastfetch.tar.gz" "$URL"

	# 解压文件
	tar -zxvf "${TMP_DIR}/fastfetch.tar.gz" -C "$TMP_DIR"

	# 移动可执行文件（根据实际目录结构调整路径）
	sudo mv "${TMP_DIR}/${UNPACK_DIR}/usr/bin/fastfetch" /usr/local/bin/
	# 设置执行权限
	sudo chmod +x /usr/local/bin/fastfetch

	# 清理临时文件
	rm -rf "$TMP_DIR"

	if command -v fastfetch >/dev/null 2>&1; then
		print_centered_message "${GREEN}fastfetch 安装完成 ✅ 版本: $(fastfetch --version | head -n1 | awk '{print $2}')${NC}" "false" "true"
	else
		print_centered_message "${RED}fastfetch 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 fastfetch=================================

# =================================开始安装 kitty=================================
if command -v kitty >/dev/null 2>&1; then
	print_centered_message "${GREEN}kitty 已安装，跳过安装。版本: $(kitty --version | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 kitty... ${NC}" "true" "false"
	sudo mkdir -p /opt/kitty && sudo chmod -R a+rw /opt/kitty
	curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n dest=/opt/kitty

	# 安装 kitty
	sudo ln -snf /opt/kitty/kitty.app/bin/* /usr/local/bin/

	# 安装 terminfo
	sudo install -Dm644 /opt/kitty/kitty.app/share/terminfo/x/xterm-kitty /usr/share/terminfo/x/xterm-kitty

	# 安装 man 手册
	sudo cp -r /opt/kitty/kitty.app/share/man/* /usr/share/man/
	sudo mandb

	# 安装 icons 图标
	sudo cp -r /opt/kitty/kitty.app/share/icons/* /usr/share/icons/
	sudo update-icon-caches /usr/share/icons/*

	# desktop 文件（系统级）
	sudo cp /opt/kitty/kitty.app/share/applications/kitty*.desktop /usr/share/applications/
	sudo sed -i 's|Exec=kitty|Exec=/opt/kitty/kitty.app/bin/kitty|g' /usr/share/applications/kitty*.desktop
	sudo sed -i 's|Icon=kitty|Icon=/opt/kitty/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g' /usr/share/applications/kitty*.desktop

	if command -v kitty >/dev/null 2>&1; then
		print_centered_message "${GREEN}kitty 安装完成 ✅ 版本: $(kitty --version | awk '{print $2}')${NC}" "false" "true"
	else
		print_centered_message "${RED}kitty 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 kitty=================================

# =================================开始安装 fzf=================================
if command -v fzf >/dev/null 2>&1; then
	print_centered_message "${GREEN}fzf 已安装，跳过安装。版本: $(fzf --version | awk '{print $2}')${NC}" "false" "false"
else
	print_centered_message "${GREEN}开始安装 fzf... ${NC}" "false" "false"
	[[ -d "/tmp/.fzf" ]] && sudo rm -rf "/tmp/.fzf"
	[[ -f "/usr/local/bin/fzf" ]] && sudo rm -rf "/usr/local/bin/fzf"

	yes | bash -c 'mkdir -p /tmp/.fzf && cd /tmp/.fzf && curl -fsSL https://raw.githubusercontent.com/junegunn/fzf/master/install | bash -s -- --no-update-rc'
	sudo cp "/tmp/.fzf/bin/fzf" /usr/local/bin/fzf

	# 清理安装目录
	sudo rm -rf "/tmp/.fzf"

	if command -v fzf >/dev/null 2>&1; then
		print_centered_message "${GREEN}fzf 安装完成 ✅ 版本: fzf --version | awk '{print $1}'${NC}" "false" "false"
	else
		print_centered_message "${RED}fzf 安装失败 ❌${NC}" "false" "false"
		exit 1
	fi
fi
# =================================结束安装 fzf=================================

export CARGO_HOME=/opt/rust/cargo
export RUSTUP_HOME=/opt/rust/rustup
# =================================开始安装 Rust 工具=================================
if command -v rustc >/dev/null 2>&1; then
	print_centered_message "${GREEN}rustc 已安装，跳过安装。版本: $(rustc --version | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 rustc...${NC}" "true" "false"

	# 1. 创建系统级安装目录并设置权限
	sudo mkdir -p /opt/rust/{cargo,rustup}
	sudo chmod -R a+rw /opt/rust/
	export CARGO_HOME=/opt/rust/cargo
	export RUSTUP_HOME=/opt/rust/rustup

	# 2. 安装 rustup（工具链管理器）、rustc（Rust 编译器）、cargo（包管理与构建工具）在 CARGO_HOME 和 RUSTUP_HOME 中。
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

	# 3. 链接 cargo、rustc、rustup cargo-binstall 到系统的 PATH 中
	sudo ln -snf /opt/rust/cargo/bin/* /usr/local/bin/
	# 4. -E 保持了环境变量
	rustup update
	# 5. 初始化 rustup 环境
	rustup default stable

	if command -v rustc >/dev/null 2>&1; then
		print_centered_message "${GREEN}rustc 安装完成 ✅ 版本: $(rustc --version | awk '{print $2}')${NC}" "false" "true"
	else
		print_centered_message "${RED}rustc 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 Rust 工具=================================

# =================================开始安装 cargo-binstall=================================
if command -v cargo-binstall >/dev/null 2>&1; then
	print_centered_message "${GREEN}cargo-binstall 已安装，跳过安装。版本: $(cargo-binstall --version | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 cargo-binstall... ${NC}" "true" "false"
	# 安装 cargo-binstall
	curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
	sudo ln -snf /opt/rust/cargo/bin/cargo-binstall /usr/local/bin/
	# 利用 cargo-binstall 自举，自己安装自己，这样 cargo 包管理工具就可以管理 cargo-binstall
	cargo-binstall --force -y cargo-binstall

	if command -v cargo-binstall >/dev/null 2>&1; then
		print_centered_message "${GREEN}cargo-binstall 安装完成 ✅ 版本: $(cargo-binstall -V | awk '{print $1}')${NC}" "false" "false"
	else
		print_centered_message "${RED}cargo-binstall 安装失败 ❌${NC}" "false" "false"
		exit 1
	fi
fi
# =================================结束安装 cargo-binstall=================================

# =================================开始安装 cargo-update=================================
if command -v cargo-install-update >/dev/null 2>&1; then
	print_centered_message "${GREEN}cargo-update 已安装，跳过安装。版本: $(cargo-install-update --version | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 cargo-update... ${NC}" "true" "false"

	# 安装 cargo-update
	cargo-binstall -y cargo-update
	sudo ln -snf /opt/rust/cargo/bin/cargo-install-update /usr/local/bin/

	if command -v cargo-install-update >/dev/null 2>&1; then
		print_centered_message "${GREEN}cargo-update 安装完成 ✅ 版本: $(cargo-binstall -V | awk '{print $1}')${NC}" "false" "false"
	else
		print_centered_message "${RED}cargo-update 安装失败 ❌${NC}" "false" "false"
		exit 1
	fi
fi
# =================================结束安装 cargo-update=================================

# =================================开始安装 eza=================================
if command -v eza >/dev/null 2>&1; then
	print_centered_message "${GREEN}eza 已安装，跳过安装。版本: $(eza --version | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 eza... ${NC}" "true" "false"

	# 安装 eza
	cargo-binstall -y eza
	sudo ln -snf /opt/rust/cargo/bin/eza /usr/local/bin/

	if command -v eza >/dev/null 2>&1; then
		print_centered_message "${GREEN}eza 安装完成 ✅ 版本: $(eza --version | awk 'NR==2 {print $1}')${NC}" "false" "false"
	else
		print_centered_message "${RED}eza 安装失败 ❌${NC}" "false" "false"
		exit 1
	fi
fi
# =================================结束安装 eza=================================

# =================================开始安装 fd=================================
if command -v fd >/dev/null 2>&1; then
	print_centered_message "${GREEN}fd 已安装，跳过安装。版本: $(fd --version | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 fd... ${NC}" "true" "false"
	cargo-binstall -y fd-find
	sudo ln -snf /opt/rust/cargo/bin/fd /usr/local/bin/

	if command -v fd >/dev/null 2>&1; then
		print_centered_message "${GREEN}fd 安装完成 ✅ 版本: $(fd --version | awk '{print $2}')${NC}" "false" "true"
	else
		print_centered_message "${RED}fd 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 fd=================================

# =================================开始安装 rg=================================
if command -v rg >/dev/null 2>&1; then
	print_centered_message "${GREEN}rg 已安装，跳过安装。版本: $(rg --version | awk '{print $2}')${NC}" "false" "false"
else
	print_centered_message "${GREEN}开始安装 rg... ${NC}" "false" "false"
	cargo-binstall -y ripgrep
	sudo ln -snf /opt/rust/cargo/bin/rg /usr/local/bin/

	if command -v rg >/dev/null 2>&1; then
		print_centered_message "${GREEN}rg 安装完成 ✅ 版本: $(rg --version | awk 'NR==1 {print $2}')${NC}" "false" "false"
	else
		print_centered_message "${RED}rg 安装失败 ❌${NC}" "false" "false"
		exit 1
	fi
fi
# =================================结束安装 rg=================================

# =================================开始安装 bat=================================
if command -v bat >/dev/null 2>&1; then
	print_centered_message "${GREEN}bat 已安装，跳过安装。版本: $(bat --version | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 bat... ${NC}" "true" "false"
	cargo-binstall -y bat
	sudo ln -snf /opt/rust/cargo/bin/bat /usr/local/bin/

	if command -v bat >/dev/null 2>&1; then
		print_centered_message "${GREEN}bat 安装完成 ✅ 版本: $(bat --version | awk '{print $2}')${NC}" "false" "true"
	else
		print_centered_message "${RED}bat 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 bat=================================

# =================================开始安装 lua=================================
if command -v lua >/dev/null 2>&1; then
	print_centered_message "${GREEN}lua 已安装，跳过安装。版本: $(lua -v | awk '{print $2}')${NC}" "false" "true"
else
	print_centered_message "${GREEN}开始安装 lua... ${NC}" "false" "false"
	latest=$(apt list lua* 2>/dev/null | grep -oP 'lua\d+\.\d+' | sort -V | tail -n 1)
	sudo apt install -y ${latest} lib${latest}-dev

	if command -v lua >/dev/null 2>&1; then
		print_centered_message "${GREEN}lua 安装完成 ✅ 版本: $(lua -v | awk '{print $2}')${NC}" "false" "true"
	else
		print_centered_message "${RED}lua 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 lua=================================

# =================================开始安装 shfmt=================================
if command -v shfmt >/dev/null 2>&1; then
	print_centered_message "${GREEN}shfmt 已安装，跳过安装。版本: $(shfmt -version)${NC}" "false" "true"
else
	print_centered_message "${GREEN}开始安装 shfmt... ${NC}" "false" "false"

	VERSION=$(curl -sIL -o /dev/null -w '%{url_effective}\n' https://github.com/mvdan/sh/releases/latest | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')

	# 检测操作系统
	OS=$(uname -s | tr '[:upper:]' '[:lower:]')
	case $OS in
	linux)
		OS="linux"
		;;
	darwin)
		OS="darwin"
		;;
	*)
		echo "不支持的操作系统: $OS"
		exit 1
		;;
	esac

	# 检测架构
	ARCH=$(uname -m)
	case $ARCH in
	x86_64 | amd64)
		ARCH="amd64"
		;;
	arm64 | aarch64)
		ARCH="arm64"
		;;
	*)
		echo "不支持的架构: $ARCH"
		exit 1
		;;
	esac

	# 构建下载URL
	FILENAME="/tmp/shfmt_${VERSION}_${OS}_${ARCH}"
	DOWNLOAD_URL="https://github.com/mvdan/sh/releases/download/${VERSION}/${FILENAME##*/}"

	curl -L -o "$FILENAME" "$DOWNLOAD_URL"
	chmod +x "$FILENAME"
	sudo mv "$FILENAME" /usr/local/bin/shfmt

	if command -v shfmt >/dev/null 2>&1; then
		print_centered_message "${GREEN}shfmt 安装完成 ✅ 版本: $(shfmt -version)${NC}" "false" "true"
	else
		print_centered_message "${RED}shfmt 安装失败 ❌${NC}" "false" "true"
		exit 1
	fi
fi
# =================================结束安装 shfmt=================================

# =================================开始安装 dust=================================
if command -v dust >/dev/null 2>&1; then
	print_centered_message "${GREEN}dust 已安装，跳过安装。版本: $(dust --version | awk '{print $2}')${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 dust... ${NC}" "true" "false"

	# 安装 dust
	cargo-binstall -y du-dust
	sudo ln -snf /opt/rust/cargo/bin/dust /usr/local/bin/

	if command -v dust >/dev/null 2>&1; then
		print_centered_message "${GREEN}dust 安装完成 ✅ 版本: $(dust --version | awk '{print $2}')${NC}" "false" "false"
	else
		print_centered_message "${RED}dust 安装失败 ❌${NC}" "false" "false"
		exit 1
	fi
fi
# =================================结束安装 dust=================================
