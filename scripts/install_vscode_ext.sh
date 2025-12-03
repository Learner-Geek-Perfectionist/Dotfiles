#!/bin/bash
# VSCode/Cursor 插件批量安装脚本
set -e

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

# 通用插件
EXTENSIONS=(
	"ms-vscode.cmake-tools" "twxs.cmake" "xaver.clang-format" "vadimcn.vscode-lldb"
	"rust-lang.rust-analyzer" "serayuzgur.crates" "tamasfe.even-better-toml"
	"golang.go"
	"ms-python.python" "ms-python.vscode-pylance" "charliermarsh.ruff" "ms-python.debugpy"
	"vscjava.vscode-java-pack" "fwcd.kotlin"
	"sumneko.lua"
	"mkhl.shfmt"
	"yzhang.markdown-all-in-one" "bierner.markdown-mermaid" "DavidAnson.vscode-markdownlint"
	"mhutchie.git-graph"
	"ms-azuretools.vscode-docker"
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

	# 构建参数：--install-extension ext1 --install-extension ext2 ...
	args=()
	for ext in "${EXTENSIONS[@]}"; do
		args+=(--install-extension "$ext")
	done
	for item in "${SPECIFIC[@]}"; do
		t="${item%%:*}" e="${item#*:}"
		[[ "$t" == "$type" ]] && args+=(--install-extension "$e")
	done

	# 一条命令安装所有插件
	print_info "安装 $((${#args[@]} / 2)) 个插件..."
	if "$cmd" "${args[@]}" --force; then
		print_success "✓ 全部安装完成"
	else
		print_error "✗ 部分插件安装失败"
	fi
done

print_success "=== 安装完成 ==="
