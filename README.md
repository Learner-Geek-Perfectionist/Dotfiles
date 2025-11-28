# 🚀 Dotfiles

个人 macOS 和 Linux 开发环境自动化配置脚本。

## ✨ 功能特性

- 🍎 **macOS**: Homebrew 包管理、GUI 应用安装、Karabiner、Hammerspoon
- 🐧 **Linux**: Ubuntu / Fedora 支持，自动配置镜像源
- 🐚 **Zsh**: zinit 插件管理、主题、自动补全
- 🔧 **开发工具**: LLVM、CMake、Kotlin、Docker、Rust 工具链
- 🎨 **终端**: kitty 终端、fastfetch、eza、bat、fzf、ripgrep

## 📦 安装

### 完整安装（推荐）

安装所有开发工具和配置文件：

```bash
# GitHub
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/master/install.sh)"

# Gitee（国内加速）
/bin/bash -c "$(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/master/install.sh)"
```

### 仅 Zsh 配置和工具

安装 zsh 配置和相关工具（不安装 IDE、Docker 等）：

```bash
# GitHub
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/master/zsh_config.sh)"

# Gitee（国内加速）
/bin/bash -c "$(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/master/zsh_config.sh)"
```

### 仅更新 Dotfiles

只更新配置文件（`.zshrc`、`.zprofile` 等），不安装任何软件：

```bash
# GitHub
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/master/update_dotfiles.sh)"

# Gitee（国内加速）
/bin/bash -c "$(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/master/update_dotfiles.sh)"
```

## 🗑️ 卸载

移除所有配置文件：

```bash
# GitHub
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/master/uninstall_dotfiles.sh)"

# Gitee（国内加速）
/bin/bash -c "$(curl -fsSL https://gitee.com/oyzxin/Dotfiles/raw/master/uninstall_dotfiles.sh)"
```

## 📁 目录结构

```
Dotfiles/
├── install.sh              # 完整安装入口
├── update_dotfiles.sh      # 更新配置文件
├── uninstall_dotfiles.sh   # 卸载脚本
├── zsh_config.sh           # Zsh 配置安装
├── .zshrc                  # Zsh 主配置
├── .zshenv                 # Zsh 环境变量
├── .zprofile               # Zsh 登录配置
├── .config/
│   ├── zsh/                # Zsh 插件和配置
│   └── kitty/              # Kitty 终端配置
├── lib/
│   ├── constants.sh        # 常量定义
│   ├── packages.sh         # 包列表
│   └── utils.sh            # 工具函数
└── scripts/
    ├── main.sh             # 主安装脚本
    ├── macos_install.sh    # macOS 安装
    ├── ubuntu_install.sh   # Ubuntu 安装
    ├── ubuntu_tools.sh     # Ubuntu 工具安装
    ├── fedora_install.sh   # Fedora 安装
    └── fedora_tools.sh     # Fedora 工具安装
```

## 🛠️ 安装内容

### macOS (Homebrew)

| 类型 | 软件 |
|------|------|
| CLI | git, neovim, fzf, ripgrep, eza, bat, fd, htop, cmake, llvm |
| GUI | kitty, VSCode, JetBrains IDEs, Chrome, Wireshark, OrbStack |

### Linux (Ubuntu/Fedora)

| 类型 | 软件 |
|------|------|
| 编译工具 | cmake, llvm/clang, gcc |
| 语言 | OpenJDK, Kotlin, Go, Rust, Python |
| 容器 | Docker |
| 终端工具 | kitty, fzf, eza, bat, ripgrep, fd, fastfetch |

## 📄 License

MIT
