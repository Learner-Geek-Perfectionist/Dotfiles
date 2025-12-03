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
	export PATH="/Applications/Cursor.app/Contents/Resources/app/bin:$PATH"
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
	# Cursor 编辑器
	[[ -d "/opt/Cursor/resources/app/bin" ]] && export PATH="/opt/Cursor/resources/app/bin:$PATH"

	# OrbStack Linux 支持 open 命令打开 macOS Finder
	if [[ -n "$ORBSTACK" ]] && command -v open >/dev/null 2>&1; then
		alias open='open -R'
	fi

	# Pixi 路径（Linux 包管理）
	export PATH="$HOME/.pixi/bin:$PATH"
fi

# 加载平台配置插件
[[ -f "${HOME}/.config/zsh/plugins/platform.zsh" ]] && source "${HOME}/.config/zsh/plugins/platform.zsh" || echo "${RED}No ${HOME}/.config/zsh/plugins/platform.zsh${NC}"

# 加载 zinit 插件
[[ -f "${HOME}/.config/zsh/plugins/zinit.zsh" ]] && source "${HOME}/.config/zsh/plugins/zinit.zsh" || echo "${RED}No ${HOME}/.config/zsh/plugins/zinit.zsh${NC}"

# 自动启动 ssh-agent 并加载密钥
if [[ -z "$SSH_AUTH_SOCK" ]]; then
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

# 加载 fzf 的环境变量
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

# bat 映射到 cat（检查命令是否存在）
command -v bat >/dev/null 2>&1 && alias cat=bat

# tldr 替代 man（更简洁的命令手册，检查命令是否存在）
command -v tldr >/dev/null 2>&1 && alias man='tldr'

# 让 history 命令的最大容量为无限
export HISTSIZE=10000000
export HISTFILESIZE=10000000

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

# reload 映射到重启 .zshrc
alias reload="source ~/.zshenv;source ~/.zprofile;source ~/.zshrc"

# 更新 zsh 配置
alias upgrade='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/update_dotfiles.sh?$(date +%s)")" && reload'

# 卸载 dotfiles
alias uninstall='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/uninstall_dotfiles.sh?$(date +%s)")"'

alias g1='git clone --depth=1'

alias mkdir='mkdir -p'

alias cp='cp -r'

alias show='kitty +kitten icat'

alias reboot='sudo reboot'
