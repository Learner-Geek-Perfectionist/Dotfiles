# Dotfiles

跨平台（macOS / Linux）开发环境配置管理系统。通过 install.sh 一键部署 Shell、编辑器、终端、Git、SSH、包管理等全套配置，uninstall.sh 支持分模块卸载。

核心理念：模块化、幂等、install/uninstall 对称。

## 模块依赖地图

### Shell 核心层（加载顺序）

.zshenv           -- 最先加载，定义环境变量（ZSH_CACHE_DIR, HISTFILE 等）
  -> .zprofile    -- macOS 登录 shell，缓存 Homebrew shellenv
  -> .zshrc       -- 交互式 shell 入口
       source -> .config/zsh/plugins/platform.zsh    -- 平台特定 PATH 和别名
       source -> .config/zsh/plugins/zinit.zsh       -- Zinit 插件管理器
                    zinit 加载 -> p10k, fzf-tab, autosuggestions, syntax-hl
       source -> .config/zsh/plugins/double-esc-clear.zsh
       ...（PATH / 平台配置完成后）...
       source -> .config/zsh/plugins/age-tokens.zsh  -- age 加密令牌（依赖 PATH 已就绪）
       引用   -> .config/zsh/fzf/fzf-preview.sh      -- FZF_DEFAULT_OPTS 中引用
       引用   -> .config/ripgrep/config               -- $RIPGREP_CONFIG_PATH 引用

### 安装/卸载层（必须双向同步）

install.sh <-> uninstall.sh
  调用 -> scripts/install_dotfiles.sh     -- 配置文件符号链接部署
  调用 -> scripts/install_vscode_ext.sh   -- VSCode/Cursor 插件安装
  调用 -> scripts/install_claude_code.sh  -- Claude Code LSP/MCP/Skills/Hooks
  调用 -> scripts/install_pixi.sh         -- Pixi 包管理器（Linux）
  调用 -> scripts/install_kotlin_native.sh  -- Kotlin Native 工具链
  调用 -> scripts/macos_install.sh        -- Homebrew 包安装（macOS）
  依赖 -> lib/utils.sh                    -- 通用工具函数（颜色、日志、权限）
  依赖 -> lib/packages.sh                 -- Homebrew 包列表定义

### 应用配置层（相互独立，标注例外）

.config/kitty/          -- 独立（终端模拟器）
.config/Code/User/    <-> .config/Cursor/User/   -- 必须保持一致（settings.json, keybindings.json）
.config/ripgrep/        -- 被 .zshrc 通过 $RIPGREP_CONFIG_PATH 引用
.config/direnv/         -- 独立（direnv 配置）
.config/karabiner/      -- 独立，macOS only
.hammerspoon/           -- 独立，macOS only
.ssh/config             -- 独立（SSH 连接配置）
.gitconfig              -- 独立（Git 用户配置）

## 修改联动规则

修改任何文件前，必须对照以下规则检查是否需要同步修改关联文件：

1. install.sh 中增删组件 -> 必须同步 uninstall.sh 中对应的卸载逻辑
2. uninstall.sh 中增删卸载逻辑 -> 必须确认 install.sh 中有对应的安装逻辑
3. .zshenv 中修改/重命名变量 -> 检查 .zshrc、zinit.zsh、age-tokens.zsh 中的引用
4. .zshrc 中修改 source 路径或环境变量 -> 检查被 source 的文件是否存在且路径正确
5. .config/Code/User/settings.json 修改 -> 同步 .config/Cursor/User/settings.json
6. .config/Code/User/keybindings.json 修改 -> 同步 .config/Cursor/User/keybindings.json
7. lib/packages.sh 增删包 -> 检查是否有配置文件依赖该包（如 fzf、ripgrep、age）
8. scripts/install_*.sh 修改安装逻辑 -> 检查 install.sh 中的调用方式是否匹配
9. pixi.toml 增删依赖 -> 检查是否有 shell 配置引用该工具（PATH、别名、环境变量）
10. .config/zsh/plugins/ 下新增插件文件 -> 必须在 .zshrc 中添加 source 语句
11. 配置文件采用复制部署（非 symlink）-> 修改仓库源文件后必须同步复制到系统部署路径，反之亦然
