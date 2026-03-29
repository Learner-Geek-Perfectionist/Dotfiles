#!/bin/bash
# VSCode/Cursor 插件批量安装脚本
# 远程服务器的插件通过 settings.json 的 remote.SSH.defaultExtensions 自动同步
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

# 远程服务器环境标记（常规插件通过 settings.json 自动同步，VSIX 插件需手动安装）
REMOTE_SERVER=false
if is_remote_server; then
	REMOTE_SERVER=true
	print_dim "远程服务器环境，仅安装 Open VSX 缺失的 VSIX 插件"
fi

# 通用插件（VSCode 和 Cursor 共用）
EXTENSIONS=(
	# 中文语言包
	"ms-ceintl.vscode-language-pack-zh-hans"
	# C/C++
	"xaver.clang-format"
	# Rust
	"rust-lang.rust-analyzer" "fill-labs.dependi" "tamasfe.even-better-toml"
	# Go
	"golang.go"
	# Python - 只保留 ruff（通用 linter/formatter），其他由各编辑器专属扩展提供
	"charliermarsh.ruff"
	# Java/Kotlin
	"vscjava.vscode-java-pack" "fwcd.kotlin"
	# Lua
	"sumneko.lua"
	# Shell
	"mkhl.shfmt"
	# Markdown
	"bierner.markdown-mermaid"
	# Git
	"mhutchie.git-graph"
	# Docker
	"ms-azuretools.vscode-docker"
)

# 专属插件 (vscode:ext 或 cursor:ext)
SPECIFIC=(
	# VSCode 专属
	"vscode:huacnlee.autocorrect"
	"vscode:ms-vscode.cpptools"
	"vscode:ms-vscode.cpptools-extension-pack"
	"vscode:ms-vscode.cmake-tools"
	"vscode:vadimcn.vscode-lldb"
	"vscode:ms-python.python"
	"vscode:ms-python.vscode-pylance"
	"vscode:ms-python.debugpy"
	"vscode:ms-vscode-remote.remote-ssh"
	"vscode:ms-vscode-remote.remote-ssh-edit"
	"vscode:ms-vscode.remote-explorer"
	"vscode:ms-vscode-remote.remote-containers"
	# Cursor 专属（cursorpyright 会自动安装 debugpy）
	"cursor:anysphere.cpptools"
	"cursor:anysphere.cursorpyright"
	"cursor:anysphere.remote-ssh"
	"cursor:anysphere.remote-containers"
)

# Cursor 需要从 VS Code Marketplace 下载 VSIX 安装的插件（Open VSX 没有）
CURSOR_VSIX=(
	"huacnlee.autocorrect"
)

# GitHub Release 分发的私有 VSIX 插件（owner/repo:extension-id）
GITHUB_VSIX=(
	"Learner-Geek-Perfectionist/claude-code-ref:xin.claude-code-ref"
)

# 从 GitHub Release 下载最新 VSIX 并安装
# 参数: $1 = "owner/repo" $2 = editor command (code/cursor)
install_vsix_from_github() {
	local repo="$1" cmd="$2"
	local name="${repo#*/}"

	local tag
	tag=$(github_latest_release "$repo") || { print_warn "$name: 无法获取 release"; return 0; }

	local vsix_name="${name}-${tag#v}.vsix"
	local tmp_dir
	tmp_dir=$(mktemp -d)
	local tmp="$tmp_dir/$vsix_name"
	local url="https://github.com/${repo}/releases/download/${tag}/${vsix_name}"

	curl -fsSL "$url" -o "$tmp" || { print_warn "$name: 下载失败"; rm -rf "$tmp_dir"; return 0; }
	"$cmd" --install-extension "$tmp" --force &>/dev/null
	local rc=$?
	rm -rf "$tmp_dir"
	return $rc
}

# 从 VS Code Marketplace 下载 VSIX 并安装
install_vsix_from_marketplace() {
	local ext="$1" cmd="$2"
	local publisher="${ext%%.*}"
	local name="${ext#*.}"
	local tmp_dir
	tmp_dir=$(mktemp -d)
	local tmp="$tmp_dir/${publisher}.${name}.vsix"

	curl -sL "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${publisher}/vsextensions/${name}/latest/vspackage" \
		-o "${tmp}.gz" || { print_warn "${publisher}.${name}: 下载失败"; rm -rf "$tmp_dir"; return 0; }

	if file "${tmp}.gz" | grep -q "gzip"; then
		gunzip -c "${tmp}.gz" >"$tmp"
	else
		mv "${tmp}.gz" "$tmp"
	fi

	"$cmd" --install-extension "$tmp" --force &>/dev/null
	local rc=$?
	rm -rf "$tmp_dir"
	return $rc
}

# detect_editor_type 已在 lib/utils.sh 中定义

# 检测编辑器（基于二进制路径去重，避免 code/cursor 指向同一个二进制）
editors=()
declare -A _seen_paths=()
for cmd in code cursor; do
	command -v "$cmd" &>/dev/null || continue
	local bin_path
	bin_path=$(realpath "$(command -v "$cmd")" 2>/dev/null || command -v "$cmd")
	[[ -n "${_seen_paths[$bin_path]:-}" ]] && continue
	_seen_paths[$bin_path]=1
	local real_type
	real_type=$(detect_editor_type "$cmd")
	editors+=("$real_type:$cmd")
done
unset _seen_paths

if [[ ${#editors[@]} -eq 0 ]]; then
	print_error "未找到 VSCode 或 Cursor"
	exit 1
fi

print_dim "检测到 ${#editors[@]} 个编辑器"

for entry in "${editors[@]}"; do
	type="${entry%%:*}" cmd="${entry#*:}"
	_echo_blank
	print_info ">>> $type ($cmd)"

	# 获取已安装的插件（带版本号，一次 CLI 调用同时满足存在性检查和版本比较）
	if ! installed_ver=$("$cmd" --list-extensions --show-versions 2>/dev/null | tr '[:upper:]' '[:lower:]'); then
		print_warn "$type ($cmd) 无法获取插件列表，跳过"
		continue
	fi
	installed=$(echo "$installed_ver" | cut -d@ -f1)

	# 收集要安装的插件：ext|tag (tag: common/vscode/cursor/cursor-vsix)
	all_exts=()
	if [[ "$REMOTE_SERVER" == true ]]; then
		# 远程环境：仅安装 Open VSX 缺失的 VSIX 插件
		if [[ "$type" == "cursor" ]]; then
			for ext in "${CURSOR_VSIX[@]}"; do
				all_exts+=("$ext|cursor-vsix")
			done
		fi
	else
		for ext in "${EXTENSIONS[@]}"; do
			all_exts+=("$ext|common")
		done
		for item in "${SPECIFIC[@]}"; do
			t="${item%%:*}" e="${item#*:}"
			[[ "$t" == "$type" ]] && all_exts+=("$e|$t")
		done
		if [[ "$type" == "cursor" ]]; then
			for ext in "${CURSOR_VSIX[@]}"; do
				all_exts+=("$ext|cursor-vsix")
			done
		fi
		# GitHub Release 分发的 VSIX（VSCode 和 Cursor 通用）
		for item in "${GITHUB_VSIX[@]}"; do
			ext_id="${item#*:}"
			all_exts+=("$ext_id|github-vsix:${item%%:*}")
		done
	fi

	# 分类：已安装、待安装
	skipped=() to_install=()
	for item in "${all_exts[@]}"; do
		ext="${item%%|*}"
		tag="${item#*|}"
		ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
		if [[ "$tag" == github-vsix:* ]]; then
			# GitHub VSIX：比较已安装版本与最新 Release，一致则跳过
			repo="${tag#github-vsix:}"
			local_ver=$(echo "$installed_ver" | grep -i "^${ext_lower}@" | cut -d@ -f2)
			if [[ -n "$local_ver" ]]; then
				latest_tag=$(github_latest_release "$repo" 2>/dev/null) || true
				if [[ "${latest_tag#v}" == "$local_ver" ]]; then
					skipped+=("$ext")
					continue
				fi
			fi
			to_install+=("$item")
		elif echo "$installed" | grep -Fxq "$ext_lower"; then
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
			# 进度条直接输出到终端（\r 覆盖行），有意不写入日志（避免日志中大量覆盖行）
			printf "\r${CYAN}[%d/%d]${NC} 安装中: ${YELLOW}%s${NC}%-20s" "$count" "$total" "$ext" ""
			# 尝试安装，捕获退出码
			local install_rc=0
			if [[ "$tag" == github-vsix:* ]]; then
				repo="${tag#github-vsix:}"
				install_vsix_from_github "$repo" "$cmd" || install_rc=$?
			elif [[ "$tag" == "cursor-vsix" ]]; then
				install_vsix_from_marketplace "$ext" "$cmd" || install_rc=$?
			else
				"$cmd" --install-extension "$ext" --force &>/dev/null || install_rc=$?
			fi
			# 安装命令本身失败时立即记录
			if [[ $install_rc -ne 0 ]]; then
				failed+=("$item")
			fi
		done
		echo ""

		# 批量验证安装结果（一次 CLI 调用替代循环内 N 次）
		# 跳过已在安装阶段标记为 failed 的项
		local already_failed=" ${failed[*]} "
		new_installed=$("$cmd" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
		for item in "${to_install[@]}"; do
			ext="${item%%|*}"
			[[ "$already_failed" == *" $item "* ]] && continue
			ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
			if echo "$new_installed" | grep -Fxq "$ext_lower"; then
				success+=("$ext")
			else
				failed+=("$item")
			fi
		done
	fi

	# 打印汇总
	print_install_summary "${type} 插件" "${#success[@]}" "${#skipped[@]}" "${#failed[@]}"
	for item in "${failed[@]}"; do
		print_dim "  ✗ ${item%%|*}"
	done
done

_echo_blank
print_success "编辑器插件安装完成"
