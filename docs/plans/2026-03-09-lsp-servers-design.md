# LSP Servers Installation Design

## Purpose

为 Claude Code 安装 11 个 Language Server，覆盖 macOS 和 Linux（rootless）。

## Approach: Mixed

brew/pixi 能管的交给包管理器，其余由 `scripts/install_lsp.sh` 处理。

## File Changes

| File | Change |
|------|--------|
| `lib/packages.sh` | brew_formulas += pyright, gopls, lua-language-server, jdtls |
| `pixi.toml` | dependencies += pyright |
| `scripts/install_lsp.sh` | New script for non-package-manager LSPs |
| `install.sh` | Add LSP step after brew/pixi, before dotfiles; add `--lsp-only` flag |

## LSP Installation Matrix

| LSP | macOS | Linux |
|-----|-------|-------|
| clangd | Already installed (llvm) | Already installed (clang-tools) |
| pyright | brew | pixi (conda-forge) |
| gopls | brew | `go install golang.org/x/tools/gopls@latest` |
| rust-analyzer | `rustup component add rust-analyzer` | Same |
| lua-language-server | brew | GitHub release (latest) |
| jdtls | brew | GitHub release (latest) |
| typescript-language-server | `npm install -g typescript-language-server typescript` | Same |
| intelephense | `npm install -g intelephense` | Same |
| csharp-ls | `dotnet tool install -g csharp-ls` | Same |
| kotlin-language-server | GitHub release (latest) | Same |
| sourcekit-lsp | Built-in (Xcode) | Skip (needs Swift toolchain) |

## Binary Download Strategy

- Install dir: `~/.local/share/lsp/<lsp-name>/`
- Executables: `~/.local/bin/` (symlinks or wrapper scripts)
- Version check: GitHub API (`/repos/<owner>/<repo>/releases/latest`) with local version file
- Idempotent: skip if already at latest version

### GitHub Release Sources

| LSP | Repo | Artifact |
|-----|------|----------|
| kotlin-language-server | fwcd/kotlin-language-server | `server-<ver>.zip` |
| lua-language-server | LuaLS/lua-language-server | `lua-language-server-<ver>-<platform>.tar.gz` |
| jdtls | eclipse-jdtls/eclipse.jdt.ls | `jdt-language-server-<ver>.tar.gz` |

## install_lsp.sh Structure

```
scripts/install_lsp.sh
├── source lib/utils.sh
├── install_rustup_lsp()        # rustup component add rust-analyzer
├── install_go_lsp()            # go install gopls (Linux only)
├── install_npm_lsps()          # npm -g: typescript-language-server, intelephense
├── install_dotnet_lsp()        # dotnet tool: csharp-ls
├── install_kotlin_ls()         # GitHub release download
├── install_lua_ls()            # GitHub release download (Linux only)
├── install_jdtls()             # GitHub release download (Linux only)
└── main()                      # Sequential calls, skip per platform
```

## Integration in install.sh

macOS: Homebrew → **LSP** → Dotfiles → VSCode plugins
Linux: Pixi binary → Pixi tools → **LSP** → Dotfiles → Shell → VSCode plugins

## Out of Scope

- sourcekit-lsp on Linux (requires full Swift toolchain)
- clangd (already available on both platforms)
- Neovim/editor-specific LSP configuration

---

# LSP Servers Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 11 LSP server installations to the Dotfiles project, supporting both macOS and Linux (rootless).

**Architecture:** Mixed approach — brew/pixi for package-manager-friendly LSPs, a dedicated `scripts/install_lsp.sh` for the rest (npm, go install, rustup, dotnet, GitHub binary releases). Binary downloads go to `~/.local/share/lsp/<name>/` with executables in `~/.local/bin/`.

**Tech Stack:** Bash, Homebrew, Pixi/conda-forge, npm, go, rustup, dotnet, GitHub Releases API, jq, curl

---

### Task 1: Add LSP packages to brew_formulas

**Files:**
- Modify: `lib/packages.sh:114-125` (after `# 语言` section)

**Step 1: Add LSP comment block and packages**

After the existing `perl` entry (line 125) and before `# Rust 工具` (line 127), add:

```bash
	# LSP Servers
	pyright
	gopls
	lua-language-server
	jdtls
```

**Step 2: Verify syntax**

Run: `bash -n lib/packages.sh`
Expected: no output (no syntax errors)

**Step 3: Commit**

```bash
git add lib/packages.sh
git commit -m "feat: add LSP server packages to brew formulas"
```

---

### Task 2: Add pyright to pixi.toml

**Files:**
- Modify: `pixi.toml:35-45` (after `# 编程语言运行时` section)

**Step 1: Add pyright dependency**

After the `kotlin = "*"` entry (line 45) and before the blank line, add:

```toml
# LSP Servers
pyright = "*"
```

**Step 2: Verify TOML syntax**

Run: `python3 -c "import tomllib; tomllib.load(open('pixi.toml','rb')); print('OK')"`
Expected: `OK`

**Step 3: Commit**

```bash
git add pixi.toml
git commit -m "feat: add pyright to pixi dependencies"
```

---

### Task 3: Create scripts/install_lsp.sh — core structure

**Files:**
- Create: `scripts/install_lsp.sh`

**Step 1: Write the script with all functions**

The script must:
- `source` the project's `lib/utils.sh` for logging and platform detection
- Define `LSP_DIR="$HOME/.local/share/lsp"` and `LSP_BIN="$HOME/.local/bin"`
- Include helper functions: `ensure_lsp_dirs()`, `get_latest_release()`, `get_local_version()`, `save_local_version()`

```bash
#!/bin/bash
# LSP Server 安装脚本
# 安装 brew/pixi 无法管理的 Language Server
#
# macOS: rust-analyzer, typescript-language-server, intelephense, csharp-ls, kotlin-language-server
# Linux: 以上全部 + gopls, lua-language-server, jdtls

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

LSP_DIR="$HOME/.local/share/lsp"
LSP_BIN="$HOME/.local/bin"

# ========================================
# 辅助函数
# ========================================

ensure_lsp_dirs() {
	mkdir -p "$LSP_DIR" "$LSP_BIN"
}

# 从 GitHub API 获取最新 release tag
get_latest_release() {
	local repo="$1"
	curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name'
}

# 读取本地已安装版本
get_local_version() {
	local name="$1"
	local version_file="$LSP_DIR/$name/.version"
	[[ -f "$version_file" ]] && cat "$version_file" || echo ""
}

# 保存版本信息
save_local_version() {
	local name="$1" version="$2"
	mkdir -p "$LSP_DIR/$name"
	echo "$version" >"$LSP_DIR/$name/.version"
}

# ========================================
# rust-analyzer (双平台, via rustup)
# ========================================
install_rust_analyzer() {
	if ! command -v rustup &>/dev/null; then
		print_warn "rustup 未安装，跳过 rust-analyzer"
		return 0
	fi
	print_info "安装 rust-analyzer..."
	rustup component add rust-analyzer 2>/dev/null
	print_success "rust-analyzer 安装完成"
}

# ========================================
# gopls (仅 Linux, macOS 由 brew 管理)
# ========================================
install_gopls() {
	if [[ "$(detect_os)" == "macos" ]]; then
		return 0
	fi
	if ! command -v go &>/dev/null; then
		print_warn "go 未安装，跳过 gopls"
		return 0
	fi
	print_info "安装 gopls..."
	go install golang.org/x/tools/gopls@latest
	print_success "gopls 安装完成"
}

# ========================================
# npm LSP servers (双平台)
# typescript-language-server, intelephense
# ========================================
install_npm_lsps() {
	if ! command -v npm &>/dev/null; then
		print_warn "npm 未安装，跳过 npm LSP servers"
		return 0
	fi
	print_info "安装 typescript-language-server..."
	npm install -g typescript-language-server typescript 2>/dev/null
	print_success "typescript-language-server 安装完成"

	print_info "安装 intelephense..."
	npm install -g intelephense 2>/dev/null
	print_success "intelephense 安装完成"
}

# ========================================
# csharp-ls (双平台, via dotnet)
# ========================================
install_csharp_ls() {
	if ! command -v dotnet &>/dev/null; then
		print_warn "dotnet 未安装，跳过 csharp-ls"
		return 0
	fi
	print_info "安装 csharp-ls..."
	dotnet tool install -g csharp-ls 2>/dev/null || dotnet tool update -g csharp-ls 2>/dev/null
	print_success "csharp-ls 安装完成"
}

# ========================================
# kotlin-language-server (双平台, GitHub release)
# ========================================
install_kotlin_ls() {
	local repo="fwcd/kotlin-language-server"
	local name="kotlin-language-server"

	print_info "检查 $name..."

	local latest_ver
	latest_ver=$(get_latest_release "$repo") || {
		print_warn "无法获取 $name 最新版本，跳过"
		return 0
	}

	local local_ver
	local_ver=$(get_local_version "$name")
	if [[ "$latest_ver" == "$local_ver" ]]; then
		print_warn "$name 已是最新版本 ($latest_ver)"
		return 0
	fi

	print_info "安装 $name $latest_ver..."
	local download_url="https://github.com/$repo/releases/download/$latest_ver/server.zip"
	local tmp_file="/tmp/$name.zip"

	curl -fsSL -o "$tmp_file" "$download_url" || {
		print_warn "下载 $name 失败，跳过"
		return 0
	}

	rm -rf "$LSP_DIR/$name"
	mkdir -p "$LSP_DIR/$name"
	unzip -q -o "$tmp_file" -d "$LSP_DIR/$name"
	rm -f "$tmp_file"

	# 创建符号链接
	ln -sf "$LSP_DIR/$name/server/bin/kotlin-language-server" "$LSP_BIN/kotlin-language-server"

	save_local_version "$name" "$latest_ver"
	print_success "$name $latest_ver 安装完成"
}

# ========================================
# lua-language-server (仅 Linux, GitHub release)
# macOS 由 brew 管理
# ========================================
install_lua_ls() {
	if [[ "$(detect_os)" == "macos" ]]; then
		return 0
	fi

	local repo="LuaLS/lua-language-server"
	local name="lua-language-server"

	print_info "检查 $name..."

	local latest_ver
	latest_ver=$(get_latest_release "$repo") || {
		print_warn "无法获取 $name 最新版本，跳过"
		return 0
	}

	local local_ver
	local_ver=$(get_local_version "$name")
	if [[ "$latest_ver" == "$local_ver" ]]; then
		print_warn "$name 已是最新版本 ($latest_ver)"
		return 0
	fi

	print_info "安装 $name $latest_ver..."
	local arch
	arch=$(detect_arch)
	local platform_suffix
	case "$arch" in
	x86_64) platform_suffix="linux-x64" ;;
	aarch64) platform_suffix="linux-arm64" ;;
	esac

	local download_url="https://github.com/$repo/releases/download/$latest_ver/lua-language-server-${latest_ver#v}-$platform_suffix.tar.gz"
	local tmp_file="/tmp/$name.tar.gz"

	curl -fsSL -o "$tmp_file" "$download_url" || {
		print_warn "下载 $name 失败，跳过"
		return 0
	}

	rm -rf "$LSP_DIR/$name"
	mkdir -p "$LSP_DIR/$name"
	tar -xzf "$tmp_file" -C "$LSP_DIR/$name"
	rm -f "$tmp_file"

	# lua-language-server 需要从其自身目录运行，创建 wrapper 脚本
	cat >"$LSP_BIN/lua-language-server" <<'WRAPPER'
#!/bin/bash
exec "$HOME/.local/share/lsp/lua-language-server/bin/lua-language-server" "$@"
WRAPPER
	chmod +x "$LSP_BIN/lua-language-server"

	save_local_version "$name" "$latest_ver"
	print_success "$name $latest_ver 安装完成"
}

# ========================================
# jdtls (仅 Linux, GitHub release)
# macOS 由 brew 管理
# ========================================
install_jdtls() {
	if [[ "$(detect_os)" == "macos" ]]; then
		return 0
	fi

	local repo="eclipse-jdtls/eclipse.jdt.ls"
	local name="jdtls"

	print_info "检查 $name..."

	local latest_ver
	latest_ver=$(get_latest_release "$repo") || {
		print_warn "无法获取 $name 最新版本，跳过"
		return 0
	}

	local local_ver
	local_ver=$(get_local_version "$name")
	if [[ "$latest_ver" == "$local_ver" ]]; then
		print_warn "$name 已是最新版本 ($latest_ver)"
		return 0
	fi

	print_info "安装 $name $latest_ver..."
	local ver_num="${latest_ver#v}"
	local download_url="https://github.com/$repo/releases/download/$latest_ver/jdt-language-server-$ver_num.tar.gz"
	local tmp_file="/tmp/$name.tar.gz"

	curl -fsSL -o "$tmp_file" "$download_url" || {
		print_warn "下载 $name 失败，跳过"
		return 0
	}

	rm -rf "$LSP_DIR/$name"
	mkdir -p "$LSP_DIR/$name"
	tar -xzf "$tmp_file" -C "$LSP_DIR/$name"
	rm -f "$tmp_file"

	# jdtls 需要 Java 运行时，创建 wrapper 脚本
	cat >"$LSP_BIN/jdtls" <<'WRAPPER'
#!/bin/bash
JDTLS_HOME="$HOME/.local/share/lsp/jdtls"
LAUNCHER=$(find "$JDTLS_HOME/plugins" -name 'org.eclipse.equinox.launcher_*.jar' | head -1)
CONFIG="$JDTLS_HOME/config_linux"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/jdtls-workspace/$(echo -n "$(pwd)" | md5sum | cut -d' ' -f1)"

exec java \
	-Declipse.application=org.eclipse.jdt.ls.core.id1 \
	-Dosgi.bundles.defaultStartLevel=4 \
	-Declipse.product=org.eclipse.jdt.ls.core.product \
	-Dlog.protocol=true \
	-Dlog.level=ALL \
	-Xmx1G \
	--add-modules=ALL-SYSTEM \
	--add-opens java.base/java.util=ALL-UNNAMED \
	--add-opens java.base/java.lang=ALL-UNNAMED \
	-jar "$LAUNCHER" \
	-configuration "$CONFIG" \
	-data "$DATA_DIR" \
	"$@"
WRAPPER
	chmod +x "$LSP_BIN/jdtls"

	save_local_version "$name" "$latest_ver"
	print_success "$name $latest_ver 安装完成"
}

# ========================================
# 主函数
# ========================================
main() {
	print_section "🔧 安装 LSP Servers"

	ensure_lsp_dirs

	install_rust_analyzer
	install_gopls
	install_npm_lsps
	install_csharp_ls
	install_kotlin_ls
	install_lua_ls
	install_jdtls

	_echo_blank
	print_success "LSP Servers 安装完成"
}

main "$@"
```

**Step 2: Make it executable and verify syntax**

Run: `chmod +x scripts/install_lsp.sh && bash -n scripts/install_lsp.sh`
Expected: no output (no syntax errors)

**Step 3: Commit**

```bash
git add scripts/install_lsp.sh
git commit -m "feat: add LSP server installation script"
```

---

### Task 4: Integrate LSP installation into install.sh

**Files:**
- Modify: `install.sh`

**Step 1: Add LSP_ONLY variable and --lsp-only flag**

Add `LSP_ONLY="${LSP_ONLY:-false}"` after line 23 (after `VSCODE_ONLY`).

Add to the `case` block in `main()` (after the `--vscode-only)` case, around line 509):

```bash
		--lsp-only)
			LSP_ONLY="true"
			shift
			;;
```

Update `show_help()` to include the new flag:

```
    --lsp-only       仅安装 LSP Servers
```

Update `setup_logging()` to handle lsp-only mode suffix:

```bash
	elif [[ "$LSP_ONLY" == "true" ]]; then
		mode_suffix="-lsp-only"
```

**Step 2: Add install_lsp_servers() function**

Add after the `install_vscode()` function (after line 375):

```bash
# ========================================
# 安装 LSP Servers
# ========================================
install_lsp_servers() {
	local dotfiles_dir="$1"
	local step_num="$2"

	print_section "步骤 ${step_num}: 🔧 安装 LSP Servers"

	if [[ -f "$dotfiles_dir/scripts/install_lsp.sh" ]]; then
		bash "$dotfiles_dir/scripts/install_lsp.sh"
	else
		print_warn "未找到 LSP 安装脚本，跳过"
	fi
}
```

**Step 3: Update install_linux() flow**

Change from 5 steps to 6 steps. Add LSP_ONLY check and LSP step:

```bash
install_linux() {
	local dotfiles_dir="$1"

	# 仅安装 VSCode 插件模式
	if [[ "$VSCODE_ONLY" == "true" ]]; then
		install_vscode "$dotfiles_dir" "1/1"
		return 0
	fi

	# 仅安装 Dotfiles 模式
	if [[ "$DOTFILES_ONLY" == "true" ]]; then
		setup_dotfiles "$dotfiles_dir" "1/1"
		return 0
	fi

	# 仅安装 LSP 模式
	if [[ "$LSP_ONLY" == "true" ]]; then
		install_lsp_servers "$dotfiles_dir" "1/1"
		return 0
	fi

	# 步骤 1: 安装 Pixi
	install_pixi_binary "$dotfiles_dir" "1/6"

	if [[ "$PIXI_ONLY" == "true" ]]; then
		print_success "Pixi 安装完成（仅 Pixi 模式）"
		return 0
	fi

	# 步骤 2: 同步 Pixi 工具包
	sync_pixi_tools "$dotfiles_dir" "2/6"

	# 步骤 3: 安装 LSP Servers
	install_lsp_servers "$dotfiles_dir" "3/6"

	# 步骤 4: 安装 Dotfiles 配置
	setup_dotfiles "$dotfiles_dir" "4/6"

	# 步骤 5: 设置默认 shell
	setup_default_shell "5/6"

	# 步骤 6: VSCode 插件
	install_vscode "$dotfiles_dir" "6/6"
}
```

**Step 4: Update install_macos() flow**

Change from 3 steps to 4 steps. Add LSP_ONLY check and LSP step:

```bash
install_macos() {
	local dotfiles_dir="$1"

	# 仅安装 VSCode 插件模式
	if [[ "$VSCODE_ONLY" == "true" ]]; then
		install_vscode "$dotfiles_dir" "1/1"
		return 0
	fi

	# 仅安装 Dotfiles 模式
	if [[ "$DOTFILES_ONLY" == "true" ]]; then
		setup_dotfiles "$dotfiles_dir" "1/1"
		return 0
	fi

	# 仅安装 LSP 模式
	if [[ "$LSP_ONLY" == "true" ]]; then
		install_lsp_servers "$dotfiles_dir" "1/1"
		return 0
	fi

	# 步骤 1: 安装 Homebrew 包
	install_macos_homebrew "$dotfiles_dir" "1/4"

	# 步骤 2: 安装 LSP Servers
	install_lsp_servers "$dotfiles_dir" "2/4"

	# 步骤 3: 安装 Dotfiles 配置（已包含 SSH config）
	setup_dotfiles "$dotfiles_dir" "3/4"

	# 步骤 4: VSCode 插件
	install_vscode "$dotfiles_dir" "4/4"
}
```

**Step 5: Verify syntax**

Run: `bash -n install.sh`
Expected: no output (no syntax errors)

**Step 6: Commit**

```bash
git add install.sh
git commit -m "feat: integrate LSP server installation into install flow"
```

---

### Task 5: Verify on macOS

**Step 1: Run syntax checks on all modified files**

```bash
bash -n lib/packages.sh && echo "packages.sh OK"
bash -n scripts/install_lsp.sh && echo "install_lsp.sh OK"
bash -n install.sh && echo "install.sh OK"
python3 -c "import tomllib; tomllib.load(open('pixi.toml','rb')); print('pixi.toml OK')"
```

Expected: All print OK

**Step 2: Test LSP script standalone**

Run: `bash scripts/install_lsp.sh`
Expected: Each LSP installs or shows "跳过" if prerequisite missing. No errors.

**Step 3: Verify installed LSP binaries**

```bash
command -v rust-analyzer && echo "rust-analyzer OK"
command -v typescript-language-server && echo "typescript-language-server OK"
command -v intelephense && echo "intelephense OK"
kotlin-language-server --version 2>/dev/null && echo "kotlin-language-server OK"
```

**Step 4: Commit all changes**

```bash
git add -A
git commit -m "feat: LSP servers installation complete"
```
