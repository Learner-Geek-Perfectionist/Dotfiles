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
	rustup-init -y

	# 3. 链接 cargo、rustc、rustup 到系统的 PATH 中
	sudo ln -snf /opt/rust/cargo/bin/* /usr/local/bin/
	# 4. -E 保持了环境变量
	sudo -E rustup update
	# 5. 初始化 rustup 环境
	rustup default stable
	# .rustup 目录安装在 RUSTUP_HOME；cargo、rustc、rustup、eza、rg、fd 都安装在 CARGO_HOME（但是它们符号链接在 /usr/local/bin/）
	print_centered_message "${GREEN} rustc 安装完成 ✅${NC}" "false" "true"
fi
# =================================结束安装 Rust 工具=================================

# =================================开始安装 cargo-binstall=================================
if command -v cargo-binstall >/dev/null 2>&1; then
	print_centered_message "${GREEN}cargo-binstall 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 cargo-binstall... ${NC}" "true" "false"

	# 安装 cargo-binstall
	cargo install cargo-binstall
	sudo ln -snf /opt/rust/cargo/bin/cargo-binstall /usr/local/bin/
	print_centered_message "${GREEN} cargo-binstall 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 cargo-binstall=================================

# =================================开始安装 cargo-update=================================
if command -v cargo-install-update >/dev/null 2>&1; then
	print_centered_message "${GREEN}cargo-update 已安装，跳过安装。${NC}" "true" "true"
else
	print_centered_message "${GREEN}开始安装 cargo-update... ${NC}" "true" "false"

	# 安装 cargo-update
	cargo-binstall -y cargo-update
	sudo ln -snf /opt/rust/cargo/bin/cargo-install-update /usr/local/bin/
	print_centered_message "${GREEN} cargo-update 安装完成 ✅${NC}" "false" "false"
fi
# =================================结束安装 cargo-update=================================
# # 更新 rustup 自身
# rustup self update

# # 更新所有已安装的工具链（rustc, cargo, rustfmt, clippy）
# rustup update

# #更新 第三方 Cargo 工具（fd-find, eza, bat, starship）
# cargo install-update -a
