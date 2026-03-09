#!/bin/bash
# LSP Server 安装脚本
# 安装不由 brew/pixi 管理的 LSP servers
# 支持 macOS 和 Linux，幂等设计

set -eo pipefail

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

# ========================================
# 配置
# ========================================
LSP_DIR="$HOME/.local/share/lsp"
LSP_BIN="$HOME/.local/bin"

# ========================================
# 辅助函数
# ========================================

# 确保 LSP 目录存在
ensure_lsp_dirs() {
	mkdir -p "$LSP_DIR" "$LSP_BIN"
}

# 获取 GitHub 仓库最新 release 的 tag_name
# 参数: $1 = owner/repo (例如 fwcd/kotlin-language-server)
get_latest_release() {
	local repo="$1"
	curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
		| jq -r '.tag_name // empty' 2>/dev/null
}

# 获取本地已安装的版本
# 参数: $1 = LSP 名称
get_local_version() {
	local name="$1"
	local version_file="$LSP_DIR/$name/.version"
	if [[ -f "$version_file" ]]; then
		cat "$version_file"
	else
		echo ""
	fi
}

# 保存本地版本记录
# 参数: $1 = LSP 名称, $2 = 版本号
save_local_version() {
	local name="$1"
	local version="$2"
	mkdir -p "$LSP_DIR/$name"
	echo "$version" >"$LSP_DIR/$name/.version"
}

# ========================================
# 安装函数
# ========================================

# 1. rust-analyzer (Both platforms)
install_rust_analyzer() {
	print_info "安装 rust-analyzer..."
	if ! command -v rustup &>/dev/null; then
		print_warn "rustup 未找到，跳过 rust-analyzer"
		return 0
	fi
	if rustup component add rust-analyzer &>/dev/null; then
		print_success "rust-analyzer 安装完成"
	else
		print_warn "rust-analyzer 安装失败"
	fi
}

# 2. gopls (Linux only, macOS uses brew)
install_gopls() {
	local os
	os=$(detect_os)
	if [[ "$os" == "macos" ]]; then
		return 0
	fi

	print_info "安装 gopls..."
	if ! command -v go &>/dev/null; then
		print_warn "go 未找到，跳过 gopls"
		return 0
	fi
	if go install golang.org/x/tools/gopls@latest &>/dev/null; then
		print_success "gopls 安装完成"
	else
		print_warn "gopls 安装失败"
	fi
}

# 3. npm LSP servers (Both platforms)
install_npm_lsps() {
	if ! command -v npm &>/dev/null; then
		print_warn "npm 未找到，跳过 npm LSP servers"
		return 0
	fi

	# typescript-language-server
	if command -v typescript-language-server &>/dev/null; then
		print_success "typescript-language-server 已安装"
	else
		print_info "安装 typescript-language-server..."
		if npm install -g typescript-language-server typescript &>/dev/null; then
			print_success "typescript-language-server 安装完成"
		else
			print_warn "typescript-language-server 安装失败"
		fi
	fi

	# intelephense
	if command -v intelephense &>/dev/null; then
		print_success "intelephense 已安装"
	else
		print_info "安装 intelephense..."
		if npm install -g intelephense &>/dev/null; then
			print_success "intelephense 安装完成"
		else
			print_warn "intelephense 安装失败"
		fi
	fi
}

# 4. csharp-ls (Both platforms)
install_csharp_ls() {
	print_info "安装 csharp-ls..."
	if ! command -v dotnet &>/dev/null; then
		print_warn "dotnet 未找到，跳过 csharp-ls"
		return 0
	fi
	if dotnet tool install -g csharp-ls &>/dev/null; then
		print_success "csharp-ls 安装完成"
	else
		# 已安装时 install 会失败，尝试 update
		if dotnet tool update -g csharp-ls &>/dev/null; then
			print_success "csharp-ls 更新完成"
		else
			print_warn "csharp-ls 安装/更新失败"
		fi
	fi
}

# 5. kotlin-language-server (Both platforms, GitHub release)
install_kotlin_ls() {
	local name="kotlin-language-server"
	local repo="fwcd/kotlin-language-server"

	print_info "安装 $name..."

	local latest
	latest=$(get_latest_release "$repo")
	if [[ -z "$latest" ]]; then
		print_warn "$name: 无法获取最新版本，跳过"
		return 0
	fi

	local local_ver
	local_ver=$(get_local_version "$name")
	if [[ "$local_ver" == "$latest" ]]; then
		print_success "$name 已是最新版本 ($latest)"
		return 0
	fi

	print_dim "版本: ${local_ver:-无} -> $latest"

	local tmp_dir
	tmp_dir=$(mktemp -d)
	local download_url="https://github.com/${repo}/releases/download/${latest}/server.zip"

	if ! curl -fsSL "$download_url" -o "$tmp_dir/server.zip"; then
		print_warn "$name: 下载失败"
		rm -rf "$tmp_dir"
		return 0
	fi

	# 清理旧安装
	rm -rf "$LSP_DIR/$name"
	mkdir -p "$LSP_DIR/$name"

	# 解压（zip 内含 server/ 子目录）
	if ! unzip -qo "$tmp_dir/server.zip" -d "$LSP_DIR/$name"; then
		print_warn "$name: 解压失败"
		rm -rf "$tmp_dir"
		return 0
	fi
	rm -rf "$tmp_dir"

	# 创建符号链接
	chmod +x "$LSP_DIR/$name/server/bin/kotlin-language-server"
	ln -sf "$LSP_DIR/$name/server/bin/kotlin-language-server" "$LSP_BIN/kotlin-language-server"

	save_local_version "$name" "$latest"
	print_success "$name $latest 安装完成"
}

# 6. lua-language-server (Linux only, macOS uses brew)
install_lua_ls() {
	local os arch
	os=$(detect_os)
	if [[ "$os" == "macos" ]]; then
		return 0
	fi

	local name="lua-language-server"
	local repo="LuaLS/lua-language-server"

	print_info "安装 $name..."

	arch=$(detect_arch)

	local latest
	latest=$(get_latest_release "$repo")
	if [[ -z "$latest" ]]; then
		print_warn "$name: 无法获取最新版本，跳过"
		return 0
	fi

	local local_ver
	local_ver=$(get_local_version "$name")
	if [[ "$local_ver" == "$latest" ]]; then
		print_success "$name 已是最新版本 ($latest)"
		return 0
	fi

	print_dim "版本: ${local_ver:-无} -> $latest"

	# 确定平台标识
	local platform
	if [[ "$arch" == "aarch64" ]]; then
		platform="linux-arm64"
	else
		platform="linux-x64"
	fi

	# 版本号去掉开头的 v
	local ver_without_v="${latest#v}"
	local tarball="lua-language-server-${ver_without_v}-${platform}.tar.gz"
	local download_url="https://github.com/${repo}/releases/download/${latest}/${tarball}"

	local tmp_dir
	tmp_dir=$(mktemp -d)

	if ! curl -fsSL "$download_url" -o "$tmp_dir/$tarball"; then
		print_warn "$name: 下载失败"
		rm -rf "$tmp_dir"
		return 0
	fi

	# 清理旧安装
	rm -rf "$LSP_DIR/$name"
	mkdir -p "$LSP_DIR/$name"

	# 解压
	if ! tar -xzf "$tmp_dir/$tarball" -C "$LSP_DIR/$name"; then
		print_warn "$name: 解压失败"
		rm -rf "$tmp_dir"
		return 0
	fi
	rm -rf "$tmp_dir"

	# 创建 wrapper 脚本
	cat >"$LSP_BIN/lua-language-server" <<-'WRAPPER'
	#!/bin/bash
	exec "$HOME/.local/share/lsp/lua-language-server/bin/lua-language-server" "$@"
	WRAPPER
	chmod +x "$LSP_BIN/lua-language-server"

	save_local_version "$name" "$latest"
	print_success "$name $latest 安装完成"
}

# 7. jdtls (Linux only, macOS uses brew)
install_jdtls() {
	local os
	os=$(detect_os)
	if [[ "$os" == "macos" ]]; then
		return 0
	fi

	local name="jdtls"
	local repo="eclipse-jdtls/eclipse.jdt.ls"

	print_info "安装 $name..."

	if ! command -v java &>/dev/null; then
		print_warn "java 未找到，跳过 jdtls"
		return 0
	fi

	local latest
	latest=$(get_latest_release "$repo")
	if [[ -z "$latest" ]]; then
		print_warn "$name: 无法获取最新版本，跳过"
		return 0
	fi

	local local_ver
	local_ver=$(get_local_version "$name")
	if [[ "$local_ver" == "$latest" ]]; then
		print_success "$name 已是最新版本 ($latest)"
		return 0
	fi

	print_dim "版本: ${local_ver:-无} -> $latest"

	# 版本号去掉开头的 v
	local ver_without_v="${latest#v}"
	local tarball="jdt-language-server-${ver_without_v}.tar.gz"
	local download_url="https://github.com/${repo}/releases/download/${latest}/${tarball}"

	local tmp_dir
	tmp_dir=$(mktemp -d)

	if ! curl -fsSL "$download_url" -o "$tmp_dir/$tarball"; then
		print_warn "$name: 下载失败"
		rm -rf "$tmp_dir"
		return 0
	fi

	# 清理旧安装
	rm -rf "$LSP_DIR/$name"
	mkdir -p "$LSP_DIR/$name"

	# 解压
	if ! tar -xzf "$tmp_dir/$tarball" -C "$LSP_DIR/$name"; then
		print_warn "$name: 解压失败"
		rm -rf "$tmp_dir"
		return 0
	fi
	rm -rf "$tmp_dir"

	# 创建 wrapper 脚本
	cat >"$LSP_BIN/jdtls" <<-'WRAPPER'
	#!/bin/bash
	# jdtls wrapper script
	# 自动查找 equinox launcher jar 并启动 Eclipse JDT Language Server

	JDTLS_HOME="$HOME/.local/share/lsp/jdtls"

	# 查找 equinox launcher jar
	LAUNCHER_JAR=$(find "$JDTLS_HOME/plugins" -name 'org.eclipse.equinox.launcher_*.jar' -print -quit 2>/dev/null)
	if [[ -z "$LAUNCHER_JAR" ]]; then
	    echo "Error: Cannot find equinox launcher jar" >&2
	    exit 1
	fi

	# 配置目录
	CONFIG_DIR="$JDTLS_HOME/config_linux"

	# 每个项目使用独立的 data 目录（基于工作目录的哈希）
	PROJECT_DIR="${1:-$(pwd)}"
	PROJECT_HASH=$(echo "$PROJECT_DIR" | md5sum | cut -d' ' -f1)
	DATA_DIR="$HOME/.cache/jdtls/workspace-${PROJECT_HASH}"
	mkdir -p "$DATA_DIR"

	exec java \
	    -Declipse.application=org.eclipse.jdt.ls.core.id1 \
	    -Dosgi.bundles.defaultStartLevel=4 \
	    -Declipse.product=org.eclipse.jdt.ls.core.product \
	    -Dlog.protocol=true \
	    -Dlog.level=ALL \
	    -Xms1g \
	    -Xmx2G \
	    --add-modules=ALL-SYSTEM \
	    --add-opens java.base/java.util=ALL-UNNAMED \
	    --add-opens java.base/java.lang=ALL-UNNAMED \
	    -jar "$LAUNCHER_JAR" \
	    -configuration "$CONFIG_DIR" \
	    -data "$DATA_DIR" \
	    "$@"
	WRAPPER
	chmod +x "$LSP_BIN/jdtls"

	save_local_version "$name" "$latest"
	print_success "$name $latest 安装完成"
}

# ========================================
# 主函数
# ========================================
main() {
	print_section "🔧 安装 LSP Servers"

	ensure_lsp_dirs

	install_rust_analyzer
	install_gopls
	install_npm_lsps
	install_csharp_ls
	install_kotlin_ls
	install_lua_ls
	install_jdtls

	_echo_blank
	print_success "LSP Servers 安装完成"
}

main "$@"
