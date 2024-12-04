# =============================================
# ======== Zinit
# =============================================


# 检查 git 是否安装......
if ! command -v git &>/dev/null; then
  echo "git is not installed, zinit installation skipped."
  return
fi

# 插件管理器 zinit 安装的路径
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# 如果插件管理器 zinit 没有安装......
if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
  print -P "%F{33} %F{220}Installing ZDHARMA-CONTINUUM Initiative Plugin Manager...%f"
  sudo mkdir -p "$(dirname $ZINIT_HOME)" && sudo chmod g+rw "$(dirname $ZINIT_HOME)"
  if git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
    print -P "%F{33} %F{34}Installation successful.%f%b"
  else
    print -P "%F{160} The clone has failed.%f%b"
    return
  fi
fi

# 执行 zinit.zsh，加载 zinit 插件管理器本身，将 zinit 命令引入 zsh 中。
source "$ZINIT_HOME/zinit.zsh"

# 1.Powerlevel10k 的 instant prompt 的缓存文件，用于加速启动
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# 2.加载 p10k 主题
zinit light romkatv/powerlevel10k

# 3.加载 p10k 主题的配置文件
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

# General options for all plugins
HYPHEN_INSENSITIVE='true'
COMPLETION_WAITING_DOTS='true'


# OMZ 迁移和插件配置
# clipboard
zinit ice wait lucid depth=1;zinit snippet OMZL::clipboard.zsh
# completion
zinit ice wait lucid depth=1;zinit snippet OMZL::completion.zsh
# grep
zinit ice wait lucid depth=1;zinit snippet OMZL::grep.zsh
# key-bindings
zinit ice wait lucid depth=1;zinit snippet OMZL::key-bindings.zsh
# directories
zinit ice wait lucid depth=1;zinit snippet OMZL::directories.zsh
# history
zinit ice wait lucid depth=1;zinit snippet OMZL::history.zsh
# theme 
zinit ice wait lucid depth=1 atload="alias ls &>/dev/null && unalias ls && alias ls='eza --icons -h --time-style=iso'";zinit snippet OMZL::theme-and-appearance.zsh
# git
zinit ice wait lucid depth=1;zinit snippet OMZL::git.zsh
zinit ice wait lucid depth=1;zinit snippet OMZP::git/git.plugin.zsh
# man
zinit ice wait lucid depth=1;zinit snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh





# == fzf-tab setting
zstyle ':fzf-tab:complete:_zlua:*' query-string input
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:3:wrap'
zstyle ':fzf-tab:complete:kill:*' popup-pad 0 3
zstyle ':fzf-tab:complete:cd:*x' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:cd:*' popup-pad 30 0
zstyle ":fzf-tab:*" fzf-flags --color=bg+:23
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ":completion:*:git-checkout:*" sort false
zstyle ':completion:*' file-sort modification
zstyle ':completion:*:eza' sort false
zstyle ':completion:files' sort false

# 添加 _fzf 补全函数 
zinit ice as"completion"
zinit snippet https://github.com/Learner-Geek-Perfectionist/Dotfiles/blob/master/.config/zsh/completion/_fzf

# 1.make sure fzf is installed
# 2.fzf-tab needs to be loaded 「after」 compinit, but 「before」 plugins which will wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
# 3.Completions should be configured before compinit, as stated in the zsh-completions manual installation guide.

# zsh-completions 提供大量的补全定义
zinit ice wait blockf lucid depth=1;zinit light zsh-users/zsh-completions

# 设置插件加载的选项，加载 fzf-tab 插件
zinit ice atinit"autoload -Uz compinit; compinit -C -d \"$ZSH_COMPDUMP\"; zpcdreplay" wait lucid depth=1;zinit light Aloxaf/fzf-tab

# autosuggestions，atload 用于保障启动 autosuggest 功能。
zinit ice wait lucid depth=1 atload='_zsh_autosuggest_start';zinit light zsh-users/zsh-autosuggestions
# 必须在 zdharma-continuum/fast-syntax-highlighting 之前加载 autosuggestions，否则「粘贴代码」太亮了。
zinit ice wait lucid depth=1;zinit light zdharma-continuum/fast-syntax-highlighting



# 你提供的这些 zstyle 命令是用来配置 Zsh 的样式和行为，特别是与 fzf-tab 插件和其他一些补全相关的设置相结合。fzf-tab 插件是一个用于在 Zsh 中使用 fzf（一种命令行模糊查找器）增强标签补全功能的工具。这些命令定制了如何显示和处理不同命令的补全结果。下面是对每一行设置的解释：
# 	1.	zstyle ‘:fzf-tab:complete:_zlua:*’ query-string input
# 	•	这条命令为 _zlua （可能是一个命令或函数）设置补全时的查询字符串为用户的输入。
# 	2.	zstyle ‘:fzf-tab:complete:kill:argument-rest’ fzf-preview ‘ps –pid=$word -o cmd –no-headers -w -w’
# 	•	对于 kill 命令的补全，设置一个预览窗口来显示每个进程 ID 的命令行详情。$word 是当前选定的候选词。
# 	3.	zstyle ‘:fzf-tab:complete:kill:argument-rest’ fzf-flags ‘–preview-window=down:3:wrap’
# 	•	设置 kill 命令的 fzf 预览窗口的样式，使其显示在下方、高度为 3 行，并允许文本换行。
# 	4.	zstyle ‘:fzf-tab:complete:kill:*’ popup-pad 0 3
# 	•	设置 kill 命令的弹出补全菜单的内边距为上下 0 行、左右 3 字符。
# 	5.	zstyle ‘:fzf-tab:complete:cd:*’ fzf-preview ‘eza -1 –color=always $realpath’
# 	•	对于 cd 命令的补全，设置一个预览窗口来显示 eza 命令（一个现代化的 ls 替代品）的输出，其中 $realpath 是补全候选的实际路径。
# 	6.	zstyle ‘:fzf-tab:complete:cd:*’ popup-pad 30 0
# 	•	设置 cd 命令的弹出补全菜单的内边距为上下 30 行、左右 0 字符。
# 	7.	zstyle “:fzf-tab:*” fzf-flags –color=bg+:23
# 	•	为所有 fzf-tab 的 fzf 调用设置背景颜色。
# 	8.	zstyle ‘:fzf-tab:*’ fzf-command ftb-tmux-popup
# 	•	为 fzf-tab 设置一个定制的 fzf 命令，这里指定为 ftb-tmux-popup，可能是一个脚本或函数来在 tmux 中显示 fzf。
# 	9.	zstyle ‘:fzf-tab:*’ switch-group ‘,’ ‘.’
# 	•	设置在 fzf-tab 补全中切换候选组的键为 , 和 .。
# 	10.	zstyle “:completion::git-checkout:” sort false
# 	•	禁用对 git checkout 命令的补全结果排序。
# 	11.	zstyle ‘:completion:*’ file-sort modification
# 	•	设置文件补全的排序方式为按修改时间。
# 	12.	zstyle ‘:completion:*:eza’ sort false
# 	•	禁用对 eza 命令的补全结果排序。
# 	13.	zstyle ‘:completion:files’ sort false
# 	•	禁用对文件补全结果的排序。

# 这些配置帮助提高 Zsh 使用效率，使得命令行界面更加强大和灵活。
