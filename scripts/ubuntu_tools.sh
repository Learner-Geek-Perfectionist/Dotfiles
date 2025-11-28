#!/bin/bash

# =================================开始安装 cmake=================================
# 检查 cmake 是否已安装
if command -v cmake >/dev/null 2>&1; then
	print_msg "cmake 已安装，跳过安装。版本: $(cmake --version | head -n1 | awk '{print $3}')" "35"
else
	print_msg "开始安装 cmake..." "212"

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

	# 使用 curl 获取 Kitware 支持的版本列表（静默获取，失败时不输出 HTML）
	KITWARE_HTML=$(curl -fsSL https://apt.kitware.com/ubuntu/ 2>/dev/null) || KITWARE_HTML=""
	SUPPORTED_VERSIONS=$(echo "$KITWARE_HTML" | grep -oP 'For Ubuntu [^<]+' | sed -E 's/For Ubuntu (.*):/\1/' | sort -r | uniq)

	# 提取最新的版本代号
	SUPPORTED_VERSION_CODE=$(echo "$SUPPORTED_VERSIONS" | sed -E 's/ .*//g' | tr '[:upper:]' '[:lower:]' | head -n 1)
	SUPPORTED_VERSION_NUM_MAX=$(echo "$SUPPORTED_VERSIONS" | grep -oP '\d+\.\d+' | sort -V | tail -n 1)
	SUPPORTED_VERSION_NUM_MIN=$(echo "$SUPPORTED_VERSIONS" | grep -oP '\d+\.\d+' | sort -V | head -n 1)

	# 检查当前版本是否支持
	if [[ $(echo "$CURRENT_VERSION_NUM > $SUPPORTED_VERSION_NUM_MAX" | bc -l) -eq 1 ]]; then
		echo "deb [signed-by=/etc/apt/keyrings/kitware.gpg] https://apt.kitware.com/ubuntu/ $SUPPORTED_VERSION_CODE main" | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
	elif [[ $(echo "$CURRENT_VERSION_NUM < $SUPPORTED_VERSION_NUM_MIN" | bc -l) -eq 1 ]]; then
		echo "deb [signed-by=/etc/apt/keyrings/kitware.gpg] https://apt.kitware.com/ubuntu/ $CURRENT_VERSION_CODE main" | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
	else
		curl -fsSL https://apt.kitware.com/kitware-archive.sh 2>/dev/null | sudo bash
	fi

	# 下载密钥到临时目录
	curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc -o "$TEMP_DIR/kitware-archive-latest.asc"
	sudo GNUPGHOME="$GNUPG_TEMP_DIR" gpg --dearmor -o /etc/apt/keyrings/kitware.gpg "$TEMP_DIR/kitware-archive-latest.asc"

	# 更新仓库并安装CMake
	sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt install -y cmake

	rm -rf "$TEMP_DIR"

	# 最终验证
	if command -v cmake >/dev/null 2>&1; then
		print_msg "cmake 安装完成 ✅ 版本: $(cmake --version | head -n1 | awk '{print $3}')" "35"
	else
		print_msg "cmake 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 cmake=================================

# =================================开始安装 llvm 套装=================================
if command -v llvm-config >/dev/null 2>&1; then
	print_msg "llvm 套装 已安装，跳过安装。版本: $(llvm-config --version)" "35"
else
	print_msg "开始安装 llvm 套装..." "212"

	CODENAME=$(lsb_release -cs)
	ARCH="$(dpkg --print-architecture)"
	URL="https://apt.llvm.org/${CODENAME}/dists/llvm-toolchain-${CODENAME}/main/binary-${ARCH}/Packages"
	LLVM_VERSION=$(curl -fsSL "$URL" | grep -oP '^Package: clangd-\K[0-9]+' | sort -Vu | tail -1)

	TEMP_DIR=$(mktemp -d)
	GNUPG_TEMP_DIR="$TEMP_DIR/gnupg"
	mkdir -p "$GNUPG_TEMP_DIR"
	chmod 700 "$GNUPG_TEMP_DIR"

	[[ -f /etc/apt/keyrings/llvm.gpg ]] && sudo rm -f /etc/apt/keyrings/llvm.gpg
	sudo mkdir -p /etc/apt/keyrings
	wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo GNUPGHOME="$GNUPG_TEMP_DIR" gpg --dearmor -o /etc/apt/keyrings/llvm.gpg
	echo "deb [signed-by=/etc/apt/keyrings/llvm.gpg] http://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME} main" | sudo tee /etc/apt/sources.list.d/llvm.list >/dev/null

	PKG="clang-$LLVM_VERSION lldb-$LLVM_VERSION lld-$LLVM_VERSION clangd-$LLVM_VERSION"
	PKG="$PKG clang-tidy-$LLVM_VERSION clang-format-$LLVM_VERSION clang-tools-$LLVM_VERSION llvm-$LLVM_VERSION-dev lld-$LLVM_VERSION lldb-$LLVM_VERSION llvm-$LLVM_VERSION-tools libomp-$LLVM_VERSION-dev libc++-$LLVM_VERSION-dev libc++abi-$LLVM_VERSION-dev libclang-common-$LLVM_VERSION-dev libclang-$LLVM_VERSION-dev libclang-cpp$LLVM_VERSION-dev liblldb-$LLVM_VERSION-dev libunwind-$LLVM_VERSION-dev"
	if [[ "${LLVM_VERSION:-0}" -gt 14 ]]; then
		PKG="$PKG libclang-rt-$LLVM_VERSION-dev libpolly-$LLVM_VERSION-dev"
	fi
	sudo apt update
	sudo DEBIAN_FRONTEND=noninteractive apt install -y $PKG

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

	rm -rf "$TEMP_DIR"

	if command -v llvm-config >/dev/null 2>&1; then
		print_msg "llvm 套装安装完成 ✅ 版本: $(llvm-config --version)" "35"
	else
		print_msg "llvm 套装安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 llvm 套装=================================

# =================================开始安装 fastfetch=================================
if command -v fastfetch >/dev/null 2>&1; then
	print_msg "fastfetch 已安装，跳过安装。版本: $(fastfetch --version | head -n1 | awk '{print $2}')" "35"
else
	print_msg "开始安装 fastfetch..." "212"

	# 使用 GitHub API 获取最新版本（避免解析 HTML）
	VERSION=$(curl -fsSL "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' | sed 's/^v//')
	ARCH=$(uname -m)
	case $ARCH in
	x86_64) BIN_ARCH="amd64" ;;
	aarch64) BIN_ARCH="aarch64" ;;
	*)
		echo "不支持的架构: $ARCH"
		exit 1
		;;
	esac

	UNPACK_DIR="fastfetch-linux-${BIN_ARCH}"
	URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${VERSION}/fastfetch-linux-${BIN_ARCH}.tar.gz"

	TMP_DIR=$(mktemp -d)
	print_msg "正在下载 fastfetch ${VERSION}..." "214"
	wget --progress=bar:force -O "${TMP_DIR}/fastfetch.tar.gz" "$URL" 2>&1
	print_msg "正在解压并安装..." "214"
	tar -zxf "${TMP_DIR}/fastfetch.tar.gz" -C "$TMP_DIR"
	sudo mv "${TMP_DIR}/${UNPACK_DIR}/usr/bin/fastfetch" /usr/local/bin/
	sudo chmod +x /usr/local/bin/fastfetch
	rm -rf "$TMP_DIR"

	if command -v fastfetch >/dev/null 2>&1; then
		print_msg "fastfetch 安装完成 ✅ 版本: $(fastfetch --version | head -n1 | awk '{print $2}')" "35"
	else
		print_msg "fastfetch 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 fastfetch=================================

# =================================开始安装 kitty=================================
if command -v kitty >/dev/null 2>&1; then
	print_msg "kitty 已安装，跳过安装。版本: $(kitty --version | awk '{print $2}')" "35"
else
	print_msg "开始安装 kitty..." "212"

	sudo mkdir -p /opt/kitty && sudo chmod -R a+rw /opt/kitty
	curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n dest=/opt/kitty

	sudo ln -snf /opt/kitty/kitty.app/bin/* /usr/local/bin/
	sudo install -Dm644 /opt/kitty/kitty.app/share/terminfo/x/xterm-kitty /usr/share/terminfo/x/xterm-kitty
	sudo cp -r /opt/kitty/kitty.app/share/man/* /usr/share/man/
	sudo mandb -q 2>/dev/null || true
	sudo cp -r /opt/kitty/kitty.app/share/icons/* /usr/share/icons/
	sudo update-icon-caches /usr/share/icons/*
	sudo cp /opt/kitty/kitty.app/share/applications/kitty*.desktop /usr/share/applications/
	sudo sed -i 's|Exec=kitty|Exec=/opt/kitty/kitty.app/bin/kitty|g' /usr/share/applications/kitty*.desktop
	sudo sed -i 's|Icon=kitty|Icon=/opt/kitty/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g' /usr/share/applications/kitty*.desktop

	if command -v kitty >/dev/null 2>&1; then
		print_msg "kitty 安装完成 ✅ 版本: $(kitty --version | awk '{print $2}')" "35"
	else
		print_msg "kitty 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 kitty=================================

# =================================开始安装 fzf=================================
if command -v fzf >/dev/null 2>&1; then
	print_msg "fzf 已安装，跳过安装。版本: $(fzf --version | awk '{print $1}')" "35"
else
	print_msg "开始安装 fzf..." "212"

	[[ -d "/tmp/.fzf" ]] && sudo rm -rf "/tmp/.fzf"
	[[ -f "/usr/local/bin/fzf" ]] && sudo rm -rf "/usr/local/bin/fzf"

	yes | bash -c 'mkdir -p /tmp/.fzf && cd /tmp/.fzf && curl -fsSL https://raw.githubusercontent.com/junegunn/fzf/master/install | bash -s -- --no-update-rc'
	sudo cp "/tmp/.fzf/bin/fzf" /usr/local/bin/fzf
	sudo rm -rf "/tmp/.fzf"

	if command -v fzf >/dev/null 2>&1; then
		print_msg "fzf 安装完成 ✅ 版本: $(fzf --version | awk '{print $1}')" "35"
	else
		print_msg "fzf 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 fzf=================================

export CARGO_HOME=/opt/rust/cargo
export RUSTUP_HOME=/opt/rust/rustup

# =================================开始安装 Rust 工具=================================
if command -v rustc >/dev/null 2>&1; then
	print_msg "rustc 已安装，跳过安装。版本: $(rustc --version | awk '{print $2}')" "35"
else
	print_msg "开始安装 rustc..." "212"

	# 1. 创建系统级安装目录并设置权限
	sudo mkdir -p /opt/rust/{cargo,rustup}
	sudo chmod -R a+rw /opt/rust/
	export CARGO_HOME=/opt/rust/cargo
	export RUSTUP_HOME=/opt/rust/rustup

	# 2. 安装 rustup（工具链管理器）、rustc（Rust 编译器）、cargo（包管理与构建工具）
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

	# 3. 链接 cargo、rustc、rustup 到系统的 PATH 中
	sudo ln -snf /opt/rust/cargo/bin/* /usr/local/bin/
	# 4. 更新 rustup
	rustup update
	# 5. 初始化 rustup 环境
	rustup default stable

	if command -v rustc >/dev/null 2>&1; then
		print_msg "rustc 安装完成 ✅ 版本: $(rustc --version | awk '{print $2}')" "35"
	else
		print_msg "rustc 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 Rust 工具=================================

# =================================开始安装 cargo-binstall=================================
if command -v cargo-binstall >/dev/null 2>&1; then
	print_msg "cargo-binstall 已安装，跳过安装。版本: $(cargo-binstall -V 2>&1 | head -1)" "35"
else
	print_msg "开始安装 cargo-binstall..." "212"
	# 安装 cargo-binstall
	curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
	sudo ln -snf /opt/rust/cargo/bin/cargo-binstall /usr/local/bin/
	# 利用 cargo-binstall 自举，自己安装自己，这样 cargo 包管理工具就可以管理 cargo-binstall
	cargo-binstall --force cargo-binstall --no-confirm

	if command -v cargo-binstall >/dev/null 2>&1; then
		print_msg "cargo-binstall 安装完成 ✅ 版本: $(cargo-binstall -V 2>&1 | head -1)" "35"
	else
		print_msg "cargo-binstall 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 cargo-binstall=================================

# =================================开始安装 cargo-update=================================
if command -v cargo-install-update >/dev/null 2>&1; then
	print_msg "cargo-update 已安装，跳过安装。" "35"
else
	print_msg "开始安装 cargo-update..." "212"

	# 安装 cargo-update
	cargo-binstall cargo-update --no-confirm
	sudo ln -snf /opt/rust/cargo/bin/cargo-install-update /usr/local/bin/

	if command -v cargo-install-update >/dev/null 2>&1; then
		print_msg "cargo-update 安装完成 ✅" "35"
	else
		print_msg "cargo-update 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 cargo-update=================================

# =================================开始安装 eza=================================
if command -v eza >/dev/null 2>&1; then
	print_msg "eza 已安装，跳过安装。版本: $(eza --version | awk 'NR==1 {print $2}')" "35"
else
	print_msg "开始安装 eza..." "212"

	# 安装 eza
	cargo-binstall -y eza
	sudo ln -snf /opt/rust/cargo/bin/eza /usr/local/bin/

	if command -v eza >/dev/null 2>&1; then
		print_msg "eza 安装完成 ✅ 版本: $(eza --version | awk 'NR==1 {print $2}')" "35"
	else
		print_msg "eza 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 eza=================================

# =================================开始安装 fd=================================
if command -v fd >/dev/null 2>&1; then
	print_msg "fd 已安装，跳过安装。版本: $(fd --version | awk '{print $2}')" "35"
else
	print_msg "开始安装 fd..." "212"
	cargo-binstall -y fd-find
	sudo ln -snf /opt/rust/cargo/bin/fd /usr/local/bin/

	if command -v fd >/dev/null 2>&1; then
		print_msg "fd 安装完成 ✅ 版本: $(fd --version | awk '{print $2}')" "35"
	else
		print_msg "fd 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 fd=================================

# =================================开始安装 rg=================================
if command -v rg >/dev/null 2>&1; then
	print_msg "rg 已安装，跳过安装。版本: $(rg --version | awk 'NR==1 {print $2}')" "35"
else
	print_msg "开始安装 rg..." "212"
	cargo-binstall -y ripgrep
	sudo ln -snf /opt/rust/cargo/bin/rg /usr/local/bin/

	if command -v rg >/dev/null 2>&1; then
		print_msg "rg 安装完成 ✅ 版本: $(rg --version | awk 'NR==1 {print $2}')" "35"
	else
		print_msg "rg 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 rg=================================

# =================================开始安装 bat=================================
if command -v bat >/dev/null 2>&1; then
	print_msg "bat 已安装，跳过安装。版本: $(bat --version | awk '{print $2}')" "35"
else
	print_msg "开始安装 bat..." "212"
	cargo-binstall -y bat
	sudo ln -snf /opt/rust/cargo/bin/bat /usr/local/bin/

	if command -v bat >/dev/null 2>&1; then
		print_msg "bat 安装完成 ✅ 版本: $(bat --version | awk '{print $2}')" "35"
	else
		print_msg "bat 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 bat=================================

# =================================开始安装 lua=================================
if command -v lua >/dev/null 2>&1; then
	print_msg "lua 已安装，跳过安装。版本: $(lua -v 2>&1 | grep -oP 'Lua \K[\d.]+')" "35"
else
	print_msg "开始安装 lua..." "212"
	latest=$(apt list lua* 2>/dev/null | grep -oP 'lua\d+\.\d+' | sort -V | tail -n 1)
	sudo DEBIAN_FRONTEND=noninteractive apt install -y ${latest} lib${latest}-dev

	if command -v lua >/dev/null 2>&1; then
		print_msg "lua 安装完成 ✅ 版本: $(lua -v 2>&1 | grep -oP 'Lua \K[\d.]+')" "35"
	else
		print_msg "lua 安装失败 ❌" "196"
		exit 1
	fi
fi
# =================================结束安装 lua=================================
