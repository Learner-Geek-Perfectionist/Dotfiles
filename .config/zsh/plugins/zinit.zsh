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

# 设置 zinit 的 compdump 路径（zinit 不读取 ZSH_COMPDUMP，需要单独设置）
ZINIT[ZCOMPDUMP_PATH]="${ZSH_COMPDUMP:-$HOME/.cache/zsh/.zcompdump}"

# 1.Powerlevel10k 的 instant prompt 的缓存文件，用于加速启动
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh"
fi

# 2.加载 p10k 主题
zinit light romkatv/powerlevel10k

# 3.加载 p10k 主题的配置文件
[[ -f ~/.config/zsh/.p10k.zsh ]] && source ~/.config/zsh/.p10k.zsh

# =============================================
# ======== zsh-autocomplete 配置
# =============================================
# 必须在 compinit 和其他补全插件之前加载
# 文档：https://github.com/marlonrichert/zsh-autocomplete

# zsh-autocomplete 配置（在加载前设置）
zstyle ':autocomplete:*' delay 0.1  # 输入停止后 0.1 秒显示补全
zstyle ':autocomplete:*' min-input 1  # 至少输入 1 个字符才显示补全
zstyle ':autocomplete:*complete*:*' insert-unambiguous yes  # 先插入公共子串
zstyle ':autocomplete:*history*:*' insert-unambiguous yes
zstyle ':autocomplete:history-search-backward:*' list-lines 8  # 历史搜索显示行数
# 默认只对命令加空格，改成所有补全都加
zstyle ':autocomplete:*' add-space '*'

zinit ice depth=1
# 加载 zsh-autocomplete
zinit light marlonrichert/zsh-autocomplete

# =============================================
# ======== 补全系统颜色配置（必须在 zsh-autocomplete 之后）
# =============================================

# 设置 LS_COLORS（文件类型颜色，补全列表使用）
# 注意：不使用加粗(1;)，只用普通颜色，让分组标题的加粗更突出
# md=38;5;117(浅蓝) json=33(黄) 区分开
export LS_COLORS='di=34:ln=36:so=35:pi=33:ex=32:bd=33;40:cd=33;40:su=37;41:sg=30;43:tw=30;42:ow=34;42:*.tar=31:*.tgz=31:*.gz=31:*.zip=31:*.7z=31:*.rar=31:*.bz2=31:*.xz=31:*.jpg=35:*.jpeg=35:*.png=35:*.gif=35:*.webp=35:*.svg=35:*.mp3=36:*.mp4=36:*.mkv=36:*.avi=36:*.mov=36:*.pdf=38;5;208:*.doc=38;5;27:*.docx=38;5;27:*.xls=38;5;22:*.xlsx=38;5;22:*.ppt=38;5;166:*.pptx=38;5;166:*.md=38;5;117:*.txt=37:*.json=38;5;220:*.yaml=38;5;178:*.yml=38;5;178:*.toml=38;5;178:*.xml=33:*.html=38;5;166:*.css=38;5;39:*.js=38;5;220:*.ts=38;5;39:*.py=32:*.sh=32:*.zsh=32:*.bash=32:*.c=32:*.cpp=32:*.h=32:*.rs=38;5;208:*.go=38;5;39:*.java=38;5;136'

# 不同分组标题使用不同颜色（加粗 + 前面换行增加间距）
# 使用 %{...%} 包裹 ANSI 序列，告诉 zsh 这是非打印字符
# 38;5;N = 前景色 256色, 1 = 加粗, 0 = 重置
zstyle ':completion:*:*:*:*:directories' format $'\n%{\e[1;38;5;213m%}-- %d --%{\e[0m%}'
zstyle ':completion:*:*:*:*:files' format $'\n%{\e[1;38;5;114m%}-- %d --%{\e[0m%}'
zstyle ':completion:*:*:*:*:commands' format $'\n%{\e[1;38;5;220m%}-- %d --%{\e[0m%}'
zstyle ':completion:*:*:*:*:aliases' format $'\n%{\e[1;38;5;177m%}-- %d --%{\e[0m%}'
zstyle ':completion:*:*:*:*:functions' format $'\n%{\e[1;38;5;87m%}-- %d --%{\e[0m%}'
zstyle ':completion:*:*:*:*:parameters' format $'\n%{\e[1;38;5;87m%}-- %d --%{\e[0m%}'
zstyle ':completion:*:*:*:*:options' format $'\n%{\e[1;38;5;252m%}-- %d --%{\e[0m%}'
# 其他分组的默认颜色
zstyle ':completion:*:descriptions' format $'\n%{\e[1;38;5;75m%}-- %d --%{\e[0m%}'

# 无匹配时的提示颜色
zstyle ':completion:*:warnings' format '%F{red}%B-- no matches found --%b%f'
# 消息提示颜色
zstyle ':completion:*:messages' format '%F{yellow}%B-- %d --%b%f'

# 补全列表文件颜色（使用 LS_COLORS）
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# 目录优先显示
zstyle ':completion:*' list-dirs-first true


# =============================================
# ======== OMZ 迁移和插件配置
# =============================================
# clipboard
zinit ice wait lucid depth=1
zinit snippet OMZL::clipboard.zsh
# 注意：移除了 OMZL::completion.zsh，由 zsh-autocomplete 接管补全系统
# grep
zinit ice wait lucid depth=1
zinit snippet OMZL::grep.zsh
# key-bindings
# zinit ice wait lucid depth=1
# zinit snippet OMZL::key-bindings.zsh
# directories
zinit ice wait lucid depth=1
zinit snippet OMZL::directories.zsh
# history
zinit ice wait lucid depth=1 atload="unsetopt hist_ignore_all_dups hist_ignore_space"
zinit snippet OMZL::history.zsh
# theme
zinit ice wait lucid depth=1 atload="alias ls &>/dev/null && unalias ls && alias ls='eza --icons -ha --time-style=iso -g'"
zinit snippet OMZL::theme-and-appearance.zsh
# git
zinit ice wait lucid depth=1
zinit snippet OMZL::git.zsh
zinit ice wait lucid depth=1
zinit snippet OMZP::git/git.plugin.zsh
# man
zinit ice wait lucid depth=1
zinit snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

# 添加 _fzf 补全函数（fzf 命令行工具的补全，与 fzf-tab 无关）
zinit ice as"completion"
zinit snippet https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/master/.config/zsh/fzf/_fzf

# zsh-completions 提供大量的补全定义
zinit ice wait blockf lucid depth=1
zinit light zsh-users/zsh-completions

# autosuggestions，atload 用于保障启动 autosuggest 功能
zinit ice wait lucid depth=1 atload='!_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
# 必须在 zdharma-continuum/fast-syntax-highlighting 之前加载 autosuggestions，否则「粘贴代码」太亮了
zinit ice wait lucid depth=1
zinit light zdharma-continuum/fast-syntax-highlighting

# =============================================
# ======== zsh-autocomplete 按键绑定自定义
# =============================================
# Tab 和 Shift+Tab 直接进入菜单选择模式（类似 fzf-tab）
bindkey '^I' menu-select
bindkey "$terminfo[kcbt]" menu-select

# 在菜单中：Tab 向下移动，Shift+Tab 向上移动
bindkey -M menuselect '^I' menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete

# 在菜单中：Enter 只确认选择（插入补全），不执行命令
bindkey -M menuselect '\r' accept-search

# 在菜单中：← → 移动光标而不是选择（可选，取消注释启用）
# bindkey -M menuselect '^[[D' .backward-char '^[OD' .backward-char
# bindkey -M menuselect '^[[C' .forward-char '^[OC' .forward-char
