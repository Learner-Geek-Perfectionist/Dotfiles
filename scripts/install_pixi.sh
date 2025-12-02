#!/bin/bash
# Pixi 安装脚本
# 基于 conda-forge 的现代包管理器
# 完全 Rootless，支持 x86_64 和 arm64
#
# 文档: https://pixi.sh/

set -e

# ========================================
# 加载工具函数
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../lib/utils.sh" ]]; then
    source "$SCRIPT_DIR/../lib/utils.sh"
else
    # 内置打印函数（独立运行时）
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    print_info() { echo -e "${CYAN}$1${NC}"; }
    print_success() { echo -e "${GREEN}$1${NC}"; }
    print_warn() { echo -e "${YELLOW}$1${NC}"; }
    print_error() { echo -e "${RED}$1${NC}"; }
    print_header() { echo -e "${BLUE}$1${NC}"; }
fi

# ========================================
# 配置
# ========================================
PIXI_HOME="${PIXI_HOME:-$HOME/.pixi}"
PIXI_BIN="$PIXI_HOME/bin/pixi"

# ========================================
# 检查 Pixi 是否已安装
# ========================================
check_pixi_installed() {
    if command -v pixi &>/dev/null; then
        local version
        version=$(pixi --version 2>/dev/null)
        print_info "Pixi 已安装: $version"
        return 0
    fi
    return 1
}

# ========================================
# 安装 Pixi
# ========================================
install_pixi() {
    print_header "=========================================="
    print_header "🦀 安装 Pixi (现代包管理器)"
    print_header "=========================================="

    print_info "安装目录: $PIXI_HOME"
    echo ""

    # 检查是否已安装
    if check_pixi_installed; then
        print_warn "Pixi 已安装，跳过安装步骤"
        return 0
    fi

    # 使用官方安装脚本
    print_info "下载并安装 Pixi..."

    if curl -fsSL https://pixi.sh/install.sh | bash; then
        print_success "✓ Pixi 安装成功"
    else
        print_error "Pixi 安装失败"
        exit 1
    fi

    # 验证安装
    export PATH="$PIXI_HOME/bin:$PATH"
    if command -v pixi &>/dev/null; then
        print_success "✓ Pixi 已可用: $(pixi --version)"
    else
        print_error "Pixi 安装验证失败"
        exit 1
    fi
}

# ========================================
# 配置 Shell 集成
# ========================================
setup_shell_integration() {
    print_header "=========================================="
    print_header "配置 Shell 集成"
    print_header "=========================================="

    local shell_name
    shell_name=$(basename "$SHELL")

    # PATH 配置
    local path_export='export PATH="$HOME/.pixi/bin:$PATH"'

    case "$shell_name" in
    zsh)
        local zshrc="$HOME/.zshrc"
        touch "$zshrc"

        # 添加 PATH（如果不存在）
        if ! grep -q '\.pixi/bin' "$zshrc" 2>/dev/null; then
            echo "" >>"$zshrc"
            echo "# Pixi: 添加到 PATH" >>"$zshrc"
            echo "$path_export" >>"$zshrc"
            print_success "✓ 已添加 Pixi PATH 到 .zshrc"
        else
            print_warn "Pixi PATH 已存在于 .zshrc"
        fi
        ;;
    bash)
        local bashrc="$HOME/.bashrc"
        touch "$bashrc"

        if ! grep -q '\.pixi/bin' "$bashrc" 2>/dev/null; then
            echo "" >>"$bashrc"
            echo "# Pixi: 添加到 PATH" >>"$bashrc"
            echo "$path_export" >>"$bashrc"
            print_success "✓ 已添加 Pixi PATH 到 .bashrc"
        else
            print_warn "Pixi PATH 已存在于 .bashrc"
        fi
        ;;
    *)
        print_warn "未知 Shell: $shell_name"
        print_info "请手动添加以下内容到你的 shell 配置文件:"
        print_info "  $path_export"
        ;;
    esac
}

# ========================================
# 安装全局工具包
# ========================================
install_global_tools() {
    print_header "=========================================="
    print_header "安装全局工具包"
    print_header "=========================================="

    export PATH="$PIXI_HOME/bin:$PATH"

    if ! command -v pixi &>/dev/null; then
        print_error "Pixi 未找到，无法安装工具包"
        return 1
    fi

    # 定义要安装的工具
    local tools=(
        # 构建工具 (完全 Rootless!)
        "make"
        "cmake"
        "ninja"
        "pkg-config"
        "cxx-compiler"
        "c-compiler"
        
        # 编程语言
        "python"
        "nodejs"
        "go"
        "ruby"
        "lua"
        "rust"
        "openjdk"
        
        # 终端增强
        "ripgrep"
        "fd-find"
        "bat"
        "eza"
        "fzf"
        "dust"
        "hyperfine"
        
        # 开发工具
        "neovim"
        "jq"
        "yq"
        
        # 代码格式化
        "shfmt"
        "ruff"
        
        # 其他
        "starship"
        "glow"
        "fastfetch"
        "chezmoi"
    )

    print_info "安装 ${#tools[@]} 个工具包..."
    print_info "（这可能需要几分钟，所有包都是预编译的）"
    echo ""

    local failed=()
    for tool in "${tools[@]}"; do
        echo -n "  Installing $tool... "
        if pixi global install "$tool" 2>/dev/null; then
            echo "✓"
        else
            echo "✗"
            failed+=("$tool")
        fi
    done

    echo ""
    if ((${#failed[@]} > 0)); then
        print_warn "以下工具安装失败: ${failed[*]}"
        print_info "可以稍后手动安装: pixi global install <tool>"
    fi

    print_success "✓ 工具包安装完成"
}

# ========================================
# 显示帮助
# ========================================
show_help() {
    cat <<HELP_EOF
Pixi 安装脚本

用法: $0 [选项]

选项:
    --install-only      仅安装 pixi，不安装工具包
    --tools-only        仅安装工具包（假设 pixi 已安装）
    --shell-only        仅配置 shell 集成
    --help, -h          显示帮助信息

环境变量:
    PIXI_HOME           Pixi 安装目录 (默认: ~/.pixi)

示例:
    # 完整安装
    $0

    # 仅安装 pixi
    $0 --install-only

常用 pixi 命令:
    pixi global install <pkg>  - 全局安装包
    pixi global list           - 列出已安装的包
    pixi global upgrade        - 升级所有包
    pixi global remove <pkg>   - 移除包
HELP_EOF
}

# ========================================
# 主函数
# ========================================
main() {
    local action="full"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --install-only)
            action="install"
            shift
            ;;
        --tools-only)
            action="tools"
            shift
            ;;
        --shell-only)
            action="shell"
            shift
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

    case "$action" in
    full)
        install_pixi
        setup_shell_integration
        install_global_tools
        ;;
    install)
        install_pixi
        ;;
    tools)
        install_global_tools
        ;;
    shell)
        setup_shell_integration
        ;;
    esac

    echo ""
    print_success "=========================================="
    print_success "✅ Pixi 设置完成！"
    print_success "=========================================="
    echo ""
    print_info "下一步:"
    print_info "  1. 重新打开终端，或运行: source ~/.zshrc"
    print_info "  2. 验证安装: pixi global list"
    echo ""
    print_info "常用命令:"
    print_info "  pixi global install <pkg>  - 安装包"
    print_info "  pixi global list           - 列出已安装包"
    print_info "  pixi global upgrade        - 升级所有包"
    echo ""
}

main "$@"

