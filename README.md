# Dotfiles

Cross-platform (macOS / Linux) development environment bootstrap system. One command to deploy Shell, editor, terminal, Git, SSH, package management, and AI tooling configurations.

---

## Quick Start

```bash
# Full install (macOS: Homebrew + configs / Linux: Pixi + configs)
curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/beta/install.sh | bash

# Selective install
bash install.sh --dotfiles-only   # Config files only
bash install.sh --pixi-only       # Pixi package manager only (Linux)
bash install.sh --vscode-only     # VSCode/Cursor extensions only
bash install.sh --lsp-only        # LSP servers only
bash install.sh --skip-vscode     # Everything except VSCode extensions
```

## Features

### Shell (Zsh)

- **[Zinit](https://github.com/zdharma-continuum/zinit)** plugin manager with turbo async loading
- **[Powerlevel10k](https://github.com/romkatv/powerlevel10k)** prompt with instant prompt cache
- **[fzf-tab](https://github.com/Aloxaf/fzf-tab)** fuzzy completion, **[fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting)**, **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)**
- Smart CLI wrappers: `fd` with auto-sudo, `cat` via `bat`, `ls` via `eza`, `man` via `tldr`
- Pre-compiled `.zwc` bytecode for faster shell startup
- **[age](https://github.com/FiloSottile/age)** encrypted token management

### Package Management

| Platform | Manager | Config |
|----------|---------|--------|
| macOS | Homebrew | `lib/packages.sh` (80+ formulas & casks) |
| Linux | Pixi (rootless, conda-forge) | `pixi.toml` (90+ packages) |

### Terminal & Editor

- **[Kitty](https://sw.kovidgoyal.net/kitty/)** with Catppuccin Frappe theme, smart tab/close scripts
- **VSCode / Cursor** synced settings & keybindings, automated extension install
- **Neovim / Vim**

### macOS Extras

- **[Karabiner-Elements](https://karabiner-elements.pqrs.org/)** keyboard remapping
- **[Hammerspoon](https://www.hammerspoon.org/)** window management & automation
- Homebrew auto-update via `brew autoupdate`

### AI Tooling

- **Claude Code** CLI with LSP servers (pyright, gopls, rust-analyzer, clangd, kotlin-ls, etc.)
- MCP server integration, plugin marketplace, and skill system

### Developer Toolchain

Languages: Python, Node.js, Go, Rust, Kotlin, Java, Ruby, Lua, C/C++ (LLVM/GCC)

Build tools: CMake, Ninja, Make, Autoconf

## Architecture

```
install.sh / uninstall.sh          # Symmetric entry points
  scripts/
    install_dotfiles.sh            # Symlink deployment
    install_vscode_ext.sh          # VSCode/Cursor extensions
    install_claude_code.sh         # Claude Code LSP/MCP/Skills
    install_pixi.sh                # Pixi (Linux)
    install_kotlin_native.sh       # Kotlin Native toolchain
    macos_install.sh               # Homebrew packages
  lib/
    utils.sh                       # Logging, colors, helpers
    packages.sh                    # Homebrew package lists

.zshenv -> .zprofile -> .zshrc     # Shell loading order
  .config/zsh/plugins/
    platform.zsh                   # Platform-specific PATH & aliases
    zinit.zsh                      # Plugin manager & turbo loading
    age-tokens.zsh                 # Encrypted credentials
    double-esc-clear.zsh           # Double-ESC to clear

.config/
  kitty/                           # Terminal emulator
  Code/User/ & Cursor/User/       # Editor configs (kept in sync)
  ripgrep/                         # rg global config & ignore
  karabiner/                       # Keyboard remapping (macOS)
  direnv/                          # Per-directory env management
```

## Design Principles

- **Modular** - Each component installs/uninstalls independently
- **Idempotent** - Safe to run repeatedly
- **Symmetric** - Every `install` has a matching `uninstall`
- **Rootless** - Linux setup requires no sudo (Pixi + conda-forge)
- **Pipe-safe** - Supports `curl | bash` remote execution

## Uninstall

```bash
bash uninstall.sh --all            # Remove everything
bash uninstall.sh --dotfiles       # Config files only
bash uninstall.sh --pixi           # Pixi only
bash uninstall.sh --claude         # Claude Code only
```

## License

MIT
