#!/bin/bash
# macOS 安装脚本 - 使用 Homebrew

set -e

# ========================================
# 路径检测
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LIB_DIR="$DOTFILES_DIR/lib"

# 加载工具函数和包定义
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/packages.sh"

# ========================================
# 开始安装
# ========================================
print_header "=========================================="
print_header "macOS 安装脚本"
print_header "=========================================="

# 1. 检查 Xcode Command Line Tools
print_info "检查 Xcode Command Line Tools..."

if ! xcode-select --version &>/dev/null; then
    print_warn "Xcode Command Line Tools 未安装"
    print_info "正在安装..."
    xcode-select --install 2>/dev/null || true
    print_error "请在弹出的对话框中点击 '安装'，安装完成后重新运行此脚本"
    exit 1
fi

print_success "✓ Xcode Command Line Tools 已安装"

# 重置 Xcode 路径
sudo xcode-select --reset 2>/dev/null || true

# 2. 检查/安装 Homebrew
print_info "检查 Homebrew..."

if command -v brew >/dev/null 2>&1; then
    print_success "✓ Homebrew 已安装"
else
    print_info "安装 Homebrew..."
    
    # 使用官方安装器
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # 配置 PATH
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    print_success "✓ Homebrew 安装完成"
fi

echo ""
print_warn "提示: 建议开启代理以加速 Homebrew 下载"
echo ""

# 3. 安装 CLI 工具
print_info "安装 CLI 工具..."
install_packages "brew_formulas" "formula"
print_success "✓ CLI 工具安装完成"

# 4. 安装 GUI 应用
print_info "安装 GUI 应用..."

# 添加第三方 tap
brew tap mihomo-party-org/mihomo-party 2>/dev/null || true

install_packages "brew_casks" "cask"
print_success "✓ GUI 应用安装完成"

# 5. 清理 Homebrew 缓存
print_info "清理 Homebrew 缓存..."
brew cleanup --prune=all 2>/dev/null || true

# 6. 配置网络抓包工具权限
print_info "配置网络工具权限..."

if dscl . -read /Groups/access_bpf &>/dev/null; then
    if ! dscl . -read /Groups/access_bpf GroupMembership 2>/dev/null | grep -qw "$(whoami)"; then
        print_info "添加用户到 access_bpf 组..."
        sudo dseditgroup -o edit -a "$(whoami)" -t user access_bpf
        print_success "✓ 网络工具权限配置完成（重启后生效）"
    else
        print_success "✓ 用户已在 access_bpf 组"
    fi
else
    print_warn "access_bpf 组不存在，请先安装 Wireshark"
fi

# ========================================
# 完成
# ========================================
echo ""
print_success "=========================================="
print_success "macOS 安装完成！"
print_success "=========================================="
