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

	# 收集要安装的插件
	all_exts=("${EXTENSIONS[@]}")
	for item in "${SPECIFIC[@]}"; do
		t="${item%%:*}" e="${item#*:}"
		[[ "$t" == "$type" ]] && all_exts+=("$e")
	done

	# 安装并记录结果
	success=() failed=()
	total=${#all_exts[@]}
	count=0

	for ext in "${all_exts[@]}"; do
		((++count))
		printf "\r${CYAN}[%d/%d]${NC} 安装中: ${YELLOW}%s${NC}%-20s" "$count" "$total" "$ext" ""
		if "$cmd" --install-extension "$ext" --force &>/dev/null; then
			success+=("$ext")
		else
			failed+=("$ext")
		fi
	done
	echo ""

	# 打印结果
	if [[ ${#success[@]} -gt 0 ]]; then
		print_success "✓ 成功 (${#success[@]}):"
		for ext in "${success[@]}"; do echo -e "  ${GREEN}✓ $ext${NC}"; done
	fi
	if [[ ${#failed[@]} -gt 0 ]]; then
		print_error "✗ 失败 (${#failed[@]}):"
		for ext in "${failed[@]}"; do echo -e "  ${RED}✗ $ext${NC}"; done
	fi
	echo ""
done

print_success "=== 安装完成 ==="
