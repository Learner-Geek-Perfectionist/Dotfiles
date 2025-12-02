# Dotfiles

个人 macOS 和 Linux 开发环境自动化配置脚本。

## 特性

- **Linux**: 使用 [Nix](https://nixos.org/) + [Devbox](https://www.jetify.com/devbox) 管理开发环境
  - 默认**无需 sudo 权限**，适合服务器环境
  - 使用 [nix-user-chroot](https://github.com/nix-community/nix-user-chroot) 实现用户级安装
  - 统一的包管理，无需针对不同发行版编写脚本
  - **包装脚本透明处理 nix 环境，直接 `devbox shell` 即可**
- **macOS**: 使用 [Homebrew](https://brew.sh/) 管理 CLI 工具和 GUI 应用
- **Zsh**: zinit 插件管理、Powerlevel10k 主题、自动补全
- **终端**: kitty 终端配置
- **VSCode**: 插件自动安装

## 快速安装

### GitHub

```bash
# 默认安装
bash <(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/beta/install.sh)

# 使用 sudo 安装（Linux 系统级 Nix）
bash <(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/beta/install.sh) --use-sudo

# 仅安装 dotfiles 配置
bash <(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/beta/install.sh) --dotfiles-only

# 跳过 VSCode 插件安装
bash <(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/beta/install.sh) --skip-vscode
```

### Gitee（国内加速）

```bash
# 默认安装
bash <(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/beta/install.sh)

# 使用 sudo 安装（Linux 系统级 Nix）
bash <(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/beta/install.sh) --use-sudo

# 仅安装 dotfiles 配置
bash <(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/beta/install.sh) --dotfiles-only

# 跳过 VSCode 插件安装
bash <(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/beta/install.sh) --skip-vscode
```

### 安装选项说明

| 选项 | 说明 |
|------|------|
| (无) | 默认安装，Linux 使用 nix-user-chroot（无需 sudo） |
| `--use-sudo` | Linux 使用系统级 Nix 安装（需要 sudo） |
| `--dotfiles-only` | 仅安装配置文件，不安装工具 |
| `--skip-vscode` | 跳过 VSCode 插件安装 |

## 架构

```
┌─────────────────────────────────────────────────────┐
│                   install.sh (入口)                  │
├─────────────────────────────────────────────────────┤
│              检测 OS → macOS / Linux                 │
└──────────┬──────────────────────────┬───────────────┘
           ↓                          ↓
┌──────────────────────┐   ┌──────────────────────────┐
│   macOS (Homebrew)   │   │   Linux (Nix/Devbox)     │
│   • brew formulas    │   │   • nix-user-chroot      │
│   • brew casks       │   │   • devbox 包装脚本      │
│   • dotfiles         │   │   • 无需 sudo            │
└──────────────────────┘   └──────────────────────────┘
```

## 目录结构

```
Dotfiles/
├── install.sh              # 统一入口
├── devbox.json             # Devbox 包定义（Linux）
├── scripts/
│   ├── install_nix.sh      # Nix 安装（支持 nix-user-chroot）
│   ├── install_devbox.sh   # Devbox 安装 + 包装脚本
│   ├── install_vscode_ext.sh # VSCode 插件安装
│   ├── setup_dotfiles.sh   # 配置文件部署
│   └── macos_install.sh    # macOS Homebrew 安装
├── lib/
│   ├── packages.sh         # macOS 包定义
│   └── utils.sh            # 工具函数
├── .config/
│   ├── zsh/                # Zsh 插件配置
│   └── kitty/              # Kitty 终端配置
├── .zshrc                  # Zsh 主配置
├── .zshenv                 # Zsh 环境变量
└── .zprofile               # Zsh 登录配置
```

## Linux 使用

### 无 sudo 权限（默认）

适用于没有 root 权限的服务器环境。安装流程：

1. 检测用户命名空间支持
2. 下载 nix-user-chroot 到 `~/.local/bin`
3. 在 `~/.nix` 目录安装 Nix
4. 安装 Devbox + 创建包装脚本
5. 配置 dotfiles

**安装完成后，直接使用：**

```bash
# 进入开发环境（包装脚本自动处理 nix 环境）
cd ~/.dotfiles && devbox shell
```

> 💡 无需先运行 `nix-enter`，包装脚本会透明处理 nix-user-chroot。

### 有 sudo 权限

```bash
curl -fsSL .../install.sh | bash -s -- --use-sudo
```

使用官方 Nix 安装器，以 daemon 模式安装到系统级。

## macOS 使用

自动安装以下内容：

### CLI 工具 (brew formulas)

| 类型 | 工具 |
|------|------|
| 核心 | git, curl, wget, coreutils |
| 编辑器 | neovim, vim |
| 终端增强 | fzf, ripgrep, fd, eza, bat, htop |
| 开发 | cmake, ninja, gcc, llvm |
| 语言 | python, nodejs, go, rust, ruby, kotlin |

### GUI 应用 (brew casks)

| 类型 | 应用 |
|------|------|
| 开发 | VS Code, Kitty, OrbStack |
| IDE | IntelliJ IDEA, PyCharm, CLion |
| 浏览器 | Chrome, Edge |
| 通讯 | WeChat, QQ, Telegram, Discord |

## Devbox 使用

安装完成后，`~/.dotfiles/devbox.json` 包含所有开发工具定义：

```bash
# 进入开发环境
cd ~/.dotfiles
devbox shell

# 运行脚本
devbox run setup        # 配置 dotfiles
devbox run vscode-ext   # 安装 VSCode 插件

# 更新包
devbox update
```

## VSCode 插件

运行 `scripts/install_vscode_ext.sh` 自动安装以下插件：

- C/C++: cpptools, CMake Tools, clangd
- Rust: rust-analyzer
- Go: golang.go
- Python: Python, Pylance
- Git: GitLens, Git Graph
- 远程开发: Remote SSH
- 主题: Material Icon Theme, One Dark Pro

## 卸载

```bash
# 移除 dotfiles 配置
rm -f ~/.zshrc ~/.zshenv ~/.zprofile
rm -rf ~/.config/kitty ~/.config/zsh

# 移除 Nix（用户级安装）
rm -rf ~/.nix ~/.local/bin/nix-* ~/.local/bin/devbox

# 移除 Devbox
rm -rf ~/.local/share/devbox ~/.dotfiles
```

## 常见问题

### Q: 无 sudo 安装失败？

检查系统是否支持用户命名空间：

```bash
unshare --user --pid echo YES
```

如果输出 `YES`，则支持。否则需要管理员启用：

```bash
sudo sysctl kernel.unprivileged_userns_clone=1
```

### Q: 如何更新开发工具？

```bash
cd ~/.dotfiles
devbox update
```

### Q: macOS Homebrew 安装很慢？

建议开启代理，或使用国内镜像（已自动配置清华源）。

## License

MIT
