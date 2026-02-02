# ============================================
# 终端环境初始化
# ============================================

# 确保 TERM 有值（空或 dumb 时设置默认值）
[[ -z "$TERM" || "$TERM" == "dumb" ]] && export TERM="xterm-256color"

# Kitty 终端 SSH 时回退 TERM（远程服务器可能没有 xterm-kitty terminfo）
[[ "$TERM" == "xterm-kitty" && ! -e "/usr/share/terminfo/x/xterm-kitty" ]] && export TERM="xterm-256color"

# SSH 会话 locale 回退（避免远程服务器没有安装本地 locale 导致乱码）
# 场景：macOS SSH 发送 LANG=zh_CN.UTF-8，但远程 Linux 没有安装该 locale
if [[ -n "$SSH_CONNECTION" ]] && locale 2>&1 | command grep -q "Cannot set"; then
    export LANG="C.UTF-8"
    export LC_ALL="C.UTF-8"
fi

# ripgrep 全局配置（包含忽略文件设置）
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"

# 让 p10k instant prompt / 补全尽早生效
export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump"
command mkdir -p "${ZSH_COMPDUMP:h}" 2>/dev/null
[[ -f "${HOME}/.config/zsh/plugins/platform.zsh" ]] && source "${HOME}/.config/zsh/plugins/platform.zsh"
[[ -f "${HOME}/.config/zsh/plugins/zinit.zsh" ]] && source "${HOME}/.config/zsh/plugins/zinit.zsh"

# ============================================
# PATH 管理
# ============================================

# PATH 添加函数（避免重复添加）
path_prepend() {
	[[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]] && export PATH="$1:$PATH"
}

# ============================================
# 平台特定配置
# ============================================

if [[ "$(uname)" == "Darwin" ]]; then
	# macOS specific settings，设置 git 、clang++、ruby、make bash、VSCode、gre、less 等工具的环境变量
	path_prepend "/opt/homebrew/opt/llvm/bin"
	path_prepend "/opt/homebrew/opt/ruby/bin"
	path_prepend "/opt/homebrew/opt/git/bin"
	path_prepend "/opt/homebrew/opt/less/bin"
	path_prepend "/opt/homebrew/opt/make/libexec/gnubin"
	path_prepend "/opt/homebrew/opt/bash/bin"
	path_prepend "/opt/homebrew/opt/grep/libexec/gnubin"
	path_prepend "/Applications/Cursor.app/Contents/Resources/app/bin"
	path_prepend "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
	path_prepend "/Applications/CLion.app/Contents/MacOS"
	path_prepend "/Applications/PyCharm.app/Contents/MacOS"
	path_prepend "/Applications/IntelliJ IDEA.app/Contents/MacOS"
	path_prepend "/opt/homebrew/anaconda3/bin"
	path_prepend "/opt/homebrew/opt/openjdk/bin"
	export HOMEBREW_NO_ENV_HINTS=1
	# clion 映射到 cl
	alias cl=clion
	# pycharm 映射到 py
	alias py=pycharm
	# rg 配置已移至 ~/.config/ripgrep/config
	alias open='open -R'

else
	# rg 配置已移至 ~/.config/ripgrep/config

	# Cursor 编辑器（Linux）- 先添加，确保 cursor 命令可用
	path_prepend "/opt/Cursor/resources/app/bin"

	# VSCode 编辑器（Linux）- 后添加，确保 code 命令指向 VSCode 而非 Cursor
	path_prepend "/opt/visual-studio-code/bin"

	# Pixi + direnv：进入/离开目录自动加载/卸载环境变量
	path_prepend "$HOME/.pixi/bin"
	# 先激活 home 的 pixi 环境，确保 direnv 等工具可用
	path_prepend "$HOME/.pixi/envs/default/bin"
	command -v direnv >/dev/null && eval "$(direnv hook zsh)"

	# OrbStack Linux 支持 open 命令打开 macOS Finder
	[[ -d "/opt/orbstack-guest" ]] && command -v open &>/dev/null && alias open='open -R'
fi

# SSH Agent 配置
# ============================================
# 测试 Agent 是否生效：
#   echo $SSH_AUTH_SOCK          # 查看 socket 路径
#   ssh-add -l                   # 列出已加载的公钥指纹
#   ssh -T git@github.com        # 测试 GitHub 认证
#
# Docker 容器使用 Agent Forwarding：
#   docker run -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent ...
# ============================================

# 密钥路径 & 指纹
typeset -g _ssh_key="$HOME/.ssh/id_ed25519"
typeset -g _ssh_fp=$(ssh-keygen -lf "$_ssh_key.pub" 2>/dev/null | awk '{print $2}')

if [[ -f "$_ssh_key" && -n "$_ssh_fp" ]]; then
	# SSH 转发场景：agent 可用则复用，不覆盖
	if [[ -n "$SSH_CONNECTION" && -n "$SSH_AUTH_SOCK" ]] && ssh-add -l &>/dev/null; ret=$?; (( ret <= 1 )); then
		ssh-add -l 2>/dev/null | grep -qF "$_ssh_fp" || ssh-add "$_ssh_key" 2>/dev/null

	# macOS：launchd 自动管理
	elif [[ "$(uname)" == "Darwin" && -n "$SSH_AUTH_SOCK" ]] && ssh-add -l &>/dev/null; ret=$?; (( ret <= 1 )); then
		ssh-add -l 2>/dev/null | grep -qF "$_ssh_fp" || ssh-add "$_ssh_key" 2>/dev/null

	# Linux 本地
	elif [[ "$(uname)" == "Linux" ]]; then
		typeset -g _sock="$HOME/.ssh/agent.sock"
		# 尝试复用现有 socket
		[[ -S "$_sock" ]] && export SSH_AUTH_SOCK="$_sock"
		# agent 不可用则启动新的
		if ! { [[ -n "$SSH_AUTH_SOCK" ]] && ssh-add -l &>/dev/null; ret=$?; (( ret <= 1 )); }; then
			rm -f "$_sock" 2>/dev/null
			eval "$(ssh-agent -a "$_sock" 2>/dev/null)"
		fi
		ssh-add -l 2>/dev/null | grep -qF "$_ssh_fp" || ssh-add "$_ssh_key" 2>/dev/null
		unset _sock
	fi
fi

unset _ssh_key _ssh_fp 2>/dev/null

# ============================================
# Zsh 选项
# ============================================
setopt interactive_comments # 注释行不报错
setopt no_nomatch           # 通配符 * 匹配不到文件也不报错
setopt nocaseglob           # 路径名匹配时忽略大小写
setopt notify               # 后台任务完成后通知
setopt no_beep              # 关闭终端提示音
setopt no_bang_hist         # 不对双引号当中的叹号做历史记录拓展 "!"
setopt GLOB_DOTS            # 文件名展开（globbing）包括以点(dot)开始的文件
setopt rm_star_silent       # 取消 zsh 的安全防护功能（默认对 rm -rf ./* 删除操作触发）

# ============================================
# Fzf 配置
# ============================================
# 加载 fzf 快捷键（Ctrl+T, Ctrl+R, Alt+C），但保留 fzf-tab 的 Tab 补全
if command -v fzf >/dev/null 2>&1; then
	source <(fzf --zsh)
	# 恢复 fzf-tab 的 Tab 绑定（fzf --zsh 会覆盖为 fzf-completion）
	bindkey '^I' fzf-tab-complete
fi

# ============================================
# 命令增强
# ============================================

# bat 映射到 cat
if command -v bat >/dev/null 2>&1; then
	# cat：默认用 bat；若文件本身包含 ANSI 转义序列(ESC=0x1b)，则回退到系统 cat 以便终端渲染颜色
	cat() {
		emulate -L zsh
		setopt local_options no_aliases

		# 无参数/stdin：保持原生 cat 行为
		if (( $# == 0 )); then
			command cat
			return $?
		fi

		# 对 cat 的参数/标准输入等情况，不做 bat 兼容，直接走系统 cat
		local a
		for a in "$@"; do
			if [[ "$a" == "-" || "$a" == --* || "$a" == -* ]]; then
				command cat "$@"
				return $?
			fi
		done

		# 若任一文件包含 ESC，则回退到系统 cat（让 ANSI 序列由终端解释渲染）
		local f
		for f in "$@"; do
			[[ -f "$f" ]] || { command cat "$@"; return $?; }
			if LC_ALL=C command grep -q $'\x1b' -- "$f" 2>/dev/null; then
				command cat "$@"
				return $?
			fi
		done

		# 普通文本：继续用 bat
		command bat -- "$@"
	}
fi

# tldr 替代 man（更简洁的命令手册）
command -v tldr >/dev/null 2>&1 && alias man='tldr'

# fzf 默认选项：预览、翻页绑定、倒序显示
export FZF_DEFAULT_OPTS='--preview "${HOME}/.config/zsh/fzf/fzf-preview.sh {}" --bind "shift-left:preview-page-up,shift-right:preview-page-down" --no-sort --tac'

# ============================================
# fd 配置
# ============================================

# fd 基础参数（排除垃圾桶和系统目录）
typeset -ga _fd_opts
_fd_opts=( -g -H -I -i -a )
if [[ "$(uname)" == "Darwin" ]]; then
	_fd_opts+=( -E .Trash -E /System/Volumes/Data )
else
	_fd_opts+=( -E .local/share/Trash )
fi

# fzf 读取列表时不要走包装函数（避免任何额外输出）
export FZF_DEFAULT_COMMAND="command fd --color=never ${(j: :)_fd_opts}"

# fd 智能函数：有 sudo 权限就用 sudo，否则回退普通模式
fd() {
	emulate -L zsh

	local -a cmd
	local fd_bin
	fd_bin=$(whence -p fd)

	# fd 未安装时直接返回错误
	if [[ -z "$fd_bin" ]]; then
		echo "fd: command not found (install via: pixi global install fd-find)" >&2
		return 127
	fi

	if sudo -n true 2>/dev/null; then
		cmd=( sudo "$fd_bin" )
	else
		cmd=( "$fd_bin" )
	fi

	# 这些选项直接透传，避免默认参数干扰
	case "$1" in
		--version|-V|--help|-h) "${cmd[@]}" "$@"; return;;
	esac

	"${cmd[@]}" --color=always "${_fd_opts[@]}" "$@" 2>/dev/null
}

# ============================================
# 别名定义
# ============================================

# 工具脚本
alias getip="$HOME/sh-script/get-my-ip.sh"

# 终端操作
alias clear='clear && printf '\''\e[3J'\'''  # 清除整个屏幕（含回滚）
alias reload="source ~/.zshenv;source ~/.zprofile;source ~/.zshrc"

# Dotfiles 管理
alias upgrade='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/beta/update_dotfiles.sh?$(date +%s)")" && reload'
alias uninstall='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/uninstall_dotfiles.sh?$(date +%s)")"'

# 常用命令简化
alias python=python3
alias g1='git clone --depth=1 --recursive'
alias mkdir='mkdir -p'
alias cp='cp -r'
alias show='kitty +kitten icat'
alias reboot='sudo reboot'


# ============================================
# 修复 pixi 覆盖的 HOST 变量（必须在最后）
# ============================================
[[ "$(uname)" == "Linux" ]] && export HOST=$(hostname -s 2>/dev/null || hostname)

