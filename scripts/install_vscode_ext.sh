#!/bin/bash
# VSCode/Cursor 插件批量安装脚本
# 远程服务器的插件通过 settings.json 的 remote.SSH.defaultExtensions 自动同步
set -e

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

# 通用插件（VSCode 和 Cursor 共用）
EXTENSIONS=(
	# 中文语言包
	"ms-ceintl.vscode-language-pack-zh-hans"
	# C/C++
	"ms-vscode.cmake-tools" "twxs.cmake" "xaver.clang-format" "vadimcn.vscode-lldb"
	# Rust
	"rust-lang.rust-analyzer" "serayuzgur.crates" "tamasfe.even-better-toml"
	# Go
	"golang.go"
	# Python
	"ms-python.python" "charliermarsh.ruff" "ms-python.debugpy"
	# Java/Kotlin
	"vscjava.vscode-java-pack" "fwcd.kotlin"
	# Lua
	"sumneko.lua"
	# Shell
	"mkhl.shfmt"
	# Markdown
	"yzhang.markdown-all-in-one" "bierner.markdown-mermaid" "DavidAnson.vscode-markdownlint"
	# Git
	"mhutchie.git-graph"
	# Docker
	"ms-azuretools.vscode-docker"
)

# 专属插件 (vscode:ext 或 cursor:ext)
SPECIFIC=(
	# VSCode 专属
	"vscode:ms-vscode.cpptools"
	"vscode:ms-vscode.cpptools-extension-pack"
	"vscode:ms-python.vscode-pylance"
	"vscode:ms-vscode-remote.remote-ssh"
	"vscode:ms-vscode-remote.remote-ssh-edit"
	"vscode:ms-vscode.remote-explorer"
	"vscode:ms-vscode-remote.remote-containers"
	# Cursor 专属
	"cursor:anysphere.cpptools"
	"cursor:anysphere.remote-ssh"
	"cursor:anysphere.remote-containers"
)

# 检测真实的编辑器类型（code 命令可能实际是 Cursor）
detect_real_type() {
	local cmd="$1"
	if "$cmd" --help 2>&1 | head -1 | grep -qi "cursor"; then
		echo "cursor"
	else
		echo "vscode"
	fi
}

# 检测编辑器
editors=()
if command -v code &>/dev/null; then
	real_type=$(detect_real_type "code")
	editors+=("$real_type:code")
fi
if command -v cursor &>/dev/null; then
	# 避免重复（如果 code 已经是 cursor）
	if [[ ! " ${editors[*]} " =~ "cursor:" ]]; then
		editors+=("cursor:cursor")
	fi
fi

if [[ ${#editors[@]} -eq 0 ]]; then
	print_error "未找到 VSCode 或 Cursor"
	exit 1
fi

print_info "检测到 ${#editors[@]} 个编辑器"

for entry in "${editors[@]}"; do
	type="${entry%%:*}" cmd="${entry#*:}"
	print_header ">>> $type (命令: $cmd)"

	# 获取已安装的插件（转小写比较）
	installed=$("$cmd" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

	# 收集要安装的插件：ext|tag (tag: common/vscode/cursor)
	all_exts=()
	for ext in "${EXTENSIONS[@]}"; do
		all_exts+=("$ext|common")
	done
	for item in "${SPECIFIC[@]}"; do
		t="${item%%:*}" e="${item#*:}"
		[[ "$t" == "$type" ]] && all_exts+=("$e|$t")
	done

	# 分类：已安装、待安装
	skipped=() to_install=()
	for item in "${all_exts[@]}"; do
		ext="${item%%|*}"
		ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
		if echo "$installed" | grep -Fxq "$ext_lower"; then
			skipped+=("$ext")
		else
			to_install+=("$item")
		fi
	done

	# 安装并记录结果
	success=() failed=()
	total=${#to_install[@]}
	count=0

	if [[ $total -gt 0 ]]; then
		for item in "${to_install[@]}"; do
			ext="${item%%|*}"
			tag="${item#*|}"
			((++count))
			printf "\r${CYAN}[%d/%d]${NC} 安装中: ${YELLOW}%s${NC}%-20s" "$count" "$total" "$ext" ""
			# 尝试安装
			"$cmd" --install-extension "$ext" --force &>/dev/null || true
			# 验证是否真的安装成功（重新检查）
			new_installed=$("$cmd" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
			ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
			if echo "$new_installed" | grep -Fxq "$ext_lower"; then
				success+=("$ext")
			else
				failed+=("$ext|$tag")
			fi
		done
		echo ""
	fi

	# 打印结果
	if [[ ${#skipped[@]} -gt 0 ]]; then
		print_warn "⊘ 已安装 (${#skipped[@]}):"
		for ext in "${skipped[@]}"; do echo -e "  ${YELLOW}⊘ $ext${NC}"; done
	fi
	if [[ ${#success[@]} -gt 0 ]]; then
		print_success "✓ 新安装 (${#success[@]}):"
		for ext in "${success[@]}"; do echo -e "  ${GREEN}✓ $ext${NC}"; done
	fi
	if [[ ${#failed[@]} -gt 0 ]]; then
		print_error "✗ 失败 (${#failed[@]}):"
		for item in "${failed[@]}"; do
			ext="${item%%|*}"
			tag="${item#*|}"
			if [[ "$tag" == "vscode" ]]; then
				echo -e "  ${RED}✗ $ext${NC} ${YELLOW}(VSCode 专属)${NC}"
			elif [[ "$tag" == "cursor" ]]; then
				echo -e "  ${RED}✗ $ext${NC} ${YELLOW}(Cursor 专属)${NC}"
			else
				echo -e "  ${RED}✗ $ext${NC}"
			fi
		done
	fi
	echo ""
done

print_success "=== 安装完成 ==="
