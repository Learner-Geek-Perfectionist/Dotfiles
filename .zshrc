# ============================================
# Zsh 配置文件
# ============================================

# ============================================
# 1. 基础设置
# ============================================

# 历史记录
export HISTFILE="$HOME/.cache/zsh/.zsh_history"
export HISTSIZE=10000000
export HISTFILESIZE=10000000

# Zsh 选项
setopt interactive_comments # 注释行不报错
setopt no_nomatch           # 通配符 * 匹配不到文件也不报错
setopt nocaseglob           # 路径名匹配时忽略大小写
setopt notify               # 后台任务完成后通知
setopt no_beep              # 关闭终端提示音
setopt no_bang_hist         # 不对双引号当中的叹号做历史记录拓展 "!"
setopt GLOB_DOTS            # 文件名展开包括点文件
setopt rm_star_silent       # 取消 rm -rf ./* 安全提示

# ============================================
# 2. 平台检测与 PATH 配置
# ============================================

# 缓存 CPU 核心数（避免每次执行命令都调用）
if [[ -z "$_NCPU" ]]; then
	if [[ "$(uname)" == "Darwin" ]]; then
		_NCPU=$(sysctl -n hw.ncpu)
	else
		_NCPU=$(nproc 2>/dev/null || echo 4)
	fi
fi

if [[ "$(uname)" == "Darwin" ]]; then
	# ========================================
	# macOS 配置
	# ========================================

	# Homebrew 工具路径
	export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
	export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
	export PATH="/opt/homebrew/opt/git/bin:$PATH"
	export PATH="/opt/homebrew/opt/less/bin:$PATH"
	export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
	export PATH="/opt/homebrew/opt/bash/bin:$PATH"
	export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
	export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
	export PATH="/opt/homebrew/anaconda3/bin:$PATH"

	# 应用程序路径
	export PATH="/Applications/Cursor.app/Contents/Resources/app/bin:$PATH"
	export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
	export PATH="/Applications/CLion.app/Contents/MacOS:$PATH"
	export PATH="/Applications/PyCharm.app/Contents/MacOS:$PATH"
	export PATH="/Applications/IntelliJ IDEA.app/Contents/MacOS:$PATH"

	export HOMEBREW_NO_ENV_HINTS=1

	# macOS 专属别名
	alias cl=clion
	alias py=pycharm
	alias open='open -R'

else
	# ========================================
	# Linux 配置
	# ========================================

	# Pixi 路径
	export PATH="$HOME/.pixi/bin:$PATH"

	# Cursor 编辑器
	[[ -d "/opt/Cursor/resources/app/bin" ]] && export PATH="/opt/Cursor/resources/app/bin:$PATH"

	# OrbStack 支持
	if [[ -n "$ORBSTACK" ]] && command -v open >/dev/null 2>&1; then
		alias open='open -R'
	fi
fi

# ============================================
# 3. 插件加载
# ============================================

# 颜色定义（仅用于错误提示）
_RED='\033[0;31m'
_NC='\033[0m'

# 加载平台配置插件
if [[ -f "${HOME}/.config/zsh/plugins/platform.zsh" ]]; then
	source "${HOME}/.config/zsh/plugins/platform.zsh"
else
	echo "${_RED}未找到 ${HOME}/.config/zsh/plugins/platform.zsh${_NC}"
fi

# 加载 zinit 插件
if [[ -f "${HOME}/.config/zsh/plugins/zinit.zsh" ]]; then
	source "${HOME}/.config/zsh/plugins/zinit.zsh"
else
	echo "${_RED}未找到 ${HOME}/.config/zsh/plugins/zinit.zsh${_NC}"
fi

# 加载 fzf
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

# ============================================
# 4. SSH Agent（复用已有进程）
# ============================================

_ssh_agent_env="$HOME/.ssh/agent.env"

_start_ssh_agent() {
	eval "$(ssh-agent -s)" >/dev/null
	echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK; export SSH_AGENT_PID=$SSH_AGENT_PID" >"$_ssh_agent_env"
	chmod 600 "$_ssh_agent_env"
}

if [[ -z "$SSH_AUTH_SOCK" ]]; then
	if [[ -f "$_ssh_agent_env" ]]; then
		source "$_ssh_agent_env" >/dev/null
		# 检查 agent 进程是否存活
		kill -0 "$SSH_AGENT_PID" 2>/dev/null || _start_ssh_agent
	else
		_start_ssh_agent
	fi
fi

# 加载密钥（如果尚未加载）
ssh-add -l >/dev/null 2>&1 || ssh-add ~/.ssh/id_rsa 2>/dev/null

unset _ssh_agent_env
unfunction _start_ssh_agent 2>/dev/null

# ============================================
# 5. 工具配置
# ============================================

# fd 和 fzf 统一参数（平台差异处理）
if [[ "$(uname)" == "Darwin" ]]; then
	_FD_OPTS='-g -HIia -E /System/Volumes/Data -E .Trash'
else
	_FD_OPTS='-g -HIia -E .Trash-*'
fi
export FZF_DEFAULT_COMMAND="fd $_FD_OPTS"
export FZF_DEFAULT_OPTS='--preview "${HOME}/.config/zsh/fzf/fzf-preview.sh {}" --bind "shift-left:preview-page-up,shift-right:preview-page-down" --no-sort --tac'

alias fd="fd $_FD_OPTS"
alias rg="rg -uuu -i --threads=$_NCPU"

unset _FD_OPTS

# ============================================
# 6. 别名定义
# ============================================

# --- 文件操作 ---
alias mkdir='mkdir -p'
alias cp='cp -r'
alias clear='clear && printf '\''\e[3J'\'''

# --- 开发工具 ---
alias python=python3
alias cat=bat
alias man='tldr'
alias show='kitty +kitten icat'

# --- Git ---
alias g1='git clone --depth=1'

# --- 系统管理 ---
alias reload="source ~/.zshenv; source ~/.zprofile; source ~/.zshrc"
alias reboot='sudo reboot'
alias getip="$HOME/sh-script/get-my-ip.sh"

# --- Dotfiles 管理 ---
alias upgrade='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/update_dotfiles.sh?$(date +%s)")" && reload'
alias uninstall='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/uninstall_dotfiles.sh?$(date +%s)")"'

# ============================================
# 清理临时变量
# ============================================
unset _RED _NC
