#!/bin/zsh

# =============================================
# ======== 安装并且加载 Zinit 插件管理器
# =============================================

# General options for all plugins
HYPHEN_INSENSITIVE='true'
COMPLETION_WAITING_DOTS='true'

# 插件管理器 zinit 安装的路径
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"

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

# 1.Powerlevel10k 的 instant prompt 的缓存文件，用于加速启动
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh"
fi

# 2.加载 p10k 主题
zinit light romkatv/powerlevel10k

# 3.加载 p10k 主题的配置文件
[[ -f ~/.config/zsh/.p10k.zsh ]] && source ~/.config/zsh/.p10k.zsh

# OMZ 迁移和插件配置
# clipboard
zinit ice wait lucid depth=1
zinit snippet OMZL::clipboard.zsh
# completion
zinit ice wait lucid depth=1
zinit snippet OMZL::completion.zsh
# grep
zinit ice wait lucid depth=1
zinit snippet OMZL::grep.zsh
# key-bindings
zinit ice wait lucid depth=1
zinit snippet OMZL::key-bindings.zsh
# directories
zinit ice wait lucid depth=1
zinit snippet OMZL::directories.zsh
# history
zinit ice wait lucid depth=1 atload="unsetopt hist_ignore_all_dups hist_ignore_space"
zinit snippet OMZL::history.zsh
# theme
zinit ice wait lucid depth=1 atload="alias ls &>/dev/null && unalias ls; command -v eza &>/dev/null && alias ls='eza --icons -ha --time-style=iso -g'"
zinit snippet OMZL::theme-and-appearance.zsh
# git
zinit ice wait lucid depth=1
zinit snippet OMZL::git.zsh
zinit ice wait lucid depth=1
zinit snippet OMZP::git/git.plugin.zsh
# man
zinit ice wait lucid depth=1
zinit snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

# 1.make sure fzf is installed
# 2.fzf-tab needs to be loaded 「after」 compinit, but 「before」 plugins which will wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
# 3.Completions should be configured before compinit, as stated in the zsh-completions manual installation guide.

# 设置插件加载的选项，加载 fzf-tab 插件
zinit ice atinit"autoload -Uz compinit; compinit -C -d \"$ZSH_COMPDUMP\"; zicdreplay" wait lucid depth=1
zinit light Aloxaf/fzf-tab

# 配置 fzf-tab
zstyle ':fzf-tab:complete:_zlua:*' query-string input
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps --pid=$word -o cmd --no-headers -w'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:15:wrap'
zstyle ':fzf-tab:complete:kill:*' popup-pad 0 3
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:cd:*' popup-pad 30 0
zstyle ':fzf-tab:complete:code:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:code:*' popup-pad 30 0
zstyle ":fzf-tab:*" fzf-flags --color=bg+:23
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:*' switch-group '<' '>'

# 添加 _fzf 补全函数
zinit ice as"completion"
zinit snippet https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/master/.config/zsh/fzf/_fzf

# zsh-completions 提供大量的补全定义
zinit ice wait blockf lucid depth=1
zinit light zsh-users/zsh-completions

# autosuggestions，atload 用于保障启动 autosuggest 功能。
zinit ice wait lucid depth=1 atload='!_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
# 必须在 zdharma-continuum/fast-syntax-highlighting 之前加载 autosuggestions，否则「粘贴代码」太亮了。
zinit ice wait lucid depth=1
zinit light zdharma-continuum/fast-syntax-highlighting
