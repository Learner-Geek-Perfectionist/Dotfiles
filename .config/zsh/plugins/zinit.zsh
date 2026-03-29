#!/bin/zsh

# 专门用于安装 zinit 插件的脚本

# 插件管理器 zinit 安装的路径
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"

# 异步加载控制函数
# ZINIT_SYNC=1 时同步加载（安装脚本用），否则使用 turbo 模式
_ice() {
	if [[ -n "$ZINIT_SYNC" ]]; then
		zinit ice depth=1 "${@:#wait*}"  # 同步模式：移除 wait 参数，其余保留
	else
		zinit ice lucid depth=1 "$@"  # turbo 模式：wait 值由调用方指定
	fi
}

# 如果插件管理器 zinit 没有安装......
if [[ ! -f "${ZINIT_HOME}/zinit.zsh" ]]; then
	printf "\033[33mInstalling ZDHARMA-CONTINUUM Initiative Plugin Manager...\033[0m\n"
	if git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
		printf "\033[34mInstallation successful.\033[0m\n"
	else
		printf "\033[31mThe clone has failed.\033[0m\n"
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

# 上下箭头：按已输入前缀搜索历史（替代 OMZL::key-bindings.zsh）
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# 内联原 OMZL::history.zsh 的必要设置（HIST* 变量已在 .zshrc 开头重设）
# setopt extended_history 已在 .zshenv 中设置，此处不重复
setopt hist_expire_dups_first   # 历史满时优先删除重复
setopt hist_ignore_dups         # 不记录重复命令
setopt hist_verify              # 展开历史后让用户确认再执行
setopt share_history            # 多终端共享历史
# history 命令显示全部历史（zsh 内置只显示最近 16 条）
alias history='fc -l 1'

# 内联原 OMZL::theme-and-appearance.zsh 的 eza 别名
if (( $+commands[eza] )); then
	alias ls="eza --icons -ha --time-style=iso"
	alias ll="eza --icons -ha --long --time-style=iso"
fi

# ============================================
# Turbo 异步加载（prompt 显示后按优先级加载）
# ============================================
# 排序约束：
#   0a: 补全定义 → 0b: compinit + fzf-tab → 0c: 功能插件 → 0d: autosuggestions
#   F-Sy-H(0c) 必须在 autosuggestions(0d) 之前：
#     F-Sy-H source 时绑定 widget 一次；autosuggestions 后加载直接包在外层，
#     产生干净的 autosuggest → fsh → 原始 调用链，无冗余包装层。

# ── wait'0a'：补全定义层（为 compinit 准备 FPATH）──

_ice wait'0a' as"completion"
zinit snippet "$HOME/.config/zsh/fzf/_fzf"

_ice wait'0a' blockf  # blockf: 阻止插件修改 FPATH（由 zinit 统一管理）
zinit light zsh-users/zsh-completions

# ── wait'0b'：补全系统激活 ──

_ice wait'0b' atinit'
    # 补全 matcher：移除 -_ 等价性，只保留大小写不敏感（修复 Fedora 兼容性）
    zstyle ":completion:*" matcher-list "m:{[:lower:][:upper:]}={[:upper:][:lower:]}" "r:|=*" "l:|=* r:|=*"
    autoload -Uz compinit
    local zcd="${ZSH_COMPDUMP:-$HOME/.cache/zsh/.zcompdump}"
    local need_update=0
    if [[ -f "$zcd" ]]; then
        for dir in ${(s.:.)FPATH}; do
            [[ -d "$dir" && "$dir" -nt "$zcd" ]] && { need_update=1; break }
        done
    fi
    if [[ ! -f "$zcd" || $need_update -eq 1 ]]; then
        compinit -d "$zcd"
    else
        compinit -C -d "$zcd"
    fi
    zicdreplay
' atload'
    zstyle ":fzf-tab:complete:_zlua:*" query-string input
    zstyle ":fzf-tab:complete:kill:argument-rest" fzf-preview "ps -p \$word -o comm= 2>/dev/null"
    zstyle ":fzf-tab:complete:kill:argument-rest" fzf-flags "--preview-window=down:15:wrap"
    zstyle ":fzf-tab:complete:kill:*" popup-pad 0 3
    zstyle ":fzf-tab:complete:cd:*" fzf-preview "eza -1 --color=always \$realpath"
    zstyle ":fzf-tab:complete:cd:*" popup-pad 30 0
    zstyle ":fzf-tab:complete:code:*" fzf-preview "eza -1 --color=always \$realpath"
    zstyle ":fzf-tab:complete:code:*" popup-pad 30 0
    zstyle ":fzf-tab:*" fzf-flags --color=bg+:23
    zstyle ":fzf-tab:*" switch-group "<" ">"
'
zinit light Aloxaf/fzf-tab

# ── wait'0c'：功能插件层 ──

# OMZP::git 的别名（ggpush, gpsup 等）依赖此函数，原定义在 OMZL::git.zsh 中
git_current_branch() {
	local ref
	ref=$(command git symbolic-ref --quiet HEAD 2>/dev/null) || return
	echo ${ref#refs/heads/}
}

_ice wait'0c'
zinit snippet OMZP::git/git.plugin.zsh

_ice wait'0c' atload'FAST_HIGHLIGHT[chroma-which]="→chroma/-precommand.ch"'
zinit light zdharma-continuum/fast-syntax-highlighting

# ── wait'0d'：自动建议（最外层 widget 包装）──

_ice wait'0d' atload'!_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 清理：_ice 仅在 zinit.zsh 加载期间使用
unfunction _ice  # 删除辅助函数，防止泄漏到用户的全局命名空间
