#!/bin/bash
# macOS 安装脚本 - 使用 Homebrew

set -euo pipefail

# ========================================
# 路径检测
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LIB_DIR="$DOTFILES_DIR/lib"

# 加载工具函数和包定义
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/packages.sh"

# 确保 brew tap 已添加（已 tap 则跳过）
ensure_brew_tap() {
	brew tap | grep -q "$1" || brew tap "$1"
}

brew_cleanup_launchagent_path() {
	echo "$HOME/Library/LaunchAgents/com.dotfiles.brew-cleanup.plist"
}

brew_maintenance_support_dir() {
	echo "$HOME/Library/Application Support/com.dotfiles"
}

brew_maintenance_script_path() {
	echo "$(brew_maintenance_support_dir)/brew-maintenance.sh"
}

brew_maintenance_launchagent_path() {
	echo "$HOME/Library/LaunchAgents/com.dotfiles.brew-maintenance.plist"
}

legacy_brew_autoupdate_launchagent_path() {
	echo "$HOME/Library/LaunchAgents/com.github.domt4.homebrew-autoupdate.plist"
}

remove_launchagent_plist() {
	local plist="$1"

	if [[ ! -f "$plist" ]]; then
		return 1
	fi

	if command -v launchctl &>/dev/null; then
		launchctl unload "$plist" &>/dev/null || true
	fi

	rm -f "$plist"
}

disable_legacy_brew_automation() {
	local legacy_cleanup_plist legacy_autoupdate_plist
	legacy_cleanup_plist="$(brew_cleanup_launchagent_path)"
	legacy_autoupdate_plist="$(legacy_brew_autoupdate_launchagent_path)"

	if [[ -f "$legacy_autoupdate_plist" ]] && command -v brew &>/dev/null &&
		brew commands 2>/dev/null | grep -q '^autoupdate$'; then
		if brew autoupdate delete &>/dev/null; then
			print_dim "✓ 已移除旧版 Homebrew autoupdate 配置"
		else
			print_warn "brew autoupdate delete 失败，继续手动移除旧版 Homebrew autoupdate LaunchAgent"
		fi
	fi

	if remove_launchagent_plist "$legacy_autoupdate_plist"; then
		print_dim "✓ 已移除旧版 Homebrew autoupdate LaunchAgent"
	fi

	if remove_launchagent_plist "$legacy_cleanup_plist"; then
		print_dim "✓ 已移除旧版 Homebrew cleanup LaunchAgent"
	fi
}

configure_brew_maintenance_launchagent() {
	local plist script support_dir tmp_plist tmp_script brew_bin
	plist="$(brew_maintenance_launchagent_path)"
	script="$(brew_maintenance_script_path)"
	support_dir="$(brew_maintenance_support_dir)"
	brew_bin="$(command -v brew)"

	if [[ -z "$brew_bin" ]]; then
		print_warn "未找到 brew，跳过 Homebrew 自动维护定时任务"
		return 1
	fi

	disable_legacy_brew_automation

	tmp_script="$(mktemp)"
	mkdir -p "$(dirname "$plist")" "$support_dir" "$HOME/Library/Logs"
	cat >"$tmp_script" <<EOF
#!/bin/bash
set -uo pipefail

status=0

run_step() {
	"\$@"
	local rc=\$?
	if [[ \$rc -ne 0 && \$status -eq 0 ]]; then
		status=\$rc
	fi
	return \$rc
}

echo "==> \$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"

if run_step "${brew_bin}" update; then
	run_step "${brew_bin}" upgrade --formula -v
	run_step "${brew_bin}" upgrade --cask -v --greedy
fi

run_step "${brew_bin}" cleanup --prune=all

exit "\$status"
EOF

	if [[ -f "$script" ]] && cmp -s "$script" "$tmp_script"; then
		rm -f "$tmp_script"
	else
		mv "$tmp_script" "$script"
	fi
	chmod 755 "$script"

	tmp_plist="$(mktemp)"
	cat >"$tmp_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.dotfiles.brew-maintenance</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>${script}</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>3600</integer>
	<key>StandardOutPath</key>
	<string>${HOME}/Library/Logs/com.dotfiles.brew-maintenance.log</string>
	<key>StandardErrorPath</key>
	<string>${HOME}/Library/Logs/com.dotfiles.brew-maintenance.err.log</string>
</dict>
</plist>
EOF

	if [[ -f "$plist" ]] && cmp -s "$plist" "$tmp_plist"; then
		rm -f "$tmp_plist"
	else
		mv "$tmp_plist" "$plist"
	fi

	chmod 644 "$plist"

	if command -v launchctl &>/dev/null; then
		launchctl unload "$plist" &>/dev/null || true
		if launchctl load -w "$plist" &>/dev/null; then
			print_success "Homebrew 自动维护定时任务已配置（每 1 小时顺序执行 update/upgrade/cleanup --prune=all）"
		else
			print_warn "Homebrew 自动维护 LaunchAgent 已写入，但加载失败，请手动运行 launchctl load -w \"$plist\""
		fi
	else
		print_warn "未找到 launchctl，已写入 Homebrew 自动维护 LaunchAgent: $plist"
	fi
}

configure_brew_maintenance() {
	configure_brew_maintenance_launchagent
}

configure_pmset() {
	print_info "配置电源管理..."

	if ! has_sudo; then
		print_warn "无 sudo 权限，跳过电源管理配置"
		return 0
	fi

	if save_pmset_state; then
		print_dim "已保存原始 pmset 配置"
	elif [[ -f "$(pmset_state_file)" ]]; then
		print_dim "沿用已保存的原始 pmset 配置"
	else
		print_warn "保存原始 pmset 配置失败，仍继续应用目标设置"
	fi

	sudo pmset -a sleep 0
	sudo pmset -a tcpkeepalive 1
	print_success "电源管理已配置（合盖不睡眠，TCP 保活开启）"
}

main() {
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

# 仅在 Xcode 路径无效时重置（避免覆盖用户自定义的 xcode-select -s 设置）
xcode-select -p &>/dev/null || sudo xcode-select --reset 2>/dev/null

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

# 添加第三方 tap
ensure_brew_tap "mihomo-party-org/mihomo-party"

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

# 5. 配置 Homebrew 自动维护
print_info "配置 Homebrew 自动维护..."

configure_brew_maintenance

# 6. 清理 Homebrew 缓存
print_info "清理 Homebrew 缓存..."
brew cleanup --prune=all

# 7. 配置电源管理（合盖不睡眠，保持 SSH 连接）
configure_pmset

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

# 9. 配置默认文件关联（无扩展名文本文件用 VSCode 打开）
if command -v duti &>/dev/null; then
	print_info "配置默认文件关联..."
	local changed=0
	for uti in public.plain-text public.data public.text public.unix-executable; do
		if [[ "$(duti -d "$uti" 2>/dev/null)" != "com.microsoft.VSCode" ]]; then
			duti -s com.microsoft.VSCode "$uti" all
			changed=$((changed + 1))
		fi
	done
	if [[ $changed -eq 0 ]]; then
		print_success "文件关联已配置，跳过"
	else
		print_success "文件关联已更新 ($changed 项)"
	fi
fi

# ========================================
# 完成
# ========================================
_echo_blank
print_success "=========================================="
print_success "macOS 安装完成！"
print_success "=========================================="
}

main "$@"
