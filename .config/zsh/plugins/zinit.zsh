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

zinit ice depth=1
# 加载 zsh-autocomplete
zinit light marlonrichert/zsh-autocomplete

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
zinit ice wait lucid depth=1
zinit snippet OMZL::key-bindings.zsh
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
# ======== zsh-autocomplete 按键绑定自定义（可选）
# =============================================
# 如果需要自定义按键，可以在这里添加，例如：
# bindkey '^I' menu-select  # Tab 直接进入菜单选择
# bindkey -M menuselect '^I' menu-complete  # 在菜单中 Tab 移动选择
# bindkey -M menuselect '\r' .accept-line  # Enter 直接提交命令
