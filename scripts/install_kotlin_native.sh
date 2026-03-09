#!/bin/bash
# Kotlin/Native 安装脚本
# 从 JetBrains/kotlin GitHub Releases 下载预编译的 Kotlin/Native
# 支持 macOS (aarch64/x86_64) 和 Linux (x86_64)
# 注意: JetBrains 不提供 Linux aarch64 预编译包

set -eo pipefail

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

get_local_version() {
	local version_file="$INSTALL_DIR/.version"
	if [[ -f "$version_file" ]]; then
		cat "$version_file"
	else
		echo ""
	fi
}

save_local_version() {
	mkdir -p "$INSTALL_DIR"
	echo "$1" >"$INSTALL_DIR/.version"
}

# 获取最新版本号 (tag_name 如 "v2.3.10")
get_latest_version() {
	curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
		| jq -r '.tag_name // empty' 2>/dev/null
}

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

	# 获取最新版本
	local latest
	latest=$(get_latest_version) || true
	if [[ -z "$latest" ]]; then
		print_warn "Kotlin/Native: 无法获取最新版本，跳过"
		return 0
	fi

	# 版本比对
	local local_ver
	local_ver=$(get_local_version)
	if [[ "$local_ver" == "$latest" ]]; then
		print_success "Kotlin/Native 已是最新版本 ($latest)"
		return 0
	fi

	print_dim "版本: ${local_ver:-无} -> $latest"

	# 构造下载 URL (tag 带 v 前缀，文件名中的版本不带)
	local version="${latest#v}"
	local filename="kotlin-native-prebuilt-${platform}-${version}.tar.gz"
	local download_url="https://github.com/${REPO}/releases/download/${latest}/${filename}"

	# 下载
	local tmp_dir
	tmp_dir=$(mktemp -d)
	print_dim "下载 $filename ..."

	if ! curl -fsSL "$download_url" -o "$tmp_dir/$filename"; then
		print_warn "Kotlin/Native: 下载失败"
		rm -rf "$tmp_dir"
		return 0
	fi

	# 解压到暂存目录
	print_dim "解压中..."
	if ! tar -xzf "$tmp_dir/$filename" -C "$tmp_dir"; then
		print_warn "Kotlin/Native: 解压失败"
		rm -rf "$tmp_dir"
		return 0
	fi

	# 找到解压后的顶层目录 (格式: kotlin-native-prebuilt-<platform>-<version>)
	local extracted_dir
	extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "kotlin-native*" | head -1)
	if [[ -z "$extracted_dir" ]]; then
		print_warn "Kotlin/Native: 无法找到解压目录"
		rm -rf "$tmp_dir"
		return 0
	fi

	# 替换旧安装
	rm -rf "$INSTALL_DIR"
	mv "$extracted_dir" "$INSTALL_DIR"
	rm -rf "$tmp_dir"

	# 创建符号链接
	mkdir -p "$BIN_DIR"
	for bin in "${NATIVE_BINS[@]}"; do
		if [[ -f "$INSTALL_DIR/bin/$bin" ]]; then
			chmod +x "$INSTALL_DIR/bin/$bin"
			ln -sf "$INSTALL_DIR/bin/$bin" "$BIN_DIR/$bin"
		fi
	done

	save_local_version "$latest"
	print_success "Kotlin/Native $latest 安装完成"
}

# ========================================
# 主函数
# ========================================
main() {
	install_kotlin_native

	_echo_blank
	print_success "Kotlin/Native 安装完成"
}

main "$@"
