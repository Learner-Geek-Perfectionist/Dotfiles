# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
ORANGE='\033[0;93m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_BLUE='\033[1;34m'
DARK_RED='\033[1;31m'
NC='\033[0m' # 没有颜色

if [[ "$HISTFILE" != "$HOME/.cache/zsh/.zsh_history" ]]; then
	export HISTFILE="$HOME/.cache/zsh/.zsh_history"
	if [[ -f "$HOME/.cache/zsh/.zsh_history" ]]; then
		readonly HISTFILE
	fi
fi

if [[ "$ZSH_COMPDUMP" != "$HOME/.cache/zsh/.zcompdump" ]]; then
	export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump"
	if [[ -f "$HOME/.cache/zsh/.zcompdump" ]]; then
		readonly ZSH_COMPDUMP
	fi
fi

# 获取操作系统信息并设置 PATH
if [[ "$(uname)" == "Darwin" ]]; then
	# macOS specific settings，设置 git 、clang++、ruby、make bash、VSCode、gre、less 等工具的环境变量
	export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
	export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
	export PATH="/opt/homebrew/opt/git/bin:$PATH"
	export PATH="/opt/homebrew/opt/less/bin:$PATH"
	export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
	export PATH="/opt/homebrew/opt/bash/bin:$PATH"
	export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
	export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
	export PATH="/Applications/CLion.app/Contents/MacOS:$PATH"
	export PATH="/Applications/PyCharm.app/Contents/MacOS:$PATH"
	export PATH="/Applications/IntelliJ IDEA.app/Contents/MacOS:$PATH"
	export PATH="/opt/homebrew/anaconda3/bin:$PATH"
	export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
	export HOMEBREW_NO_ENV_HINTS=1
	# clion 映射到 cl
	alias cl=clion
	# pycharm 映射到 py
	alias py=pycharm
	alias rg='rg -uuu -i --threads=$(sysctl -n hw.ncpu)'
	alias open='open -R'

else
	alias rg='rg -uuu -i --threads=$(nproc)'
	# 加载 rust 的环境变量
	export CARGO_HOME=/opt/rust/cargo
	export RUSTUP_HOME=/opt/rust/rustup

fi

# 加载 homebrew 插件
[[ -x "${HOME}/.config/zsh/plugins/homebrew.zsh" ]] && source "$_" || echo "${RED}No ${HOME}/.config/zsh/plugins/homebrew.zsh${NC}"

# 加载 zinit 插件（修正错误路径）
[[ -x "${HOME}/.config/zsh/plugins/zinit.zsh" ]] && source "$_" || echo "${RED}No ${HOME}/.config/zsh/plugins/zinit.zsh${NC}"

# 自动启动 ssh-agent 并加载密钥
if [ -z "$SSH_AUTH_SOCK" ]; then
	# 检查是否已有 ssh-agent 进程
	eval $(ssh-agent -s >/dev/null 2>&1)
	# 加载默认私钥（替换为你的密钥路径，如 ~/.ssh/id_rsa）
	ssh-add ~/.ssh/id_rsa 2>/dev/null
fi

setopt interactive_comments # 注释行不报错
setopt no_nomatch           # 通配符 * 匹配不到文件也不报错
setopt nocaseglob           # 路径名匹配时忽略大小写
setopt notify               # 后台任务完成后通知
setopt no_beep              # 关闭终端提示音
setopt no_bang_hist         # 不对双引号当中的叹号做历史记录拓展 "!"
setopt GLOB_DOTS            # 文件名展开（globbing）包括以点(dot)开始的文件
setopt rm_star_silent       # 取消 zsh 的安全防护功能（默认对 rm -rf ./* 删除操作触发）

# 让 history 命令的最大容量为无限
export HISTSIZE=10000000
export HISTFILESIZE=10000000

# 加载 fzf 的环境变量
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

# 设置 fzf 的默认预览
export FZF_DEFAULT_OPTS='--preview "${HOME}/.config/zsh/fzf/fzf-preview.sh {}" --bind "shift-left:preview-page-up,shift-right:preview-page-down"'

export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --no-sort --tac"

export FZF_DEFAULT_COMMAND='fd -g -HIia -E /System/Volumes/Data -E '.Trash''

alias fd='fd -g -HIia -E /System/Volumes/Data -E '.Trash''

alias getip="$HOME/sh-script/get-my-ip.sh"

# 清除整个屏幕
alias clear='clear && printf '\''\e[3J'\'''

# python3 映射到 python
alias python=python3

# bat 映射到 cat
alias cat=bat

# reload 映射到重启 .zshrc
alias reload="source ~/.zshenv;source ~/.zprofile;source ~/.zshrc"

# 更新 zsh 配置
alias upgrade='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/update_dotfiles.sh?$(date +%s)")" && reload'

alias g1='git clone --depth=1'

alias mkdir='mkdir -p'

alias cp='cp -r'

alias show='kitty +kitten icat'

alias reboot='sudo reboot'
