#!/bin/bash
# Fedora Extra Tools Installation

export CARGO_HOME=/opt/rust/cargo
export RUSTUP_HOME=/opt/rust/rustup

# =================================开始安装 Rust 工具=================================
if command -v rustc >/dev/null 2>&1; then
	print_msg "rustc 已安装，跳过安装。" "35"
else
	print_msg "开始安装 rustc..." "212"

	# 1. 创建系统级安装目录并设置权限
	sudo mkdir -p /opt/rust/{cargo,rustup}
	sudo chmod -R a+rw /opt/rust/
	export CARGO_HOME=/opt/rust/cargo
	export RUSTUP_HOME=/opt/rust/rustup
	# 在 fedora 中，安装 rustup 包会得到 rustup-init 工具。
	# 2. 安装 rustup（工具链管理器）、rustc（Rust 编译器）、cargo（包管理与构建工具）在 CARGO_HOME 和 RUSTUP_HOME 中。
	rustup-init -y

	# 3. 链接 cargo、rustc、rustup 到系统的 PATH 中
	sudo ln -snf /opt/rust/cargo/bin/* /usr/local/bin/
	# 4. 使用指定环境变量的方式运行 rustup update
	sudo CARGO_HOME=/opt/rust/cargo RUSTUP_HOME=/opt/rust/rustup rustup update
	# 5. 初始化 rustup 环境
	rustup default stable
	# .rustup 目录安装在 RUSTUP_HOME；cargo、rustc、rustup、eza、rg、fd 都安装在 CARGO_HOME（但是它们符号链接在 /usr/local/bin/）
	print_msg "rustc 安装完成 ✅" "35"
fi
# =================================结束安装 Rust 工具=================================

# =================================开始安装 cargo-binstall=================================
if command -v cargo-binstall >/dev/null 2>&1; then
	print_msg "cargo-binstall 已安装，跳过安装。" "35"
else
	print_msg "开始安装 cargo-binstall..." "212"
	# 安装 cargo-binstall
	curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
	sudo ln -snf /opt/rust/cargo/bin/cargo-binstall /usr/local/bin/
	# 利用 cargo-binstall 自举，自己安装自己，这样 cargo 包管理工具就可以管理 cargo-binstall
	cargo-binstall --force cargo-binstall --no-confirm
	print_msg "cargo-binstall 安装完成 ✅" "35"
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
	print_msg "cargo-update 安装完成 ✅" "35"
fi
# =================================结束安装 cargo-update=================================

# =================================开始安装 eza=================================
if command -v eza >/dev/null 2>&1; then
	print_msg "eza 已安装，跳过安装。" "35"
else
	print_msg "开始安装 eza..." "212"

	# 安装 eza
	cargo-binstall -y eza
	sudo ln -snf /opt/rust/cargo/bin/eza /usr/local/bin/
	print_msg "eza 安装完成 ✅" "35"
fi
# =================================结束安装 eza=================================
# 更新 rustup 自身
# rustup self update

# # 更新所有已安装的工具链（rustc, cargo, rustfmt, clippy）
# rustup update

# #更新 第三方 Cargo 工具（fd-find, eza, bat, starship cargo-binstall）
# cargo install-update -a
