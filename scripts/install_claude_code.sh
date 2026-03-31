#!/bin/bash
# Claude Code 安装脚本
# 1) 安装 LSP 二进制（rust-analyzer, gopls, kotlin-ls 等）
# 2) 安装 Claude Code CLI（原生安装器）
# 3) 启用自动更新（写入 ~/.claude.json）
# 4) 添加插件 marketplace
# 5) 安装 LSP 插件和 skill 插件
# 6) 安装独立 Skill（study-master 等，在线 clone 安装）
#
# macOS 通过 brew cask 安装 CLI（见 lib/packages.sh），此脚本仅负责 Linux 安装 + 全平台插件配置

set -euo pipefail

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

# 清理 jq 操作残留的 .tmp 文件（Ctrl+C 中断时可能残留）
trap 'rm -f "$HOME/.claude/settings.json.tmp" "$HOME/.claude.json.tmp"' EXIT

# ========================================
# 配置
# ========================================

# 平台信息（由 main() 初始化，多个安装函数隐式引用）
OS=""
ARCH=""

# LSP 安装目录
LSP_DIR="$HOME/.local/share/lsp"
LSP_BIN="$HOME/.local/bin"

# Claude Code 插件配置目录
CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins"
KNOWN_MARKETPLACES_JSON="$CLAUDE_PLUGINS_DIR/known_marketplaces.json"

# 插件 Marketplace 列表 (GitHub owner/repo)
MARKETPLACES=(
	anthropics/claude-plugins-official
	anthropics/skills
	obra/superpowers-marketplace
	jarrodwatts/claude-hud
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
	claude-hud@claude-hud
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
	check_github_update "$name" "$repo" "$LSP_DIR/$name" || return 0
	local latest="$_GITHUB_LATEST"

	local platform
	platform=$(get_platform_triple "$OS" "$ARCH")

	local download_url="https://github.com/${repo}/releases/download/${latest}/rust-analyzer-${platform}.gz"

	if ! download_and_extract "$download_url" "$LSP_BIN/rust-analyzer" "gz"; then
		print_warn "$name: 下载或解压失败"
		return 0
	fi

	save_local_version "$LSP_DIR/$name" "$latest"
	print_success "$name $latest 安装完成"
}

# 2. gopls (Linux only — 由 main() 按平台调用)
install_gopls() {
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

	# 命令名:安装包（命令名用于检测是否已安装，安装包可含多个空格分隔）
	local npm_lsps=(
		"typescript-language-server:typescript-language-server typescript"
		"intelephense:intelephense"
	)

	for entry in "${npm_lsps[@]}"; do
		local cmd_name="${entry%%:*}"
		local packages="${entry#*:}"
		if command -v "$cmd_name" &>/dev/null; then
			print_success "$cmd_name 已安装"
		else
			print_info "安装 $cmd_name..."
			if npm install -g $packages &>/dev/null; then
				print_success "$cmd_name 安装完成"
			else
				print_warn "$cmd_name 安装失败"
			fi
		fi
	done
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
	check_github_update "$name" "$repo" "$LSP_DIR/$name" || return 0
	local latest="$_GITHUB_LATEST"

	local download_url="https://github.com/${repo}/releases/download/${latest}/server.zip"

	if ! download_and_extract "$download_url" "$LSP_DIR/$name" "zip"; then
		print_warn "$name: 下载或解压失败"
		return 0
	fi

	# 创建符号链接
	chmod +x "$LSP_DIR/$name/server/bin/kotlin-language-server"
	ln -sf "$LSP_DIR/$name/server/bin/kotlin-language-server" "$LSP_BIN/kotlin-language-server"

	save_local_version "$LSP_DIR/$name" "$latest"
	print_success "$name $latest 安装完成"
}

# 6. lua-language-server (Linux only — 由 main() 按平台调用)
install_lua_ls() {
	local name="lua-language-server"
	local repo="LuaLS/lua-language-server"

	print_info "安装 $name..."
	check_github_update "$name" "$repo" "$LSP_DIR/$name" || return 0
	local latest="$_GITHUB_LATEST"

	# lua-ls 使用简化格式（linux-arm64 / linux-x64），不同于 Rust triple
	local platform
	[[ "$ARCH" == "aarch64" ]] && platform="linux-arm64" || platform="linux-x64"

	# 版本号去掉开头的 v
	local ver_without_v="${latest#v}"
	local tarball="lua-language-server-${ver_without_v}-${platform}.tar.gz"
	local download_url="https://github.com/${repo}/releases/download/${latest}/${tarball}"

	if ! download_and_extract "$download_url" "$LSP_DIR/$name" "tar.gz"; then
		print_warn "$name: 下载或解压失败"
		return 0
	fi

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

	if ! download_and_extract "$download_url" "$LSP_DIR/$name" "tar.gz"; then
		print_warn "$name: 下载或解压失败"
		return 0
	fi

	# 安装 wrapper 脚本（从仓库独立文件复制，便于 ShellCheck 检查和独立维护）
	local wrapper_src="$SCRIPT_DIR/wrappers/jdtls"
	if [[ -f "$wrapper_src" ]]; then
		cp "$wrapper_src" "$LSP_BIN/jdtls"
		chmod +x "$LSP_BIN/jdtls"
	else
		print_warn "jdtls wrapper 脚本不存在: $wrapper_src"
	fi

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
	claude plugin list 2>/dev/null | grep -qF "$plugin"
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
		# macOS 由 brew cask 安装。未安装时跳过 Claude 专属配置，不阻断主安装流程。
		print_warn "Claude Code CLI 未安装，跳过 Claude 插件/MCP 配置；如需启用请先运行 brew install --cask claude-code"
		return 0
	fi

	# Linux: 使用原生安装器
	print_info "安装 Claude Code CLI (原生安装器)..."
	if curl -fsSL https://claude.ai/install.sh | sh; then
		# 确保新安装的 claude 在 PATH 中
		export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
		print_success "Claude Code CLI 安装完成"
	else
		print_warn "Claude Code CLI 安装失败，跳过 Claude 插件/MCP 配置"
		return 0
	fi
}

# ========================================
# 预填充 GitHub Host Key
# ========================================

# Claude CLI 内部 git clone 使用 -c core.sshCommand="ssh -o StrictHostKeyChecking=yes"，
# 要求 host key 必须已存在于 known_hosts 中，否则连接被拒绝。
# 这里直接写入 GitHub 官方文档公布的 host keys，避免运行时 ssh-keyscan 的 TOFU 风险。
# 对 [ssh.github.com]:443 使用与 github.com 相同的官方 host keys。
ensure_github_host_keys() {
	local known_hosts="$HOME/.ssh/known_hosts"
	mkdir -p -m 700 "$HOME/.ssh"
	local tmp_known_hosts added=0 entry
	tmp_known_hosts=$(mktemp)
	[[ -f "$known_hosts" ]] && cat "$known_hosts" >"$tmp_known_hosts"

	while IFS= read -r entry; do
		[[ -n "$entry" ]] || continue
		if ! grep -qxF "$entry" "$tmp_known_hosts" 2>/dev/null; then
			printf '%s\n' "$entry" >>"$tmp_known_hosts"
			((added++))
		fi
	done <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
[ssh.github.com]:443 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
[ssh.github.com]:443 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
[ssh.github.com]:443 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
EOF

	if [[ -e "$known_hosts" || -L "$known_hosts" ]]; then
		cat "$tmp_known_hosts" >"$known_hosts"
		rm -f "$tmp_known_hosts"
	else
		mv "$tmp_known_hosts" "$known_hosts"
	fi
	chmod 600 "$known_hosts"

	if ((added > 0)); then
		print_success "GitHub 官方 host keys 已写入 known_hosts ($added)"
	else
		print_success "GitHub 官方 host keys 已存在"
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

	print_install_summary "Marketplace" "$added" "$skipped" "$failed"
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

	print_install_summary "${label}插件" "$installed" "$skipped" "$failed"
}

# ========================================
# 配置自动更新（写入 ~/.claude.json 运行时偏好）
# ========================================
configure_auto_updates() {
	local config_file="$HOME/.claude.json"

	if [[ ! -f "$config_file" ]]; then
		printf '{\n  "autoUpdates": true\n}\n' >"$config_file"
		print_success "已创建 ~/.claude.json 并启用自动更新"
		return 0
	fi

	if ! command -v jq &>/dev/null; then
		print_warn "jq 未安装，跳过自动更新配置"
		return 0
	fi

	# 已经是 true 则跳过
	if jq -e '.autoUpdates == true' "$config_file" &>/dev/null; then
		print_success "自动更新已启用"
		return 0
	fi

	if jq '.autoUpdates = true' "$config_file" > "$config_file.tmp" && [[ -s "$config_file.tmp" ]]; then
		mv "$config_file.tmp" "$config_file"
		print_success "已启用自动更新"
	else
		rm -f "$config_file.tmp"
		print_warn "自动更新配置写入失败"
	fi
}

ensure_claude_settings_file() {
	local settings_file="$HOME/.claude/settings.json"
	local repo_settings="$SCRIPT_DIR/../.claude/settings.json"
	local global_settings_template="$SCRIPT_DIR/../.claude/settings.global.json"
	local tmp_settings

	[[ -f "$settings_file" ]] && return 0

	mkdir -p "$HOME/.claude"
	tmp_settings=$(mktemp)

	if [[ -f "$repo_settings" ]]; then
		if command -v jq &>/dev/null; then
			if jq 'del(.hooks)' "$repo_settings" >"$tmp_settings" 2>/dev/null && [[ -s "$tmp_settings" ]]; then
				mv "$tmp_settings" "$settings_file"
				print_dim "~/.claude/settings.json 已创建（不含项目级 hooks）"
				return 0
			fi
		fi

		if command -v python3 &>/dev/null; then
			if python3 -c "
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
d.pop('hooks', None)
with open(sys.argv[2], 'w') as f: json.dump(d, f, indent=4, ensure_ascii=False)
" "$repo_settings" "$tmp_settings" 2>/dev/null && [[ -s "$tmp_settings" ]]; then
				mv "$tmp_settings" "$settings_file"
				print_dim "~/.claude/settings.json 已创建（不含项目级 hooks）"
				return 0
			fi
		fi
	fi

	if [[ -f "$global_settings_template" ]]; then
		cp "$global_settings_template" "$tmp_settings"
		mv "$tmp_settings" "$settings_file"
		print_warn "无法从仓库安全剥离 hooks，已写入 hook-free 全局 Claude 配置模板"
		return 0
	fi

	rm -f "$tmp_settings"
	print_warn "未找到 hook-free Claude 配置模板，跳过 settings.json 初始化"
}

# ========================================
# 激活插件
# ========================================
enable_plugins() {
	local settings_file="$HOME/.claude/settings.json"

	if [[ ! -f "$settings_file" ]]; then
		print_warn "settings.json 不存在，跳过插件激活"
		return 0
	fi

	if ! command -v jq &>/dev/null; then
		print_warn "jq 未安装，跳过插件激活"
		return 0
	fi

	local plugins=("$@")
	local enabled=0

	for plugin in "${plugins[@]}"; do
		# 检查插件是否已启用
		if jq -e --arg p "$plugin" '.enabledPlugins[$p] == true' "$settings_file" &>/dev/null; then
			continue
		fi

		# 启用插件（非空检查防止 jq 失败时用空文件覆盖）
		if jq --arg p "$plugin" '.enabledPlugins[$p] = true' "$settings_file" > "$settings_file.tmp" && [[ -s "$settings_file.tmp" ]]; then
			mv "$settings_file.tmp" "$settings_file"
		else
			rm -f "$settings_file.tmp"
		fi
		enabled=$((enabled + 1))
	done

	if [[ $enabled -gt 0 ]]; then
		print_success "已激活 $enabled 个插件"
	fi
}

# ========================================
# study-master Skill 安装（独立 GitHub 仓库）
# ========================================

# 确保 study-master hooks 已在 settings.json 中注册
# 独立于文件部署——每次安装都执行，防止 install_dotfiles.sh 的 jq 合并覆盖动态 hooks
ensure_study_master_hooks() {
	local settings_file="$1"
	local hook_matcher="$2"
	local hook_cmd="$3"

	[[ -f "$settings_file" ]] && command -v jq &>/dev/null || return 0

	# 已注册则跳过
	if jq -e --arg m "$hook_matcher" --arg cmd "$hook_cmd" \
		'.hooks.PostToolUse // [] | any(.matcher == $m and (.hooks | any(.command == $cmd)))' \
		"$settings_file" &>/dev/null; then
		return 0
	fi

	# 注册 hook
	# jq 逻辑: 确保 .hooks.PostToolUse 路径存在 → matcher 已有则追加 command，否则新建条目
	jq --arg m "$hook_matcher" --arg cmd "$hook_cmd" '
		.hooks //= {} |
		.hooks.PostToolUse //= [] |
		if (.hooks.PostToolUse | any(.matcher == $m)) then
			(.hooks.PostToolUse[] | select(.matcher == $m)).hooks += [{"type":"command","command":$cmd,"timeout":10}]
		else
			.hooks.PostToolUse += [{"matcher":$m,"hooks":[{"type":"command","command":$cmd,"timeout":10}]}]
		end
	' "$settings_file" > "$settings_file.tmp"
	if [[ -s "$settings_file.tmp" ]]; then
		mv "$settings_file.tmp" "$settings_file"
		print_dim "  study-master hooks 已注册"
	else
		rm -f "$settings_file.tmp"
		print_warn "  study-master hooks 注册失败"
	fi
}

# 在线 clone 仓库，手动部署文件并注册 hooks
# 不使用上游 install.sh（其 hook 注册路径和格式有误）
install_study_master_skill() {
	local repo="Learner-Geek-Perfectionist/claude-code-study-skills"
	local skill_dir="$HOME/.claude/skills/study-master"
	local hooks_dir="$HOME/.claude/hooks"
	local settings_file="$HOME/.claude/settings.json"
	local hook_matcher="Write|Edit"
	local hook_cmd='bash "$HOME/.claude/hooks/check-study_master.sh"'

	# 1) 部署 Skill 文件（幂等：已存在则跳过 clone）
	if [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]]; then
		print_success "study-master Skill 已安装"
	else
		print_info "安装 study-master Skill..."

		local tmp_dir
		tmp_dir=$(mktemp -d)

		if ! git clone --depth 1 "https://github.com/${repo}.git" "$tmp_dir" &>/dev/null; then
			print_warn "study-master: clone 失败"
			rm -rf "$tmp_dir"
			return 0
		fi

		local src="$tmp_dir/study-master-skill"

		# 复制 Skill 文件
		mkdir -p "$skill_dir"
		cp "$src/SKILL.md" "$skill_dir/"
		print_dim "  Skill: $skill_dir/SKILL.md"

		# 复制 Hook 脚本
		if [[ -d "$src/hooks" ]]; then
			mkdir -p "$hooks_dir"
			for file in "$src/hooks"/*; do
				[[ -f "$file" ]] || continue
				cp "$file" "$hooks_dir/"
				chmod +x "$hooks_dir/$(basename "$file")"
			done
			print_dim "  Hooks: $(ls "$src/hooks" | tr '\n' ' ')"
		fi

		rm -rf "$tmp_dir"

		# 清理上游 install.sh 遗留的错误配置
		local dead_settings="$HOME/.claude/settings/settings.json"
		if [[ -f "$dead_settings" ]]; then
			rm -f "$dead_settings"
			rmdir "$HOME/.claude/settings" 2>/dev/null || true
			print_dim "  已清理无效的 ~/.claude/settings/settings.json"
		fi

		print_success "study-master Skill 安装完成"
	fi

	# 2) 确保 hooks 已注册（每次都检查，防止被 settings.json 合并覆盖）
	ensure_study_master_hooks "$settings_file" "$hook_matcher" "$hook_cmd"
}

# ========================================
# Claude HUD StatusLine 配置
# ========================================

# 等价于 /claude-hud:setup：检测 runtime → 生成动态命令 → 写入 settings.json
# 部署 HUD 显示偏好配置（jq 合并：保留用户自定义，补充 Dotfiles 新增选项）
_deploy_hud_config() {
	local hud_config_src="$SCRIPT_DIR/../.claude/plugins/claude-hud/config.json"
	local hud_config_dir="$HOME/.claude/plugins/claude-hud"
	local hud_config="$hud_config_dir/config.json"
	[[ -f "$hud_config_src" ]] || return 0

	mkdir -p "$hud_config_dir"
	if [[ -f "$hud_config" ]] && command -v jq &>/dev/null; then
		local tmp_merged
		tmp_merged=$(mktemp)
		if jq -s '.[0] * .[1]' "$hud_config_src" "$hud_config" >"$tmp_merged" 2>/dev/null; then
			mv "$tmp_merged" "$hud_config"
		else
			rm -f "$tmp_merged"
		fi
	else
		cp "$hud_config_src" "$hud_config"
		print_success "claude-hud config.json 已部署"
	fi

	# 清理旧版 wrapper 脚本（已改为直接命令方式）
	rm -f "$hud_config_dir/hud-wrapper.sh" "$hud_config_dir/hud-proxy.mjs"
}

# 检测 runtime 并生成 HUD statusLine 命令
# 设置全局变量 _HUD_CMD 供调用方使用
_detect_hud_runtime() {
	local runtime source
	if command -v bun &>/dev/null; then
		runtime="$(command -v bun)"
		source="src/index.ts"
	elif command -v node &>/dev/null; then
		runtime="$(command -v node)"
		source="dist/index.js"
	else
		print_warn "未找到 node 或 bun，跳过 claude-hud statusLine 配置"
		return 1
	fi

	printf -v _HUD_CMD \
		'bash -c '\''base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/cache/claude-hud/claude-hud"; latest=$(ls "$base" | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1); exec "%s" "$base/$latest/%s"'\''' \
		"$runtime" "$source"
}

# 写入 statusLine 到 settings.json
_write_hud_statusline() {
	local hud_cmd="$1"
	local settings_file="$HOME/.claude/settings.json"

	# 检查是否已配置为相同命令
	if [[ -f "$settings_file" ]] && command -v jq &>/dev/null && \
		jq -e --arg cmd "$hud_cmd" '.statusLine.command == $cmd' "$settings_file" &>/dev/null; then
		print_success "claude-hud statusLine 已配置"
		return 0
	fi

	# 测试命令是否可用
	# 安全: $hud_cmd 由 _detect_hud_runtime() 内部 printf -v 构建，内容完全由脚本控制，无注入风险
	local test_output
	test_output=$(eval "$hud_cmd" 2>&1) || true
	if [[ -z "$test_output" ]]; then
		print_warn "claude-hud 命令测试无输出，跳过（可在 Claude Code 中运行 /claude-hud:setup 手动配置）"
		return 0
	fi

	# 写入（非空检查防止 jq 失败时覆盖）
	if [[ -f "$settings_file" ]] && command -v jq &>/dev/null; then
		if jq --arg cmd "$hud_cmd" '.statusLine = {"type": "command", "command": $cmd}' \
			"$settings_file" > "$settings_file.tmp" && [[ -s "$settings_file.tmp" ]]; then
			mv "$settings_file.tmp" "$settings_file"
			print_success "claude-hud statusLine 配置完成"
		else
			rm -f "$settings_file.tmp"
			print_warn "claude-hud statusLine 写入失败"
		fi
	else
		print_warn "无法写入 settings.json（文件不存在或缺少 jq）"
	fi
}

setup_claude_hud() {
	local plugin_base="$HOME/.claude/plugins/cache/claude-hud/claude-hud"
	if [[ ! -d "$plugin_base" ]]; then
		print_warn "claude-hud 插件未安装，跳过 statusLine 配置"
		return 0
	fi

	_deploy_hud_config
	_detect_hud_runtime || return 0
	_write_hud_statusline "$_HUD_CMD"
}

# ========================================
# MCP Servers 配置
# ========================================

# 简单 MCP Servers（name:npx-package 格式，用 claude mcp add 安装）
MCP_SERVERS=(
	"tavily:tavily-mcp"
	"fetch:@kazuph/mcp-fetch"
)

# HTTP MCP Servers（name:url 格式，用 claude mcp add --transport http 安装）
HTTP_MCP_SERVERS=(
	"exa:https://mcp.exa.ai/mcp"
)

# 安装 MCP Servers
install_mcp_servers() {
	print_info "配置 MCP Servers..."

	# 缓存 mcp list 输出，避免重复调用 claude CLI
	local mcp_list
	mcp_list="$(claude mcp list 2>/dev/null)"

	local installed=0 skipped=0 failed=0

	# 1) 简单 MCP Servers（数据驱动）
	for entry in "${MCP_SERVERS[@]}"; do
		local name="${entry%%:*}"
		local package="${entry#*:}"

		if echo "$mcp_list" | grep -q "$name:"; then
			skipped=$((skipped + 1))
			continue
		fi

		local output
		if output="$(claude mcp add "$name" --scope user -- npx -y "$package" 2>&1)"; then
			print_success "MCP: $name"
			installed=$((installed + 1))
		else
			# "already exists" 视为已安装（兜底 mcp list 格式变更时的检测失败）
			if [[ "$output" == *"already exists"* ]]; then
				skipped=$((skipped + 1))
			else
				print_warn "MCP $name 安装失败: $output"
				failed=$((failed + 1))
			fi
		fi
	done

	# TAVILY_API_KEY 通过 age-tokens 注入 shell 环境，MCP 子进程自动继承
	if echo "$mcp_list" | grep -q "tavily:" || [[ $installed -gt 0 ]]; then
		[[ -z "${TAVILY_API_KEY:-}" ]] && print_warn "提醒: 请通过 edit-tokens 添加 TAVILY_API_KEY"
	fi

	# 2) HTTP MCP Servers（远程 URL，无需本地 npx 进程）
	for entry in "${HTTP_MCP_SERVERS[@]}"; do
		local name="${entry%%:*}"
		local url="${entry#*:}"

		if echo "$mcp_list" | grep -q "$name:"; then
			skipped=$((skipped + 1))
			continue
		fi

		local output
		if output="$(claude mcp add "$name" --transport http "$url" --scope user 2>&1)"; then
			print_success "MCP: $name (HTTP)"
			installed=$((installed + 1))
		else
			if [[ "$output" == *"already exists"* ]]; then
				skipped=$((skipped + 1))
			else
				print_warn "MCP $name 安装失败: $output"
				failed=$((failed + 1))
			fi
		fi
	done

	# 3) Open-WebSearch MCP（需要 claude mcp add-json，有自定义 env）
	if echo "$mcp_list" | grep -q "open-websearch:"; then
		skipped=$((skipped + 1))
	else
		local output open_websearch_json
		open_websearch_json=$(cat <<EOF
{
	"type": "stdio",
	"command": "npx",
	"args": ["-y", "open-websearch@latest"],
	"env": {
		"MODE": "stdio",
		"DEFAULT_SEARCH_ENGINE": "duckduckgo",
		"ALLOWED_SEARCH_ENGINES": "bing,baidu,duckduckgo,csdn,juejin",
		"USE_PROXY": "true",
		"PROXY_URL": "${PROXY_URL:-http://127.0.0.1:7890}"
	}
}
EOF
)
		if output="$(claude mcp add-json open-websearch "$open_websearch_json" --scope user 2>&1)"; then
			print_success "MCP: open-websearch"
			installed=$((installed + 1))
		else
			if [[ "$output" == *"already exists"* ]]; then
				skipped=$((skipped + 1))
			else
				print_warn "MCP open-websearch 安装失败: $output"
				failed=$((failed + 1))
			fi
		fi
	fi

	print_install_summary "MCP Servers" "$installed" "$skipped" "$failed"
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
	install_npm_lsps
	install_csharp_ls
	install_kotlin_ls
	# gopls / lua-ls / jdtls 仅 Linux（macOS 通过 brew 安装）
	if [[ "$OS" != "macos" ]]; then
		install_gopls
		install_lua_ls
		install_jdtls
	fi
	print_success "LSP Servers 安装完成"
	_echo_blank

	# 2) 安装 CLI
	install_cli

	# 确认 claude 可用
	if ! command -v claude &>/dev/null; then
		print_warn "Claude Code CLI 不在 PATH 中，跳过插件配置"
		return 0
	fi

	ensure_claude_settings_file

	# 3) 启用自动更新（写入 ~/.claude.json 运行时偏好）
	configure_auto_updates

	# 4) 预填充 GitHub host key
	# Claude CLI 内部 git clone 强制 StrictHostKeyChecking=yes，
	# 需要 host key 预先存在于 known_hosts 中
	ensure_github_host_keys

	# 5) 添加 Marketplace
	add_marketplaces

	# 6) 安装 LSP 插件
	install_plugins "LSP " "${LSP_PLUGINS[@]}"
	enable_plugins "${LSP_PLUGINS[@]}"

	# 7) 安装工具插件
	install_plugins "Tool " "${TOOL_PLUGINS[@]}"
	enable_plugins "${TOOL_PLUGINS[@]}"

	# 8) 安装 Skill 插件
	install_plugins "Skill " "${SKILL_PLUGINS[@]}"
	enable_plugins "${SKILL_PLUGINS[@]}"

	# 9) 安装 study-master Skill（独立 GitHub 仓库，在线 clone 安装）
	install_study_master_skill

	# 10) 配置 claude-hud statusLine（等价于 /claude-hud:setup）
	setup_claude_hud

	# 11) 配置 MCP Servers（搜索增强：Tavily + Fetch + Open-WebSearch）
	install_mcp_servers

	print_success "Claude Code 配置完成"
	_echo_blank

	# 提示用户重启以激活 LSP servers
	print_info "⚠️  重要提示："
	print_dim "   LSP 插件需要重启 Claude Code 才能激活"
	print_dim "   请退出当前会话并重新运行 'claude' 命令"
}

main "$@"
