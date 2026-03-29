#!/bin/bash
# Kotlin/Native 安装脚本
# 从 JetBrains/kotlin GitHub Releases 下载预编译的 Kotlin/Native
# 支持 macOS (aarch64/x86_64) 和 Linux (x86_64)
# 注意: JetBrains 不提供 Linux aarch64 预编译包

set -euo pipefail

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

# ========================================
# 配置
# ========================================
INSTALL_DIR="$HOME/.local/share/kotlin-native"
BIN_DIR="$HOME/.local/bin"
REPO="JetBrains/kotlin"

# Kotlin/Native 中需要链接到 ~/.local/bin 的关键命令
NATIVE_BINS=(konanc cinterop klib)

# ========================================
# 辅助函数
# ========================================

# 确定平台标识 (用于下载文件名)
# 返回空字符串表示不支持
get_platform() {
	local os="$1" arch="$2"
	if [[ "$os" == "macos" ]]; then
		if [[ "$arch" == "aarch64" ]]; then
			echo "macos-aarch64"
		else
			echo "macos-x86_64"
		fi
	elif [[ "$os" == "linux" ]]; then
		if [[ "$arch" == "x86_64" ]]; then
			echo "linux-x86_64"
		else
			# JetBrains 不提供 Linux aarch64 预编译包
			echo ""
		fi
	else
		echo ""
	fi
}

# ========================================
# 安装主逻辑
# ========================================
install_kotlin_native() {
	local os arch platform
	os=$(detect_os)
	arch=$(detect_arch)
	platform=$(get_platform "$os" "$arch")

	if [[ -z "$platform" ]]; then
		print_warn "Kotlin/Native 不支持当前平台 ($os-$arch)，跳过"
		print_dim "JetBrains 仅提供 linux-x86_64, macos-aarch64, macos-x86_64 预编译包"
		return 0
	fi

	print_info "安装 Kotlin/Native ($platform)..."
	check_github_update "Kotlin/Native" "$REPO" "$INSTALL_DIR" || return 0
	local latest="$_GITHUB_LATEST"

	# 构造下载 URL (tag 带 v 前缀，文件名中的版本不带)
	local version="${latest#v}"
	local filename="kotlin-native-prebuilt-${platform}-${version}.tar.gz"
	local download_url="https://github.com/${REPO}/releases/download/${latest}/${filename}"

	# 下载并解压到临时 staging 目录
	print_dim "下载 $filename ..."
	if ! download_and_extract "$download_url" "$INSTALL_DIR" "tar.gz"; then
		print_warn "Kotlin/Native: 下载或解压失败"
		return 0
	fi

	# tar.gz 解压后有一个动态名称的顶层目录，需要提升一层
	local extracted_dir
	extracted_dir=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "kotlin-native*" | head -1)
	if [[ -n "$extracted_dir" && "$extracted_dir" != "$INSTALL_DIR" ]]; then
		# 将顶层目录内容提升到 INSTALL_DIR
		local tmp_move
		tmp_move=$(mktemp -d)
		mv "$extracted_dir"/* "$tmp_move"/ 2>/dev/null || true
		rm -rf "$INSTALL_DIR"
		mv "$tmp_move" "$INSTALL_DIR"
	fi

	# 创建符号链接
	mkdir -p "$BIN_DIR"
	for bin in "${NATIVE_BINS[@]}"; do
		if [[ -f "$INSTALL_DIR/bin/$bin" ]]; then
			chmod +x "$INSTALL_DIR/bin/$bin"
			ln -sf "$INSTALL_DIR/bin/$bin" "$BIN_DIR/$bin"
		fi
	done

	save_local_version "$INSTALL_DIR" "$latest"
	print_success "Kotlin/Native $latest 安装完成"
}

# ========================================
# 主函数
# ========================================
main() {
	install_kotlin_native
}

main "$@"
