#!/bin/bash
# Claude Code 安装脚本
# 1) 安装 Claude Code CLI（原生安装器）
# 2) 添加插件 marketplace
# 3) 安装 LSP 插件和 skill 插件
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

# Claude Code 插件配置目录
CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins"
INSTALLED_PLUGINS_JSON="$CLAUDE_PLUGINS_DIR/installed_plugins.json"
KNOWN_MARKETPLACES_JSON="$CLAUDE_PLUGINS_DIR/known_marketplaces.json"

# 插件 Marketplace 列表 (GitHub owner/repo)
MARKETPLACES=(
	boostvolt/claude-code-lsps
	anthropics/skills
	obra/superpowers-marketplace
)

# LSP 插件 (plugin@marketplace)
LSP_PLUGINS=(
	pyright@claude-code-lsps
	vtsls@claude-code-lsps
	gopls@claude-code-lsps
	rust-analyzer@claude-code-lsps
	jdtls@claude-code-lsps
	clangd@claude-code-lsps
	omnisharp@claude-code-lsps
	intelephense@claude-code-lsps
	kotlin-lsp@claude-code-lsps
	sourcekit-lsp@claude-code-lsps
	lua-language-server@claude-code-lsps
)

# Skill 插件 (plugin@marketplace)
SKILL_PLUGINS=(
	example-skills@anthropic-agent-skills
	superpowers@superpowers-marketplace
)

# ========================================
# 检查函数
# ========================================

# 检查 marketplace 是否已添加
# 参数: $1 = GitHub owner/repo (例如 boostvolt/claude-code-lsps)
is_marketplace_installed() {
	local repo="$1"
	[[ -f "$KNOWN_MARKETPLACES_JSON" ]] && grep -q "\"$repo\"" "$KNOWN_MARKETPLACES_JSON"
}

# 检查插件是否已安装
# 参数: $1 = plugin@marketplace (例如 pyright@claude-code-lsps)
is_plugin_installed() {
	local plugin="$1"
	[[ -f "$INSTALLED_PLUGINS_JSON" ]] && grep -q "\"$plugin\"" "$INSTALLED_PLUGINS_JSON"
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

	local os
	os=$(detect_os)

	if [[ "$os" == "macos" ]]; then
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
# 添加 Marketplace
# ========================================
add_marketplaces() {
	print_info "配置插件 Marketplace..."

	local added=0 skipped=0
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
		fi
	done

	if [[ $skipped -gt 0 && $added -eq 0 ]]; then
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
# 主函数
# ========================================
main() {
	# 1) 安装 CLI
	install_cli || return 0

	# 确认 claude 可用
	if ! command -v claude &>/dev/null; then
		print_warn "Claude Code CLI 不在 PATH 中，跳过插件配置"
		return 0
	fi

	# 2) 添加 Marketplace
	add_marketplaces

	# 3) 安装 LSP 插件
	install_plugins "LSP " "${LSP_PLUGINS[@]}"

	# 4) 安装 Skill 插件
	install_plugins "Skill " "${SKILL_PLUGINS[@]}"

	_echo_blank
	print_success "Claude Code 配置完成"
}

main "$@"
