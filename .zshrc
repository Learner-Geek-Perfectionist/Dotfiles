# ============================================
# 终端环境
# ============================================

# 确保 TERM 有值（空或 dumb 时设置默认值）
[[ -z "$TERM" || "$TERM" == "dumb" ]] && export TERM="xterm-256color"

# 在 kitty 终端中自动用 kitten ssh（自动传 terminfo + shell integration）
if [[ -n "$KITTY_WINDOW_ID" ]]; then
	alias ssh='kitten ssh'
	# 创建固定路径 symlink，供外部工具（如 VS Code 插件）定位 Kitty socket
	# kitty.conf 使用 kitty-{kitty_pid} 防多实例冲突，这里补一个稳定入口
	[[ -n "$KITTY_LISTEN_ON" ]] && ln -sf "${KITTY_LISTEN_ON#unix:}" /tmp/kitty-socket
fi

# SSH 会话 locale 回退（避免远程服务器没有安装本地 locale 导致乱码）
if [[ -n "$SSH_CONNECTION" ]]; then
    export LANG="${LANG:-en_US.UTF-8}"
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
fi

# ============================================
# Shell 基础配置
# ============================================

# 重设 HIST*（macOS /etc/zshrc 会覆盖 .zshenv 的值，必须在 .zshrc 中再次设置）
HISTFILE="$ZSH_CACHE_DIR/.zsh_history"
HISTSIZE=10000000
SAVEHIST=10000000

setopt interactive_comments # 注释行不报错
setopt no_nomatch           # 通配符 * 匹配不到文件也不报错
setopt nocaseglob           # 路径名匹配时忽略大小写
setopt notify               # 后台任务完成后通知
setopt no_beep              # 关闭终端提示音
setopt no_bang_hist         # 不对双引号当中的叹号做历史记录拓展 "!"
setopt GLOB_DOTS            # 文件名展开（globbing）包括以点(dot)开始的文件
setopt rm_star_silent       # 取消 zsh 的安全防护功能（默认对 rm -rf ./* 删除操作触发）

# ============================================
# PATH 与平台配置（必须在插件加载之前，zinit 中的 eza 别名依赖 PATH）
# ============================================

# typeset -U path/fpath 已在 .zshenv 中设置（确保整个加载链去重）

if [[ "$OSTYPE" == darwin* ]]; then
	path=(
		"$HOME/.local/bin"
		"$HOME/.cargo/bin"
		/opt/homebrew/opt/openjdk/bin
		/opt/homebrew/anaconda3/bin
		"/Applications/IntelliJ IDEA.app/Contents/MacOS"
		"/Applications/PyCharm.app/Contents/MacOS"
		"/Applications/CLion.app/Contents/MacOS"
		"/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
		"/Applications/Cursor.app/Contents/Resources/app/bin"
		/opt/homebrew/opt/grep/libexec/gnubin
		/opt/homebrew/opt/bash/bin
		/opt/homebrew/opt/make/libexec/gnubin
		/opt/homebrew/opt/less/bin
		/opt/homebrew/opt/git/bin
		/opt/homebrew/opt/ruby/bin
		/opt/homebrew/opt/llvm/bin
		$path
	)
	export HOMEBREW_NO_ENV_HINTS=1
	alias cl=clion
	alias py=pycharm
	alias open='open -R'

else
	path=(
		"$HOME/.local/bin"
		"$HOME/.pixi/envs/default/bin"
		"$HOME/.pixi/bin"
		/opt/visual-studio-code/bin
		/opt/Cursor/resources/app/bin
		$path
	)

	# Pixi + direnv：进入/离开目录自动加载/卸载环境变量
	if (( $+commands[direnv] )); then  # $+commands[x]: 若 x 在 PATH 中则为 1，否则为 0
		_direnv_cache="$ZSH_CACHE_DIR/direnv-hook.zsh"
		if [[ ! -f "$_direnv_cache" || "$commands[direnv]" -nt "$_direnv_cache" ]]; then  # $commands[x] = x 的绝对路径；-nt = newer than
			direnv hook zsh > "$_direnv_cache"
		fi
		source "$_direnv_cache"
		unset _direnv_cache
	fi

	# OrbStack Linux 支持 open 命令打开 macOS Finder
	[[ -d "/opt/orbstack-guest" ]] && (( $+commands[open] )) && alias open='open -R'  # $+commands[open]: open 命令是否可用
fi

# ============================================
# 插件加载（PATH 已就绪，插件可安全检测命令是否存在）
# ============================================
[[ -f "${HOME}/.config/zsh/plugins/platform.zsh" ]] && source "${HOME}/.config/zsh/plugins/platform.zsh"
[[ -f "${HOME}/.config/zsh/plugins/zinit.zsh" ]] && source "${HOME}/.config/zsh/plugins/zinit.zsh"
[[ -f "${HOME}/.config/zsh/plugins/double-esc-clear.zsh" ]] && source "${HOME}/.config/zsh/plugins/double-esc-clear.zsh"

# ============================================
# 凭证与密钥
# ============================================

# age 加密的 tokens（必须在 PATH 设置之后，因为 age 在 pixi 环境中）
[[ -f "${HOME}/.config/zsh/plugins/age-tokens.zsh" ]] && source "${HOME}/.config/zsh/plugins/age-tokens.zsh"

# macOS Keychain 自动解锁（SSH 会话，依赖 age-tokens 提供 MACOS_KEYCHAIN_PASS）
[[ -f "${HOME}/.config/zsh/plugins/ssh-keychain-unlock.zsh" ]] && source "${HOME}/.config/zsh/plugins/ssh-keychain-unlock.zsh"

# SSH Agent (keychain)
# 仅本地运行：keychain 管理 agent，远程依赖 ForwardAgent 转发
# 测试：ssh-add -l && ssh -T git@github.com
_kc_cache="$ZSH_CACHE_DIR/keychain-env.zsh"
if [[ -z "$SSH_CONNECTION" && -f "$HOME/.ssh/id_ed25519" ]] && (( $+commands[keychain] )); then  # $+commands[]: PATH 中是否存在
	if [[ -f "$_kc_cache" ]] && source "$_kc_cache" 2>/dev/null && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
		: # agent alive, cache valid
	else
		eval "$(keychain --eval --quiet --inherit any --agents ssh id_ed25519 2>/dev/null)" \
			&& typeset -p SSH_AUTH_SOCK SSH_AGENT_PID > "$_kc_cache" 2>/dev/null  # typeset -p: 输出变量的声明语句（可直接 source 还原）
	fi
fi
unset _kc_cache

# ============================================
# 工具配置（ripgrep / fzf / fd）
# ============================================

# ripgrep 全局配置（忽略文件路径须由 shell 展开，不能放 config 里）
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
alias rg='command rg --ignore-file "$HOME/.config/ripgrep/ignore"'

# 加载 fzf 快捷键（Ctrl+T, Ctrl+R, Alt+C），但保留 fzf-tab 的 Tab 补全
if (( $+commands[fzf] )); then  # fzf 是否已安装
	_fzf_cache="$ZSH_CACHE_DIR/fzf-keybindings.zsh"
	if [[ ! -f "$_fzf_cache" || "$commands[fzf]" -nt "$_fzf_cache" ]]; then  # fzf 二进制更新了 → 重新生成缓存
		fzf --zsh > "$_fzf_cache"
	fi
	source "$_fzf_cache"
	unset _fzf_cache
	# 不要在这里 bindkey '^I' fzf-tab-complete ！
	# fzf-tab 通过 zinit turbo 延迟加载，在 enable-fzf-tab 中会自动绑定 ^I。
	# 如果在这里提前绑定，enable-fzf-tab 会误把 fzf-tab-complete 当作"原始 widget"，
	# 导致递归调用自身 → "job table full or recursion limit exceeded"。
fi

# fzf 默认选项：--exact 精确匹配（连续字符），搜索时加 ' 前缀可切换回模糊匹配
export FZF_DEFAULT_OPTS='--no-mouse --exact --preview "${HOME}/.config/zsh/fzf/fzf-preview.sh {}" --bind "shift-left:preview-page-up,shift-right:preview-page-down"'
export FZF_CTRL_R_OPTS='--tac'

# fd 基础参数（排除垃圾桶和系统目录）
typeset -ga _fd_opts  # -g = 全局变量，-a = 数组类型
_fd_opts=( -g -H -I -i -a )
if [[ "$OSTYPE" == darwin* ]]; then
	_fd_opts+=( -E .Trash -E /System/Volumes/Data )
else
	_fd_opts+=( -E .local/share/Trash )
fi

# fzf 读取列表时不要走包装函数（避免任何额外输出）
export FZF_DEFAULT_COMMAND="command fd --color=never ${(j: :)_fd_opts}"  # ${(j: :)arr}: 用空格拼接数组元素为字符串

# fd 智能函数：有免密 sudo 就提权，否则回退普通模式
fd() {
	local -a pre; sudo -n true 2>/dev/null && pre=(sudo)
	"${pre[@]}" =fd --color=always "${_fd_opts[@]}" "$@" 2>/dev/null  # =fd: 展开为 fd 的绝对路径（绕过本函数自身的递归）
}

# fzf 包装函数：透明处理管道输入（用 always 块替代 trap，避免覆盖 shell 已有 trap）
fzf() {
	if [ -p /dev/stdin ]; then
		local tmp=$(mktemp)
		{
			sed 's/\x1b\[[0-9;]*m//g' > "$tmp"
			command fzf "$@" < "$tmp"
		} always {
			rm -f "$tmp"
		}
	else
		command fzf "$@"
	fi
}

# ============================================
# 命令增强
# ============================================

# bat 映射到 cat（仅当所有参数都是不含 ANSI 的普通文件时才用 bat，其余回退系统 cat）
if (( $+commands[bat] )); then
	cat() {
		emulate -L zsh
		(( $# )) || { command cat; return }
		local f
		for f in "$@"; do
			# 有标志(-x/--x/-)、非普通文件、含 ANSI 转义 → 回退系统 cat
			if [[ "$f" == -* || ! -f "$f" ]]; then
				command cat "$@"; return
			fi
			if LC_ALL=C command grep -q $'\x1b' -- "$f" 2>/dev/null; then
				command cat "$@"; return
			fi
		done
		command bat -- "$@"
	}
fi

# tldr 替代 man（更简洁的命令手册）
(( $+commands[tldr] )) && alias man='tldr'  # tldr 已安装则用它替代 man

# ============================================
# 别名定义
# ============================================

# 工具脚本
alias getip="$HOME/sh-script/get-my-ip.sh"

# 终端操作
alias clear='clear && printf '\''\e[3J'\'''  # 清除整个屏幕（含回滚）
alias reload='exec zsh -l'

# Dotfiles 管理
alias upgrade='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/beta/install.sh?$(date +%s)")" -- --dotfiles-only && reload'
alias uninstall='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/beta/uninstall_dotfiles.sh?$(date +%s)")"'

# 常用命令简化
alias python=python3
alias g1='git clone --depth=1 --recursive'
alias mkdir='mkdir -p'
alias cp='cp -r'
alias show='kitty +kitten icat'
alias reboot='sudo reboot'

# claude
alias claude='claude --dangerously-skip-permissions'

# ============================================
# 预编译：加速下次启动（后台执行，不阻塞当前启动）
# ============================================
{
	local f
	# 只编译 ~/.config 和 ~/.cache 下的脚本
	# 不编译 ~/.zshrc ~/.zshenv ~/.zprofile ——避免在 $HOME 下生成 .zwc 缓存文件
	# （对这些小文件，编译带来的启动加速可忽略）
	# 跳过 keychain-env.zsh（含 PID，频繁变更，编译无收益）
	for f in ~/.config/zsh/plugins/*.zsh \
		~/.config/zsh/.p10k.zsh \
		"$ZSH_CACHE_DIR"/*.zsh(N); do  # (N): glob qualifier — 无匹配时返回空（不报错）
		[[ "$f" == *keychain-env.zsh ]] && continue
		[[ -f "$f" && ( ! -f "${f}.zwc" || "$f" -nt "${f}.zwc" ) ]] && zcompile "$f"  # zcompile: 编译为字节码 .zwc，source 时更快
	done
} &!  # &! = 后台执行 + disown（不受 HUP 信号影响，不阻塞启动）
