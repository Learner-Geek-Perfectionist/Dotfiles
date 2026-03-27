#!/bin/bash
# macOS 安装脚本 - 使用 Homebrew

set -eo pipefail

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
	xcode-select --install 2>/dev/null
	print_error "请在弹出的对话框中点击 '安装'，安装完成后重新运行此脚本"
	exit 1
fi

print_success "Xcode Command Line Tools 已安装"

# 重置 Xcode 路径
sudo xcode-select --reset 2>/dev/null

# 2. 检查/安装 Homebrew
print_info "检查 Homebrew..."

if command -v brew >/dev/null 2>&1; then
	print_success "Homebrew 已安装"
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

	print_success "Homebrew 安装完成"
fi

_echo_blank
print_warn "提示: 建议开启代理以加速 Homebrew 下载"
_echo_blank

# 3. 安装 CLI 工具
print_info "检查 CLI 工具..."

installed_formulas=$(brew list --formula -1 2>/dev/null)
missing_formulas=()
for formula in "${brew_formulas[@]}"; do
	if ! grep -qix "$formula" <<< "$installed_formulas"; then
		# 二次检查：处理别名/重命名（如 python→python@3.x, pkg-config→pkgconf）
		brew ls --versions "$formula" &>/dev/null || missing_formulas+=("$formula")
	fi
done

if (( ${#missing_formulas[@]} == 0 )); then
	print_success "所有 CLI 工具已安装，跳过"
else
	print_info "安装 ${#missing_formulas[@]} 个缺失的 CLI 工具: ${missing_formulas[*]}"
	brew install "${missing_formulas[@]}"
	print_success "CLI 工具安装完成"
fi

# 4. 安装 GUI 应用
print_info "检查 GUI 应用..."

# 添加第三方 tap（已 tap 则跳过 git fetch）
brew tap | grep -q "mihomo-party-org/mihomo-party" || brew tap mihomo-party-org/mihomo-party

# 一次性获取已安装列表，本地比对找出缺失项
installed_casks=$(brew list --cask -1 2>/dev/null)
missing_casks=()
for cask in "${brew_casks[@]}"; do
	grep -qix "$cask" <<< "$installed_casks" || missing_casks+=("$cask")
done

if (( ${#missing_casks[@]} == 0 )); then
	print_success "所有 GUI 应用已安装，跳过"
else
	print_info "安装 ${#missing_casks[@]} 个缺失的 GUI 应用: ${missing_casks[*]}"
	brew install --cask "${missing_casks[@]}"
	print_success "GUI 应用安装完成"
fi

# 5. 配置 Homebrew 自动更新
print_info "配置 Homebrew 自动更新..."

brew tap | grep -q "homebrew/autoupdate" || brew tap homebrew/autoupdate
if brew autoupdate status 2>/dev/null | grep -q "running"; then
	print_success "Homebrew autoupdate 已在运行，跳过"
else
	brew autoupdate start 3600 --upgrade --greedy --cleanup
	print_success "Homebrew autoupdate 已配置（每 1 小时自动更新）"
fi

# 6. 清理 Homebrew 缓存
print_info "清理 Homebrew 缓存..."
brew cleanup --prune=all

# 7. 配置电源管理（合盖不睡眠，保持 SSH 连接）
print_info "配置电源管理..."

current_sleep=$(pmset -g | awk '/^ sleep/ {print $2}')
if [[ "$current_sleep" == "0" ]]; then
	print_success "sleep 已设为 0，跳过"
else
	sudo pmset -a sleep 0
	sudo pmset -a tcpkeepalive 1
	print_success "电源管理已配置（合盖不睡眠，TCP 保活开启）"
fi

# 8. 配置网络抓包工具权限
print_info "配置网络工具权限..."

if dscl . -read /Groups/access_bpf &>/dev/null; then
	if ! dscl . -read /Groups/access_bpf GroupMembership 2>/dev/null | grep -qw "$(whoami)"; then
		print_info "添加用户到 access_bpf 组..."
		sudo dseditgroup -o edit -a "$(whoami)" -t user access_bpf
		print_success "网络工具权限配置完成（重启后生效）"
	else
		print_success "用户已在 access_bpf 组"
	fi
else
	print_warn "access_bpf 组不存在，请先安装 Wireshark"
fi

# ========================================
# 完成
# ========================================
_echo_blank
print_success "=========================================="
print_success "macOS 安装完成！"
print_success "=========================================="
