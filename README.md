# Dotfiles

跨平台（macOS / Linux）开发环境一键部署系统。一条命令完成 Shell、编辑器、终端、Git、SSH、包管理、AI 工具链的全套配置。

---

## 快速开始

```bash
# 完整安装（macOS: Homebrew + 配置 / Linux: Pixi + 配置）
curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/beta/install.sh | bash

# 选择性安装
bash install.sh --dotfiles-only   # 仅配置文件
bash install.sh --pixi-only       # 仅 Pixi 包管理器（Linux）
bash install.sh --vscode-only     # 仅 VSCode/Cursor 插件
bash install.sh --lsp-only        # 仅 LSP 服务器
bash install.sh --skip-vscode     # 跳过 VSCode 插件
```

## 功能概览

### Shell（Zsh）

- **[Zinit](https://github.com/zdharma-continuum/zinit)** 插件管理器，Turbo 异步加载
- **[Powerlevel10k](https://github.com/romkatv/powerlevel10k)** 主题，instant prompt 缓存加速
- **[fzf-tab](https://github.com/Aloxaf/fzf-tab)** 模糊补全、**[fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting)** 语法高亮、**[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)** 自动建议
- 智能命令包装：`fd` 自动提权、`cat` → `bat`、`ls` → `eza`、`man` → `tldr`
- `.zwc` 字节码预编译加速启动
- **[age](https://github.com/FiloSottile/age)** 加密令牌管理

### 包管理

| 平台 | 管理器 | 配置文件 |
|------|--------|----------|
| macOS | Homebrew | `lib/packages.sh`（80+ formulas & casks） |
| Linux | Pixi（无需 root，conda-forge） | `pixi.toml`（90+ 包） |

### 终端 & 编辑器

- **[Kitty](https://sw.kovidgoyal.net/kitty/)** 终端，Catppuccin Frappe 主题，智能标签页/关闭脚本
- **VSCode / Cursor** 配置同步（settings.json + keybindings.json），插件自动安装
- **Neovim / Vim**

### macOS 专属

- **[Karabiner-Elements](https://karabiner-elements.pqrs.org/)** 键盘改键
- **[Hammerspoon](https://www.hammerspoon.org/)** 窗口管理与自动化
- Homebrew 自动更新（`brew autoupdate`）

### AI 工具链

- **Claude Code** CLI + LSP 服务器（pyright, gopls, rust-analyzer, clangd, kotlin-ls 等）
- MCP 服务器集成、插件市场、Skill 系统

### 开发工具链

语言：Python, Node.js, Go, Rust, Kotlin, Java, Ruby, Lua, C/C++（LLVM/GCC）

构建：CMake, Ninja, Make, Autoconf

## 架构

```
                        +---------------------+
                        |     install.sh      |
                        |  Entry Point v5.0   |
                        +--------+------------+
                                 |
            +--------------------+--------------------+
            |                    |                     |
            v                    v                     v
  +------------------+  +------------------+  +------------------+
  |  macos_install   |  | install_dotfiles |  |  install_vscode  |
  |------------------|  |------------------|  |------------------|
  | Homebrew         |  | Config files     |  | VSCode / Cursor  |
  | 80+ pkg & casks  |  | Symlink deploy   |  | Extensions       |
  +------------------+  +------------------+  +------------------+
            |
            | Linux
            v
  +------------------+  +------------------+  +------------------+
  |  install_pixi    |  | install_claude   |  | install_kotlin   |
  |------------------|  |------------------|  |------------------|
  | Pixi (rootless)  |  | LSP / MCP       |  | Kotlin Native    |
  | conda-forge      |  | Skills & Hooks  |  | Toolchain        |
  +------------------+  +------------------+  +------------------+

  ================== Shell Load Order ==================

  .zshenv --> .zprofile --> .zshrc
     |                        |
     | ENV VARS               +--> platform.zsh       PATH & aliases
     | HISTFILE               +--> zinit.zsh           Plugins & Turbo
     | ZSH_CACHE_DIR          +--> double-esc-clear    Double-ESC clear
                              +--> age-tokens.zsh      Encrypted tokens

  =================== App Configs (.config/) ===================

  kitty/                Terminal emulator
  Code/User/  <--sync-->  Cursor/User/      Editor settings
  ripgrep/              Search config
  karabiner/            Key remap (macOS)
  direnv/               Per-dir env
```

## 设计原则

- **模块化** — 每个组件独立安装/卸载
- **幂等** — 重复执行安全无副作用
- **对称** — 每个 install 都有对应的 uninstall
- **无需 root** — Linux 全程 rootless（Pixi + conda-forge）
- **管道安全** — 支持 `curl | bash` 远程执行

## 卸载

```bash
bash uninstall.sh --all            # 全部卸载
bash uninstall.sh --dotfiles       # 仅配置文件
bash uninstall.sh --pixi           # 仅 Pixi
bash uninstall.sh --claude         # 仅 Claude Code
```

## 许可证

MIT
