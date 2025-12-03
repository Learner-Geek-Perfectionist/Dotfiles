#!/bin/bash
# VSCode/Cursor 插件批量安装脚本
# 如果两个编辑器都存在，会同时为两者安装插件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

# ========================================
# 通用插件（VSCode 和 Cursor 都支持）
# ========================================
COMMON_EXTENSIONS=(
	# ==================== C/C++ ====================
	"ms-vscode.cmake-tools"
	"twxs.cmake"
	"xaver.clang-format"

	# ==================== Rust ====================
	"rust-lang.rust-analyzer"
	"serayuzgur.crates"
	"tamasfe.even-better-toml"

	# ==================== Go ====================
	"golang.go"

	# ==================== Python ====================
	"ms-python.python"
	"ms-python.vscode-pylance"
	"charliermarsh.ruff"
	"ms-python.debugpy"

	# ==================== JavaScript/TypeScript ====================
	"dbaeumer.vscode-eslint"
	"esbenp.prettier-vscode"

	# ==================== Java/Kotlin ====================
	"vscjava.vscode-java-pack"
	"fwcd.kotlin"

	# ==================== Lua ====================
	"sumneko.lua"

	# ==================== Shell/Bash ====================
	"foxundermoon.shell-format"

	# ==================== Markdown ====================
	"yzhang.markdown-all-in-one"
	"bierner.markdown-mermaid"
	"DavidAnson.vscode-markdownlint"

	# ==================== Git ====================
	"mhutchie.git-graph"

	# ==================== Docker ====================
	"ms-azuretools.vscode-docker"

	# ==================== 工具类 ====================
	"EditorConfig.EditorConfig"
	"streetsidesoftware.code-spell-checker"
	"wayou.vscode-todo-highlight"
	"Gruntfuggly.todo-tree"
	"aaron-bond.better-comments"
	"usernamehw.errorlens"
	"christian-kohler.path-intellisense"

	# ==================== YAML/JSON ====================
	"redhat.vscode-yaml"
	"ZainChen.json"
)

# ========================================
# VSCode 专属插件
# ========================================
VSCODE_ONLY=(
	"ms-vscode.cpptools"
	"ms-vscode.cpptools-extension-pack"
	"ms-vscode-remote.remote-ssh"
	"ms-vscode-remote.remote-ssh-edit"
	"ms-vscode.remote-explorer"
	"ms-vscode-remote.remote-containers"
)

# ========================================
# Cursor 专属插件（替代 VSCode 专属的）
# ========================================
CURSOR_ONLY=(
	"anysphere.cpptools"
	"jeanp413.open-remote-ssh"
)

# ========================================
# 检测所有可用的编辑器
# 返回格式: type:command (每行一个)
# ========================================
detect_editors() {
	local -A seen=()

	add_editor() {
		local type="$1" cmd="$2"
		[[ -z "$cmd" ]] && return
		# 用 realpath 去重（避免同一个编辑器被检测多次）
		local real_cmd
		real_cmd=$(command -v "$cmd" 2>/dev/null || echo "$cmd")
		[[ -n "${seen[$real_cmd]}" ]] && return
		seen[$real_cmd]=1
		echo "$type:$cmd"
	}

	# macOS GUI 安装路径
	[[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]] &&
		add_editor "vscode" "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

	[[ -x "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]] &&
		add_editor "cursor" "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"

	# PATH 中的命令
	command -v code >/dev/null 2>&1 && add_editor "vscode" "code"
	command -v code-insiders >/dev/null 2>&1 && add_editor "vscode" "code-insiders"
	command -v cursor >/dev/null 2>&1 && add_editor "cursor" "cursor"
}

# ========================================
# 安装插件
# ========================================
install_extensions() {
	local cmd="$1"
	shift
	local -a exts=("$@")

	local installed
	installed=$("$cmd" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

	local installed_count=0 skipped_count=0 failed_count=0

	for ext in "${exts[@]}"; do
		local ext_lower
		ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

		if echo "$installed" | grep -Fxq "$ext_lower"; then
			print_warn "  ⊘ $ext (已安装)"
			((skipped_count++))
		elif "$cmd" --install-extension "$ext" --force >/dev/null 2>&1; then
			print_success "  ✓ $ext"
			((installed_count++))
		else
			print_error "  ✗ $ext"
			((failed_count++))
		fi
	done

	echo ""
	print_info "新安装: $installed_count | 已跳过: $skipped_count | 失败: $failed_count"
}

# ========================================
# 为单个编辑器安装所有插件
# ========================================
install_for_editor() {
	local type="$1"
	local cmd="$2"

	print_info "=========================================="
	print_info "编辑器: $type"
	print_info "命令: $cmd"
	print_info "=========================================="

	# 检查命令是否可用
	if ! "$cmd" --version >/dev/null 2>&1; then
		print_error "无法执行命令: $cmd，跳过"
		return 1
	fi

	# 通用插件
	print_info ""
	print_info ">> 安装通用插件 (${#COMMON_EXTENSIONS[@]} 个)"
	install_extensions "$cmd" "${COMMON_EXTENSIONS[@]}"

	# 专属插件
	if [[ "$type" == "vscode" ]]; then
		print_info ""
		print_info ">> 安装 VSCode 专属插件 (${#VSCODE_ONLY[@]} 个)"
		install_extensions "$cmd" "${VSCODE_ONLY[@]}"
	else
		print_info ""
		print_info ">> 安装 Cursor 专属插件 (${#CURSOR_ONLY[@]} 个)"
		install_extensions "$cmd" "${CURSOR_ONLY[@]}"
	fi

	print_info ""
}

# ========================================
# 列出所有插件
# ========================================
list_extensions() {
	print_info "通用插件 (${#COMMON_EXTENSIONS[@]} 个):"
	for ext in "${COMMON_EXTENSIONS[@]}"; do
		echo "  - $ext"
	done

	print_info ""
	print_info "VSCode 专属插件 (${#VSCODE_ONLY[@]} 个):"
	for ext in "${VSCODE_ONLY[@]}"; do
		echo "  - $ext"
	done

	print_info ""
	print_info "Cursor 专属插件 (${#CURSOR_ONLY[@]} 个):"
	for ext in "${CURSOR_ONLY[@]}"; do
		echo "  - $ext"
	done
}

# ========================================
# 显示帮助
# ========================================
show_help() {
	cat <<EOF
VSCode/Cursor 插件批量安装脚本

用法: $0 [选项]

选项:
    --list          列出所有将要安装的插件
    --code CMD      指定编辑器命令（可多次使用）
    --help          显示帮助信息

说明:
    - 自动检测系统中的 VSCode 和 Cursor
    - 如果两个编辑器都存在，会同时为两者安装插件
    - 通用插件会安装到所有编辑器
    - 专属插件只安装到对应的编辑器

示例:
    $0                    # 自动检测并安装
    $0 --list             # 列出所有插件
    $0 --code cursor      # 只为 cursor 安装
EOF
}

# ========================================
# 主函数
# ========================================
main() {
	local -a manual_cmds=()
	local action="install"

	# 解析参数
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--list)
			action="list"
			shift
			;;
		--code)
			manual_cmds+=("$2")
			shift 2
			;;
		--help | -h)
			show_help
			exit 0
			;;
		*)
			print_error "未知参数: $1"
			show_help
			exit 1
			;;
		esac
	done

	# 列出插件
	if [[ "$action" == "list" ]]; then
		list_extensions
		exit 0
	fi

	# 检测或使用手动指定的编辑器
	local -a editors=()
	if [[ ${#manual_cmds[@]} -gt 0 ]]; then
		for cmd in "${manual_cmds[@]}"; do
			# 根据命令名判断类型
			if [[ "$cmd" == *cursor* ]]; then
				editors+=("cursor:$cmd")
			else
				editors+=("vscode:$cmd")
			fi
		done
	else
		mapfile -t editors < <(detect_editors)
	fi

	if [[ ${#editors[@]} -eq 0 ]]; then
		print_error "未找到 VSCode 或 Cursor"
		print_info "请确保已安装，或使用 --code 参数指定路径"
		exit 1
	fi

	print_info "检测到 ${#editors[@]} 个编辑器，将依次安装插件"
	print_info ""

	# 为每个编辑器安装插件
	for entry in "${editors[@]}"; do
		local type="${entry%%:*}"
		local cmd="${entry#*:}"
		install_for_editor "$type" "$cmd"
	done

	print_success "=========================================="
	print_success "所有编辑器的插件安装完成！"
	print_success "=========================================="
}

main "$@"
