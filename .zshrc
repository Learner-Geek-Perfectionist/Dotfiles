# ============================================
# 终端环境初始化
# ============================================

# 确保 TERM 有值（空或 dumb 时设置默认值）
[[ -z "$TERM" || "$TERM" == "dumb" ]] && export TERM="xterm-256color"

# Kitty 终端 SSH 时回退 TERM（远程服务器可能没有 xterm-kitty terminfo）
[[ "$TERM" == "xterm-kitty" && ! -e "/usr/share/terminfo/x/xterm-kitty" ]] && export TERM="xterm-256color"

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
	alias rg='rg -uuu -i --threads=$(sysctl -n hw.ncpu) 2>/dev/null'
	alias open='open -R'

else
	alias rg='rg -uuu -i --threads=$(nproc) 2>/dev/null'

	# Cursor 编辑器（Linux）- 先添加，确保 cursor 命令可用
	path_prepend "/opt/Cursor/resources/app/bin"

	# VSCode 编辑器（Linux）- 后添加，确保 code 命令指向 VSCode 而非 Cursor
	path_prepend "/opt/visual-studio-code/bin"

	# Pixi 环境管理：快切 PATH + 异步补齐环境变量（依赖 zsh-async）
	path_prepend "$HOME/.pixi/bin"
	typeset -g _PIXI_PROJECT_DIR="__UNINITIALIZED__"
	typeset -g _PIXI_LOCK_MTIME=""
	typeset -g _PIXI_ASYNC_READY=0

	_pixi_find_project() {
		local dir="$PWD"
		while [[ "$dir" != "/" && "$dir" != "$HOME" ]]; do
			[[ -f "$dir/pixi.toml" ]] && { print -r -- "$dir"; return 0; }
			dir="${dir:h}"
		done
		return 0
	}

	# 获取 pixi.lock 文件的修改时间（用于检测 pixi add/remove 等操作）
	_pixi_lock_mtime() {
		local lock_file="$1/pixi.lock"
		[[ -f "$lock_file" ]] && stat -c %Y "$lock_file" 2>/dev/null || echo ""
	}

	# 只负责 PATH 和 CONDA_PREFIX（避免与 pixi shell-hook 的 PATH 改写打架）
	_pixi_fast_path() {
		local project_dir="$1"
		# 清理旧的 pixi env PATH（避免串环境/重复）
		local -a new_path=()
		local p
		for p in $path; do
			[[ "$p" == */.pixi/envs/* ]] && continue
			new_path+=("$p")
		done
		path=($new_path)

		# 设置 PATH 和 CONDA_PREFIX（不能混用两个环境，因为 wrapper 脚本依赖 CONDA_PREFIX）
		# 项目 pixi 环境优先，否则使用 home pixi 环境
		if [[ -n "$project_dir" && -d "$project_dir/.pixi/envs/default" ]]; then
			path=("$project_dir/.pixi/envs/default/bin" $path)
			export CONDA_PREFIX="$project_dir/.pixi/envs/default"
		elif [[ -d "$HOME/.pixi/envs/default" ]]; then
			path=("$HOME/.pixi/envs/default/bin" $path)
			export CONDA_PREFIX="$HOME/.pixi/envs/default"
		fi

		if [[ -n "$project_dir" ]]; then
			export PIXI_PROJECT_NAME="$(grep -m1 '^name' "$project_dir/pixi.toml" 2>/dev/null | sed 's/.*\"\(.*\)\".*/\1/')"
		else
			export PIXI_PROJECT_NAME="home"
		fi
		export CONDA_DEFAULT_ENV="${PIXI_PROJECT_NAME:-default}"
		# p10k anaconda segment 需要 CONDA_SHLVL 才会显示
		export CONDA_SHLVL=1
	}

	_pixi_async_init() {
		(( _PIXI_ASYNC_READY )) && return 0
		(( $+functions[async_start_worker] && $+functions[async_register_callback] )) || return 1
		async_start_worker pixi_worker
		async_register_callback pixi_worker _pixi_async_callback
		_PIXI_ASYNC_READY=1
	}

	_pixi_async_callback() {
		local job=$1 code=$2 output=$3
		local header="${output%%$'\n'*}"
		[[ "$header" == __PIXI_PROJECT__=* ]] || return 0
		local project_dir="${header#__PIXI_PROJECT__=}"
		# 防止旧任务回写：只应用当前项目的结果
		[[ "$project_dir" == "$_PIXI_PROJECT_DIR" ]] || return 0

		local exports="${output#*$'\n'}"
		if [[ $code -eq 0 && -n "$exports" && "$exports" != "$output" ]]; then
			# 保存当前 PATH，避免被覆盖
			local saved_path="$PATH"
			eval "$exports"
			# 恢复 PATH（环境变量由异步设置，PATH 由 _pixi_fast_path 同步管理）
			export PATH="$saved_path"
		fi
		return 0
	}

	_pixi_async_full_load() {
		local project_dir="$1"
		local pixi_bin="$HOME/.pixi/bin/pixi"
		
		print -r -- "__PIXI_PROJECT__=$project_dir"
		[[ -x "$pixi_bin" ]] || return 0

		# 执行 pixi shell-hook（使用绝对路径）
		if [[ -n "$project_dir" ]]; then
			[[ -f "$HOME/pixi.toml" ]] && eval "$("$pixi_bin" shell-hook --manifest-path "$HOME" 2>/dev/null)" &>/dev/null
			eval "$("$pixi_bin" shell-hook --manifest-path "$project_dir" 2>/dev/null)" &>/dev/null
		else
			[[ -f "$HOME/pixi.toml" ]] && eval "$("$pixi_bin" shell-hook --manifest-path "$HOME" 2>/dev/null)" &>/dev/null
		fi

		# 回传关键环境变量（不回传 PATH）
		export -p | grep -E '^export (PIXI_|CONDA_|CC|CXX|CFLAGS|CXXFLAGS|LDFLAGS|JAVA_HOME|GOROOT|GEM_|CARGO_|RUST)='
	}

	_pixi_switch() {
		local project_dir="$(_pixi_find_project)"
		local current_mtime=""
		local need_refresh=0

		# 检测项目目录变化
		if [[ "$project_dir" != "$_PIXI_PROJECT_DIR" ]]; then
			need_refresh=1
		else
			# 检测 pixi.lock 文件变化（pixi add/remove 会修改此文件）
			if [[ -n "$project_dir" ]]; then
				current_mtime="$(_pixi_lock_mtime "$project_dir")"
			else
				current_mtime="$(_pixi_lock_mtime "$HOME")"
			fi
			[[ "$current_mtime" != "$_PIXI_LOCK_MTIME" ]] && need_refresh=1
		fi

		(( need_refresh )) || return 0

		typeset -g _PIXI_PROJECT_DIR="$project_dir"
		typeset -g _PIXI_LOCK_MTIME="$current_mtime"

		_pixi_fast_path "$project_dir"

		# async 可用就异步补齐；否则只保留 PATH（避免阻塞启动）
		if (( $+functions[async_job] )); then
			_pixi_async_init && async_job pixi_worker _pixi_async_full_load "$project_dir"
		fi
		return 0
	}

	# precmd hook：在每次显示提示符前检查环境变化并处理异步结果
	_pixi_precmd() {
		# 检查 pixi.lock 是否变化（捕获 pixi add/remove 等操作）
		_pixi_switch

		if (( _PIXI_ASYNC_READY )); then
			# 保存当前 PATH（防止被 async 输出污染）
			local _saved_path="$PATH"
			async_process_results pixi_worker &>/dev/null
			# 恢复 PATH
			export PATH="$_saved_path"
		fi
	}

	_pixi_switch
	autoload -U add-zsh-hook
	add-zsh-hook chpwd _pixi_switch
	add-zsh-hook precmd _pixi_precmd

	# OrbStack Linux 支持 open 命令打开 macOS Finder
	[[ -d "/opt/orbstack-guest" ]] && command -v open &>/dev/null && alias open='open -R'
fi

# SSH Agent 配置
# ============================================
# 适用场景：
#   - macOS 系统自带 agent（launchd 管理）
#   - OrbStack 自动转发
#   - ssh -A 连接的服务器
#   - Docker 容器挂载 socket
#   - 无 agent 的 Linux 服务器（自动启动本地 agent）
#
# 测试 Agent Forwarding 是否生效：
#   echo $SSH_AUTH_SOCK          # 查看 socket 路径
#   ssh-add -l                   # 列出已加载的公钥指纹
#   ssh -T git@github.com        # 测试 GitHub 认证
#
# Docker 容器使用 Agent Forwarding：
#   # 方式 1：挂载 socket（推荐）
#   docker run -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent ...
#
#   # 方式 2：SSH 连接（需要容器安装 sshd）
#   apt update && apt install -y openssh-server iproute2 git zsh sudo curl
#   echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
#   service ssh start
#   passwd root  # 设置密码
#   # 然后从 macOS(客户端): ssh root@<容器IP>
#
# ============================================
# 1. 尝试连接当前环境中的 agent
# ssh-add -l 返回 0 代表连接正常且有密钥；返回 1 代表连接正常但无密钥；返回 2 代表无法连接
ssh-add -l &>/dev/null
_agent_status=$?

if [[ $_agent_status -eq 0 ]]; then
	# [情况A] Agent 存活且已有密钥 -> 检查是否只有我们需要的密钥
	# 如果密钥数量超过预期，清空后重新加载（避免 Keychain 自动加载旧密钥）
	_key_count=$(ssh-add -l 2>/dev/null | wc -l | tr -d ' ')
	_expected_keys=0
	for key in ~/.ssh/id_{ed25519,rsa,ecdsa}; do [[ -f "$key" ]] && ((_expected_keys++)); done
	if [[ $_key_count -gt $_expected_keys ]]; then
		ssh-add -D &>/dev/null  # 清空所有
		for key in ~/.ssh/id_{ed25519,rsa,ecdsa}; do
			if [[ -f "$key" ]]; then
				[[ "$(uname)" == "Darwin" ]] && OPTS="--apple-use-keychain" || OPTS=""
				ssh-add $OPTS "$key" 2>/dev/null
			fi
		done
	fi
	unset _key_count _expected_keys
	:
elif [[ $_agent_status -eq 1 ]]; then
	# [情况B] Agent 存活但没有密钥 -> 只需要加载密钥
	for key in ~/.ssh/id_{ed25519,rsa,ecdsa}; do
		if [[ -f "$key" ]]; then
			# macOS 用户建议加上 --apple-use-keychain
			[[ "$(uname)" == "Darwin" ]] && OPTS="--apple-use-keychain" || OPTS=""
			ssh-add $OPTS "$key" 2>/dev/null
		fi
	done
else
	# [情况C] 无法连接 Agent (状态码 2) 或者 SSH_AUTH_SOCK 为空 -> 启动/复用固定 Agent
	_ssh_agent_sock="$HOME/.ssh/agent.sock"

	# 如果 socket 文件存在，但连不上(上面已经测过了)，说明是死 socket，删掉
	if [[ -S "$_ssh_agent_sock" ]]; then
		export SSH_AUTH_SOCK="$_ssh_agent_sock"
		if ! ssh-add -l &>/dev/null; then
			rm -f "$_ssh_agent_sock"
		fi
	fi

	# 如果 socket 不存在（被删了或本来就没有），启动新的
	if [[ ! -S "$_ssh_agent_sock" ]]; then
		eval "$(ssh-agent -a "$_ssh_agent_sock" -s)" >/dev/null 2>&1
	else
		# 即使文件存在，也要 export 一下确保当前 shell 拿到变量
		export SSH_AUTH_SOCK="$_ssh_agent_sock"
	fi

	# 启动完新 agent 后，加载密钥
	for key in ~/.ssh/id_{ed25519,rsa,ecdsa}; do
		if [[ -f "$key" ]]; then
			[[ "$(uname)" == "Darwin" ]] && OPTS="--apple-use-keychain" || OPTS=""
			ssh-add $OPTS "$key" 2>/dev/null
		fi
	done
fi

unset _agent_status _ssh_agent_sock

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
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

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

	"${cmd[@]}" --color=always "${_fd_opts[@]}" "$@"
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
alias upgrade='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/update_dotfiles.sh?$(date +%s)")" && reload'
alias uninstall='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/uninstall_dotfiles.sh?$(date +%s)")"'

# 常用命令简化
alias python=python3
alias g1='git clone --depth=1'
alias mkdir='mkdir -p'
alias cp='cp -r'
alias show='kitty +kitten icat'
alias reboot='sudo reboot'
