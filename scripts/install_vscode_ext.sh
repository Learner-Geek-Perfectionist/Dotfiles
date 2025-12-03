#!/bin/bash
# VSCode/Cursor 插件批量安装脚本
set -e

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

# 通用插件
EXTENSIONS=(
	# C/C++
	"ms-vscode.cmake-tools" "twxs.cmake" "xaver.clang-format"
	# Rust
	"rust-lang.rust-analyzer" "serayuzgur.crates" "tamasfe.even-better-toml"
	# Go
	"golang.go"
	# Python
	"ms-python.python" "ms-python.vscode-pylance" "charliermarsh.ruff" "ms-python.debugpy"
	# JavaScript/TypeScript
	"dbaeumer.vscode-eslint" "esbenp.prettier-vscode"
	# Java/Kotlin
	"vscjava.vscode-java-pack" "fwcd.kotlin"
	# Lua
	"sumneko.lua"
	# Shell
	"foxundermoon.shell-format"
	# Markdown
	"yzhang.markdown-all-in-one" "bierner.markdown-mermaid" "DavidAnson.vscode-markdownlint"
	# Git
	"mhutchie.git-graph"
	# Docker
	"ms-azuretools.vscode-docker"
	# 工具
	"EditorConfig.EditorConfig" "streetsidesoftware.code-spell-checker"
	"wayou.vscode-todo-highlight" "Gruntfuggly.todo-tree" "aaron-bond.better-comments"
	"usernamehw.errorlens" "christian-kohler.path-intellisense"
	# YAML/JSON
	"redhat.vscode-yaml" "ZainChen.json"
)

# 专属插件 (vscode:ext 或 cursor:ext)
SPECIFIC=(
	"vscode:ms-vscode.cpptools"
	"vscode:ms-vscode.cpptools-extension-pack"
	"vscode:ms-vscode-remote.remote-ssh"
	"vscode:ms-vscode-remote.remote-ssh-edit"
	"vscode:ms-vscode.remote-explorer"
	"vscode:ms-vscode-remote.remote-containers"
	"cursor:anysphere.cpptools"
	"cursor:jeanp413.open-remote-ssh"
)

# 检测编辑器
editors=()
command -v code &>/dev/null && editors+=("vscode:code")
command -v cursor &>/dev/null && editors+=("cursor:cursor")

if [[ ${#editors[@]} -eq 0 ]]; then
	print_error "未找到 VSCode 或 Cursor"
	exit 1
fi

print_info "检测到 ${#editors[@]} 个编辑器"

for entry in "${editors[@]}"; do
	type="${entry%%:*}" cmd="${entry#*:}"
	print_header ">>> $type"

	# 通用插件
	for ext in "${EXTENSIONS[@]}"; do
		if "$cmd" --install-extension "$ext" --force &>/dev/null; then
			print_success "  ✓ $ext"
		else
			print_error "  ✗ $ext"
		fi
	done

	# 专属插件
	for item in "${SPECIFIC[@]}"; do
		t="${item%%:*}" e="${item#*:}"
		if [[ "$t" == "$type" ]]; then
			if "$cmd" --install-extension "$e" --force &>/dev/null; then
				print_success "  ✓ $e"
			else
				print_error "  ✗ $e"
			fi
		fi
	done
done

print_success "=== 安装完成 ==="
