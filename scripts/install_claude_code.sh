#!/bin/bash
# Claude Code 安装脚本
# 1) 安装 LSP 二进制（rust-analyzer, gopls, kotlin-ls 等）
# 2) 安装 Claude Code CLI（原生安装器）
# 3) 添加插件 marketplace
# 4) 安装 LSP 插件和 skill 插件
#
# macOS 通过 brew cask 安装 CLI（见 lib/packages.sh），此脚本仅负责 Linux 安装 + 全平台插件配置

set -eo pipefail

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

# ========================================
# 配置
# ========================================

# LSP 安装目录
LSP_DIR="$HOME/.local/share/lsp"
LSP_BIN="$HOME/.local/bin"

# Claude Code 插件配置目录
CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins"
INSTALLED_PLUGINS_JSON="$CLAUDE_PLUGINS_DIR/installed_plugins.json"
KNOWN_MARKETPLACES_JSON="$CLAUDE_PLUGINS_DIR/known_marketplaces.json"

# 插件 Marketplace 列表 (GitHub owner/repo)
MARKETPLACES=(
	anthropics/claude-plugins-official
	anthropics/skills
	obra/superpowers-marketplace
)

# LSP 插件 (plugin@marketplace)
LSP_PLUGINS=(
	pyright-lsp@claude-plugins-official
	typescript-lsp@claude-plugins-official
	gopls-lsp@claude-plugins-official
	rust-analyzer-lsp@claude-plugins-official
	jdtls-lsp@claude-plugins-official
	clangd-lsp@claude-plugins-official
	csharp-lsp@claude-plugins-official
	php-lsp@claude-plugins-official
	kotlin-lsp@claude-plugins-official
	swift-lsp@claude-plugins-official
	lua-lsp@claude-plugins-official
)

# 工具插件 (plugin@marketplace)
TOOL_PLUGINS=(
	github@claude-plugins-official
	commit-commands@claude-plugins-official
	code-simplifier@claude-plugins-official
)

# Skill 插件 (plugin@marketplace)
SKILL_PLUGINS=(
	example-skills@anthropic-agent-skills
	superpowers@superpowers-marketplace
)

# ========================================
# LSP 辅助函数
# ========================================

# 确保 LSP 目录存在
ensure_lsp_dirs() {
	mkdir -p "$LSP_DIR" "$LSP_BIN"
}

# ========================================
# LSP 安装函数
# ========================================

# 1. rust-analyzer (Both platforms)
# 优先使用 rustup，无 rustup 时从 GitHub Releases 下载预编译二进制
install_rust_analyzer() {
	# 方式 1: rustup（macOS brew 安装的 rust 自带 rustup）
	if command -v rustup &>/dev/null; then
		print_info "安装 rust-analyzer (via rustup)..."
		if rustup component add rust-analyzer >/dev/null; then
			print_success "rust-analyzer 安装完成"
		else
			print_warn "rust-analyzer 安装失败"
		fi
		return 0
	fi

	# 方式 2: GitHub Releases 下载（Linux pixi 环境无 rustup）
	local name="rust-analyzer"
	local repo="rust-lang/rust-analyzer"

	print_info "安装 $name (via GitHub release)..."

	local latest
	latest=$(github_latest_release "$repo") || true
	if [[ -z "$latest" ]]; then
		print_warn "$name: 无法获取最新版本，跳过"
		return 0
	fi

	local local_ver
	local_ver=$(get_local_version "$LSP_DIR/$name")
	if [[ "$local_ver" == "$latest" ]]; then
		print_success "$name 已是最新版本 ($latest)"
		return 0
	fi

	print_dim "版本: ${local_ver:-无} -> $latest"

	# 确定平台和架构
	local platform
	if [[ "$OS" == "macos" ]]; then
		if [[ "$ARCH" == "aarch64" ]]; then
			platform="aarch64-apple-darwin"
		else
			platform="x86_64-apple-darwin"
		fi
	else
		if [[ "$ARCH" == "aarch64" ]]; then
			platform="aarch64-unknown-linux-gnu"
		else
			platform="x86_64-unknown-linux-gnu"
		fi
	fi

	local download_url="https://github.com/${repo}/releases/download/${latest}/rust-analyzer-${platform}.gz"
	local tmp_dir
	tmp_dir=$(mktemp -d)

	if ! curl -fsSL "$download_url" -o "$tmp_dir/rust-analyzer.gz"; then
		print_warn "$name: 下载失败"
		rm -rf "$tmp_dir"
		return 0
	fi

	# 解压 .gz 并安装到 ~/.local/bin
	gunzip "$tmp_dir/rust-analyzer.gz"
	chmod +x "$tmp_dir/rust-analyzer"
	mv "$tmp_dir/rust-analyzer" "$LSP_BIN/rust-analyzer"
	rm -rf "$tmp_dir"

	save_local_version "$LSP_DIR/$name" "$latest"
	print_success "$name $latest 安装完成"
}

# 2. gopls (Linux only, macOS uses brew)
install_gopls() {
	if [[ "$OS" == "macos" ]]; then
		return 0
	fi

	print_info "安装 gopls..."
	if ! command -v go &>/dev/null; then
		print_warn "go 未找到，跳过 gopls"
		return 0
	fi
	if go install golang.org/x/tools/gopls@latest >/dev/null; then
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

	print_info "安装 npm LSP servers..."

	# typescript-language-server
	if command -v typescript-language-server &>/dev/null; then
		print_success "typescript-language-server 已安装"
	else
		print_info "安装 typescript-language-server..."
		if npm install -g typescript-language-server typescript >/dev/null; then
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
		if npm install -g intelephense >/dev/null; then
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
	if dotnet tool install -g csharp-ls >/dev/null; then
		print_success "csharp-ls 安装完成"
	else
		# 已安装时 install 会失败，尝试 update
		if dotnet tool update -g csharp-ls >/dev/null; then
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
	latest=$(github_latest_release "$repo") || true
	if [[ -z "$latest" ]]; then
		print_warn "$name: 无法获取最新版本，跳过"
		return 0
	fi

	local local_ver
	local_ver=$(get_local_version "$LSP_DIR/$name")
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

	# 解压到暂存目录（成功后再替换旧安装，避免解压失败丢失已有版本）
	mkdir -p "$tmp_dir/staging"
	if ! unzip -qo "$tmp_dir/server.zip" -d "$tmp_dir/staging"; then
		print_warn "$name: 解压失败"
		rm -rf "$tmp_dir"
		return 0
	fi
	rm -rf "$LSP_DIR/$name"
	mv "$tmp_dir/staging" "$LSP_DIR/$name"
	rm -rf "$tmp_dir"

	# 创建符号链接
	chmod +x "$LSP_DIR/$name/server/bin/kotlin-language-server"
	ln -sf "$LSP_DIR/$name/server/bin/kotlin-language-server" "$LSP_BIN/kotlin-language-server"

	save_local_version "$LSP_DIR/$name" "$latest"
	print_success "$name $latest 安装完成"
}

# 6. lua-language-server (Linux only, macOS uses brew)
install_lua_ls() {
	if [[ "$OS" == "macos" ]]; then
		return 0
	fi

	local name="lua-language-server"
	local repo="LuaLS/lua-language-server"

	print_info "安装 $name..."

	local latest
	latest=$(github_latest_release "$repo") || true
	if [[ -z "$latest" ]]; then
		print_warn "$name: 无法获取最新版本，跳过"
		return 0
	fi

	local local_ver
	local_ver=$(get_local_version "$LSP_DIR/$name")
	if [[ "$local_ver" == "$latest" ]]; then
		print_success "$name 已是最新版本 ($latest)"
		return 0
	fi

	print_dim "版本: ${local_ver:-无} -> $latest"

	# 确定平台标识
	local platform
	if [[ "$ARCH" == "aarch64" ]]; then
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

	# 解压到暂存目录（成功后再替换旧安装，避免解压失败丢失已有版本）
	mkdir -p "$tmp_dir/staging"
	if ! tar -xzf "$tmp_dir/$tarball" -C "$tmp_dir/staging"; then
		print_warn "$name: 解压失败"
		rm -rf "$tmp_dir"
		return 0
	fi
	rm -rf "$LSP_DIR/$name"
	mv "$tmp_dir/staging" "$LSP_DIR/$name"
	rm -rf "$tmp_dir"

	# 创建 wrapper 脚本
	cat >"$LSP_BIN/lua-language-server" <<-'WRAPPER'
	#!/bin/bash
	exec "$HOME/.local/share/lsp/lua-language-server/bin/lua-language-server" "$@"
	WRAPPER
	chmod +x "$LSP_BIN/lua-language-server"

	save_local_version "$LSP_DIR/$name" "$latest"
	print_success "$name $latest 安装完成"
}

# 7. jdtls (Linux only, macOS uses brew)
# jdtls 不使用 GitHub Releases 发布正式版本，从 Eclipse 官方镜像下载
# 通过 Homebrew API 获取最新版本号（与 brew install jdtls 保持一致）
install_jdtls() {
	if [[ "$OS" == "macos" ]]; then
		return 0
	fi

	local name="jdtls"

	print_info "安装 $name..."

	if ! command -v java &>/dev/null; then
		print_warn "java 未找到，跳过 jdtls"
		return 0
	fi

	# 从 Homebrew formula API 获取最新版本和下载 URL
	local brew_json
	brew_json=$(curl -fsSL "https://formulae.brew.sh/api/formula/jdtls.json" 2>/dev/null) || true
	if [[ -z "$brew_json" ]]; then
		print_warn "$name: 无法获取版本信息，跳过"
		return 0
	fi

	local latest download_url
	latest=$(echo "$brew_json" | jq -r '.versions.stable // empty' 2>/dev/null)
	download_url=$(echo "$brew_json" | jq -r '.urls.stable.url // empty' 2>/dev/null)

	if [[ -z "$latest" || -z "$download_url" ]]; then
		print_warn "$name: 无法解析版本信息，跳过"
		return 0
	fi

	local local_ver
	local_ver=$(get_local_version "$LSP_DIR/$name")
	if [[ "$local_ver" == "$latest" ]]; then
		print_success "$name 已是最新版本 ($latest)"
		return 0
	fi

	print_dim "版本: ${local_ver:-无} -> $latest"

	local tmp_dir
	tmp_dir=$(mktemp -d)

	if ! curl -fsSL "$download_url" -o "$tmp_dir/jdtls.tar.gz"; then
		print_warn "$name: 下载失败"
		rm -rf "$tmp_dir"
		return 0
	fi

	# 解压到暂存目录（成功后再替换旧安装，避免解压失败丢失已有版本）
	mkdir -p "$tmp_dir/staging"
	if ! tar -xzf "$tmp_dir/jdtls.tar.gz" -C "$tmp_dir/staging"; then
		print_warn "$name: 解压失败"
		rm -rf "$tmp_dir"
		return 0
	fi
	rm -rf "$LSP_DIR/$name"
	mv "$tmp_dir/staging" "$LSP_DIR/$name"
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
	PROJECT_HASH=$(echo -n "$(pwd)" | md5sum | cut -d' ' -f1)
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

	save_local_version "$LSP_DIR/$name" "$latest"
	print_success "$name $latest 安装完成"
}

# ========================================
# 检查函数
# ========================================

# 检查 marketplace 是否已添加
# 参数: $1 = GitHub owner/repo (例如 anthropics/claude-plugins-official)
is_marketplace_installed() {
	local repo="$1"
	[[ -f "$KNOWN_MARKETPLACES_JSON" ]] && \
		jq -e --arg repo "$repo" 'any(.[]; .source.repo == $repo)' "$KNOWN_MARKETPLACES_JSON" &>/dev/null
}

# 检查插件是否已安装（通过 CLI 而非 JSON）
# 参数: $1 = plugin@marketplace (例如 pyright-lsp@claude-plugins-official)
is_plugin_installed() {
	local plugin="$1"
	claude plugin list 2>/dev/null | grep -q "^  ❯ ${plugin}$"
}

# ========================================
# 安装 Claude Code CLI
# ========================================
install_cli() {
	if command -v claude &>/dev/null; then
		local ver
		ver=$(claude --version 2>/dev/null | head -1)
		print_success "Claude Code CLI 已安装 ($ver)"
		return 0
	fi

	if [[ "$OS" == "macos" ]]; then
		# macOS 由 brew cask 安装，此处不处理
		print_warn "Claude Code CLI 未安装，请先运行 brew install --cask claude-code"
		return 1
	fi

	# Linux: 使用原生安装器
	print_info "安装 Claude Code CLI (原生安装器)..."
	if curl -fsSL https://claude.ai/install.sh | sh; then
		# 确保新安装的 claude 在 PATH 中
		export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
		print_success "Claude Code CLI 安装完成"
	else
		print_warn "Claude Code CLI 安装失败"
		return 1
	fi
}

# ========================================
# 预填充 GitHub Host Key
# ========================================

# Claude CLI 内部 git clone 使用 -c core.sshCommand="ssh -o StrictHostKeyChecking=yes"，
# 要求 host key 必须已存在于 known_hosts 中，否则连接被拒绝。
# 通过 ssh-keyscan 预先获取 GitHub 的 host key 来满足此要求。
ensure_github_host_keys() {
	local known_hosts="$HOME/.ssh/known_hosts"
	mkdir -p -m 700 "$HOME/.ssh"

	local added=0
	# 分别检查并填充每个 host key，避免重复追加
	if ! grep -q "^github\.com " "$known_hosts" 2>/dev/null; then
		ssh-keyscan github.com >>"$known_hosts" 2>/dev/null && ((added++))
	fi
	if ! grep -q "^\[ssh\.github\.com\]:443 " "$known_hosts" 2>/dev/null; then
		ssh-keyscan -p 443 ssh.github.com >>"$known_hosts" 2>/dev/null && ((added++))
	fi

	if ((added > 0)); then
		print_success "GitHub host key 已添加 ($added)"
	else
		print_success "GitHub host key 已存在"
	fi
}

# ========================================
# 添加 Marketplace
# ========================================
add_marketplaces() {
	print_info "配置插件 Marketplace..."

	local added=0 skipped=0 failed=0
	for repo in "${MARKETPLACES[@]}"; do
		if is_marketplace_installed "$repo"; then
			skipped=$((skipped + 1))
			continue
		fi
		if claude plugin marketplace add "$repo" &>/dev/null; then
			print_success "Marketplace: $repo"
			added=$((added + 1))
		else
			print_warn "Marketplace 添加失败: $repo"
			failed=$((failed + 1))
		fi
	done

	if [[ $failed -eq 0 && $skipped -gt 0 && $added -eq 0 ]]; then
		print_success "所有 Marketplace 已配置 (${#MARKETPLACES[@]} 个)"
	elif [[ $skipped -gt 0 ]]; then
		print_dim "跳过 $skipped 个已存在的 Marketplace"
	fi
}

# ========================================
# 安装插件（通用函数）
# ========================================
install_plugins() {
	local label="$1"
	shift
	local plugins=("$@")

	print_info "安装${label}插件..."

	local installed=0 skipped=0 failed=0
	for plugin in "${plugins[@]}"; do
		if is_plugin_installed "$plugin"; then
			skipped=$((skipped + 1))
			continue
		fi
		if claude plugin install "$plugin" &>/dev/null; then
			print_success "$plugin"
			installed=$((installed + 1))
		else
			print_warn "安装失败: $plugin"
			failed=$((failed + 1))
		fi
	done

	if [[ $skipped -gt 0 && $installed -eq 0 && $failed -eq 0 ]]; then
		print_success "所有${label}插件已安装 (${#plugins[@]} 个)"
	elif [[ $skipped -gt 0 ]]; then
		print_dim "跳过 $skipped 个已安装的插件"
	fi
}

# ========================================
# 激活插件
# ========================================
enable_plugins() {
	local settings_file="$HOME/.claude/settings.json"

	if [[ ! -f "$settings_file" ]]; then
		print_warn "settings.json 不存在，跳过插件激活"
		return 1
	fi

	if ! command -v jq &>/dev/null; then
		print_warn "jq 未安装，跳过插件激活"
		return 1
	fi

	local plugins=("$@")
	local enabled=0

	for plugin in "${plugins[@]}"; do
		# 检查插件是否已启用
		if jq -e --arg p "$plugin" '.enabledPlugins[$p] == true' "$settings_file" &>/dev/null; then
			continue
		fi

		# 启用插件
		jq --arg p "$plugin" '.enabledPlugins[$p] = true' "$settings_file" > "$settings_file.tmp" && \
			mv "$settings_file.tmp" "$settings_file"
		enabled=$((enabled + 1))
	done

	if [[ $enabled -gt 0 ]]; then
		print_success "已激活 $enabled 个插件"
	fi
}

# ========================================
# 主函数
# ========================================
main() {
	# 缓存平台信息
	OS=$(detect_os)
	ARCH=$(detect_arch)

	# 1) 安装 LSP 二进制
	ensure_lsp_dirs
	install_rust_analyzer
	install_gopls
	install_npm_lsps
	install_csharp_ls
	install_kotlin_ls
	install_lua_ls
	install_jdtls
	print_success "LSP Servers 安装完成"
	_echo_blank

	# 2) 安装 CLI
	install_cli || return 0

	# 确认 claude 可用
	if ! command -v claude &>/dev/null; then
		print_warn "Claude Code CLI 不在 PATH 中，跳过插件配置"
		return 0
	fi

	# 3) 预填充 GitHub host key
	# Claude CLI 内部 git clone 强制 StrictHostKeyChecking=yes，
	# 需要 host key 预先存在于 known_hosts 中
	ensure_github_host_keys

	# 4) 添加 Marketplace
	add_marketplaces

	# 5) 安装 LSP 插件
	install_plugins "LSP " "${LSP_PLUGINS[@]}"
	enable_plugins "${LSP_PLUGINS[@]}"

	# 6) 安装工具插件
	install_plugins "Tool " "${TOOL_PLUGINS[@]}"
	enable_plugins "${TOOL_PLUGINS[@]}"

	# 7) 安装 Skill 插件
	install_plugins "Skill " "${SKILL_PLUGINS[@]}"
	enable_plugins "${SKILL_PLUGINS[@]}"

	print_success "Claude Code 配置完成"
	_echo_blank

	# 提示用户重启以激活 LSP servers
	print_info "⚠️  重要提示："
	print_dim "   LSP 插件需要重启 Claude Code 才能激活"
	print_dim "   请退出当前会话并重新运行 'claude' 命令"
}

main "$@"
