#!/bin/zsh

# 专门用于安装 zinit 插件的脚本

# 插件管理器 zinit 安装的路径
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"

# 异步加载控制函数
# ZINIT_SYNC=1 时同步加载（安装脚本用），否则使用 turbo 模式
_ice() {
	if [[ -n "$ZINIT_SYNC" ]]; then
		zinit ice depth=1 "$@"
	else
		zinit ice wait lucid depth=1 "$@"
	fi
}

# 如果插件管理器 zinit 没有安装......
if [[ ! -f "${ZINIT_HOME}/zinit.zsh" ]]; then
	printf "\033[33m\033[220mInstalling ZDHARMA-CONTINUUM Initiative Plugin Manager...\033[0m\n"
	if git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
		printf "\033[33m\033[34mInstallation successful.\033[0m\n"
	else
		printf "\033[160mThe clone has failed.\033[0m\n"
		return
	fi
fi

# 执行 zinit.zsh，加载 zinit 插件管理器本身，将 zinit 命令引入 zsh 中。
source "${ZINIT_HOME}/zinit.zsh"

# 设置 zinit 的 compdump 路径（zinit 不读取 ZSH_COMPDUMP，需要单独设置）
ZINIT[ZCOMPDUMP_PATH]="${ZSH_COMPDUMP:-$HOME/.cache/zsh/.zcompdump}"

# 1.Powerlevel10k 的 instant prompt 的缓存文件，用于加速启动
# ZINIT_SYNC=1 时跳过（安装模式下 instant prompt 会导致 macOS script 命令卡住）
if [[ -z "$ZINIT_SYNC" && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh"
fi

# 2.加载 p10k 主题
zinit light romkatv/powerlevel10k

# 3.加载 p10k 主题的配置文件
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

# General options for all plugins
HYPHEN_INSENSITIVE='true'
COMPLETION_WAITING_DOTS='true'

# OMZ 精简插件配置（移除 clipboard/grep/completion/history/theme/colored-man-pages）
# 保留：key-bindings, directories, git

# key-bindings: 键盘快捷键
_ice
zinit snippet OMZL::key-bindings.zsh

# directories: 目录导航（d / cd 增强）
_ice atload'setopt no_auto_cd'
zinit snippet OMZL::directories.zsh

# git: git 别名和函数
_ice
zinit snippet OMZL::git.zsh
_ice
zinit snippet OMZP::git/git.plugin.zsh

# 内联原 OMZL::history.zsh 的必要设置（HIST* 变量已在 .zshrc 开头重设）
setopt extended_history         # 记录命令时间戳
setopt hist_expire_dups_first   # 历史满时优先删除重复
setopt hist_ignore_dups         # 不记录重复命令
setopt hist_verify              # 展开历史后让用户确认再执行
setopt share_history            # 多终端共享历史
# history 命令显示全部历史（zsh 内置只显示最近 16 条）
alias history='fc -l 1'

# 内联原 OMZL::theme-and-appearance.zsh 的 eza 别名
(( $+commands[eza] )) && alias ls="eza --icons -ha --time-style=iso"

# 1.make sure fzf is installed
# 2.fzf-tab needs to be loaded 「after」 compinit, but 「before」 plugins which will wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
# 3.Completions should be configured before compinit, as stated in the zsh-completions manual installation guide.

# 设置插件加载的选项，加载 fzf-tab 插件
_ice atinit'
    autoload -Uz compinit
    local zcd="${ZSH_COMPDUMP:-$HOME/.cache/zsh/.zcompdump}"
    # 检查是否有 FPATH 目录比缓存更新
    local need_update=0
    if [[ -f "$zcd" ]]; then
        for dir in ${(s.:.)FPATH}; do
            [[ -d "$dir" && "$dir" -nt "$zcd" ]] && { need_update=1; break }
        done
    fi
    # 缓存不存在或过期时完整扫描，否则用快速模式
    if [[ ! -f "$zcd" || $need_update -eq 1 ]]; then
        compinit -d "$zcd"
    else
        compinit -C -d "$zcd"
    fi
    zicdreplay
'
zinit light Aloxaf/fzf-tab

# 配置 fzf-tab
zstyle ':fzf-tab:complete:_zlua:*' query-string input
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps -p $word -o comm= 2>/dev/null'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:15:wrap'
zstyle ':fzf-tab:complete:kill:*' popup-pad 0 3
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:cd:*' popup-pad 30 0
zstyle ':fzf-tab:complete:code:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:code:*' popup-pad 30 0
zstyle ":fzf-tab:*" fzf-flags --color=bg+:23
zstyle ':fzf-tab:*' switch-group '<' '>'

# ============================================
# 修复 Fedora zsh 补全兼容性问题
# ============================================
# 问题：输入 `fast<Tab>` 时自动变成 `fast-`，导致 `fastfetch` 不显示
#
# 根本原因：
#   1. OMZL::completion.zsh 设置的 matcher-list 包含 `-_` 等价规则：
#      'm:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}'
#      这使得 `-` 和 `_` 被视为相同字符
#
#   2. Fedora 的 zsh 包中 `_path_commands` 函数是精简版（仅 4 行），
#      而 Ubuntu 是完整版（65 行）。精简版在处理补全时，
#      与 `-_` 等价规则结合会产生异常行为：
#      - `fast` 匹配 `FAST_*` 变量（大小写不敏感 + `_`=`-`）
#      - 补全系统认为 `fast-` 是"共同前缀"，自动插入 `-`
#      - 导致 `fastfetch` 被过滤掉
#
# 解决方案：移除 `-_` 等价性，只保留大小写不敏感
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'

# 添加 _fzf 补全函数（使用本地文件）
zinit ice as"completion"
zinit snippet "$HOME/.config/zsh/fzf/_fzf"

# zsh-completions 提供大量的补全定义
_ice blockf
zinit light zsh-users/zsh-completions

# autosuggestions，atload 用于保障启动 autosuggest 功能。
_ice atload'!_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 必须在 zdharma-continuum/fast-syntax-highlighting 之前加载 autosuggestions，否则「粘贴代码」太亮了。
_ice
zinit light zdharma-continuum/fast-syntax-highlighting
