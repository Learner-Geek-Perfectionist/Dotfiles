#!/bin/bash
# VSCode 插件批量安装脚本

set -e

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

# ========================================
# VSCode 插件列表
# ========================================
extensions=(
	# ==================== C/C++ 开发 ====================
	"ms-vscode.cpptools"                # C/C++ IntelliSense
	"ms-vscode.cpptools-extension-pack" # C/C++ 扩展包
	"ms-vscode.cmake-tools"             # CMake 工具
	"twxs.cmake"                        # CMake 语法高亮
	"xaver.clang-format"                # Clang-Format

	# ==================== Rust ====================
	"rust-lang.rust-analyzer"  # Rust Analyzer
	"serayuzgur.crates"        # Crates 依赖管理
	"tamasfe.even-better-toml" # TOML 支持

	# ==================== Go ====================
	"golang.go" # Go 官方扩展

	# ==================== Python ====================
	"ms-python.python"          # Python 官方扩展
	"ms-python.vscode-pylance"  # Pylance
	"ms-python.black-formatter" # Black 格式化
	"ms-python.debugpy"         # Python 调试器

	# ==================== JavaScript/TypeScript ====================
	"dbaeumer.vscode-eslint" # ESLint
	"esbenp.prettier-vscode" # Prettier

	# ==================== Java/Kotlin ====================
	"vscjava.vscode-java-pack" # Java 扩展包
	"fwcd.kotlin"              # Kotlin 支持

	# ==================== Lua ====================
	"sumneko.lua" # Lua Language Server

	# ==================== Shell/Bash ====================
	"foxundermoon.shell-format" # Shell 格式化

	# ==================== Markdown ====================
	"yzhang.markdown-all-in-one"     # Markdown 增强
	"bierner.markdown-mermaid"       # Mermaid 图表支持
	"DavidAnson.vscode-markdownlint" # Markdown Lint

	# ==================== Git ====================
	"mhutchie.git-graph" # Git Graph

	# ==================== Docker/容器 ====================
	"ms-azuretools.vscode-docker"        # Docker
	"ms-vscode-remote.remote-containers" # Remote Containers

	# ==================== 远程开发 ====================
	"ms-vscode-remote.remote-ssh"      # Remote SSH
	"ms-vscode-remote.remote-ssh-edit" # Remote SSH 编辑
	"ms-vscode.remote-explorer"        # Remote Explorer

	# ==================== 工具类 ====================
	"EditorConfig.EditorConfig"             # EditorConfig
	"streetsidesoftware.code-spell-checker" # 拼写检查
	"wayou.vscode-todo-highlight"           # TODO 高亮
	"Gruntfuggly.todo-tree"                 # TODO Tree
	"aaron-bond.better-comments"            # 更好的注释
	"usernamehw.errorlens"                  # Error Lens
	"christian-kohler.path-intellisense"    # 路径智能提示

	# ==================== YAML/JSON ====================
	"redhat.vscode-yaml" # YAML 支持
	"ZainChen.json"      # JSON 支持
)

# ========================================
# 检测 code 命令
# ========================================
detect_code_command() {
	# 检查 code 命令
	if command -v code >/dev/null 2>&1; then
		echo "code"
		return 0
	fi

	# 检查 code-insiders 命令
	if command -v code-insiders >/dev/null 2>&1; then
		echo "code-insiders"
		return 0
	fi

	# macOS 上的路径
	if [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
		echo "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
		return 0
	fi

	# Cursor IDE
	if command -v cursor >/dev/null 2>&1; then
		echo "cursor"
		return 0
	fi

	return 1
}

# ========================================
# 获取已安装的插件列表
# ========================================
get_installed_extensions() {
	local code_cmd="$1"
	"$code_cmd" --list-extensions 2>/dev/null || true
}

# ========================================
# 安装单个插件
# ========================================
install_extension() {
	local code_cmd="$1"
	local ext="$2"

	if "$code_cmd" --install-extension "$ext" --force 2>/dev/null; then
		print_success "  ✓ $ext"
		return 0
	else
		print_error "  ✗ $ext"
		return 1
	fi
}

# ========================================
# 批量安装插件
# ========================================
install_all_extensions() {
	local code_cmd="$1"
	local installed_count=0
	local failed_count=0
	local skipped_count=0

	# 获取已安装的插件
	local installed_list
	installed_list=$(get_installed_extensions "$code_cmd" | tr '[:upper:]' '[:lower:]')

	print_info "开始安装 VSCode 插件..."
	print_info "共 ${#extensions[@]} 个插件待处理"
	print_info ""

	for ext in "${extensions[@]}"; do
		local ext_lower
		ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

        # 检查是否已安装
		if echo "$installed_list" | grep -Fxq "$ext_lower"; then
			print_warn "  ⊘ $ext (已安装)"
			((skipped_count++))
			continue
		fi

		if install_extension "$code_cmd" "$ext"; then
			((installed_count++))
		else
			((failed_count++))
		fi
	done

	print_info ""
	print_info "=========================================="
	print_success "安装完成: $installed_count"
	print_warn "已跳过: $skipped_count"
	if [[ $failed_count -gt 0 ]]; then
		print_error "失败: $failed_count"
	fi
	print_info "=========================================="
}

# ========================================
# 显示使用帮助
# ========================================
show_help() {
	cat <<HELP_EOF
VSCode 插件批量安装脚本

用法: $0 [选项]

选项:
    --list          列出所有将要安装的插件
    --code CMD      指定 code 命令路径（默认自动检测）
    --help          显示帮助信息

示例:
    # 自动检测 VSCode 并安装
    $0

    # 指定 code 命令
    $0 --code /usr/bin/code

    # 列出插件
    $0 --list
HELP_EOF
}

# ========================================
# 列出所有插件
# ========================================
list_extensions() {
	print_info "将要安装的插件列表:"
	print_info ""

	for ext in "${extensions[@]}"; do
		echo "  - $ext"
	done

	print_info ""
	print_info "共 ${#extensions[@]} 个插件"
}

# ========================================
# 主函数
# ========================================
main() {
	local code_cmd=""
	local action="install"

	# 解析参数
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--list)
			action="list"
			shift
			;;
		--code)
			code_cmd="$2"
			shift 2
			;;
            --help|-h)
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

	# 检测 code 命令
	if [[ -z "$code_cmd" ]]; then
		if ! code_cmd=$(detect_code_command); then
			print_error "未找到 VSCode/Cursor，请确保已安装并在 PATH 中"
			print_info "或使用 --code 参数指定路径"
			exit 1
		fi
	fi

	print_info "=========================================="
	print_info "VSCode 插件安装脚本"
	print_info "=========================================="
	print_info "使用命令: $code_cmd"
	print_info "=========================================="
	print_info ""

	# 验证 code 命令
	if ! "$code_cmd" --version >/dev/null 2>&1; then
		print_error "无法执行 code 命令: $code_cmd"
		exit 1
	fi

	# 安装插件
	install_all_extensions "$code_cmd"
}

main "$@"
