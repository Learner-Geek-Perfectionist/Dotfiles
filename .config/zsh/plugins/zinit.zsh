#!/bin/zsh

# 专门用于安装 zinit 插件的脚本

# 插件管理器 zinit 安装的路径
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"

# 异步加载控制函数
# ZINIT_SYNC=1 时同步加载（安装脚本用），否则使用 turbo 模式
_ice() {
	if [[ -n "$ZINIT_SYNC" ]]; then
		zinit ice depth=1 "${@:#wait*}"  # 同步模式：移除 wait 参数，其余保留
	else
		zinit ice lucid depth=1 "$@"  # turbo 模式：wait 值由调用方指定
	fi
}

# 如果插件管理器 zinit 没有安装......
if [[ ! -f "${ZINIT_HOME}/zinit.zsh" ]]; then
	[[ -d "${ZINIT_HOME:h}" ]] || mkdir -p "${ZINIT_HOME:h}" || {
		printf "\033[31mFailed to create %s.\033[0m\n" "${ZINIT_HOME:h}"
		return 1
	}
	printf "\033[33mInstalling ZDHARMA-CONTINUUM Initiative Plugin Manager...\033[0m\n"
	if git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
		printf "\033[34mInstallation successful.\033[0m\n"
	else
		printf "\033[31mThe clone has failed.\033[0m\n"
		return
	fi
fi

# 执行 zinit.zsh，加载 zinit 插件管理器本身，将 zinit 命令引入 zsh 中。
source "${ZINIT_HOME}/zinit.zsh"

# 设置 zinit 的 compdump 路径（zinit 不读取 ZSH_COMPDUMP，需要单独设置）
ZINIT[ZCOMPDUMP_PATH]="${ZSH_COMPDUMP:-$HOME/.cache/zsh/.zcompdump}"

# 1.Powerlevel10k 的 instant prompt 的缓存文件，用于加速启动
# ZINIT_SYNC=1 时跳过（安装模式下 instant prompt 会导致 macOS script 命令卡住）
if [[ -z "$ZINIT_SYNC" && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh"
fi

# 2.加载 p10k 主题
zinit light romkatv/powerlevel10k

# 3.加载 p10k 主题的配置文件
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

# 上下箭头：按已输入前缀搜索历史（替代 OMZL::key-bindings.zsh）
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
autoload -Uz add-zle-hook-widget
zmodload zsh/terminfo 2>/dev/null || :
_bind_history_prefix_search() {
	emulate -L zsh
	local keymap
	# 很多终端会在普通/应用 cursor 模式之间切换，方向键可能发出两套序列：
	# `^[[A/^[[B`（CSI）或 `^[OA/^[OB`（SS3）。两套都绑定，避免前缀搜索失效。
	for keymap in emacs viins vicmd; do
		[[ -n "${terminfo[kcuu1]-}" ]] && bindkey -M "$keymap" -- "${terminfo[kcuu1]}" up-line-or-beginning-search
		[[ -n "${terminfo[kcud1]-}" ]] && bindkey -M "$keymap" -- "${terminfo[kcud1]}" down-line-or-beginning-search
		bindkey -M "$keymap" '^[[A' up-line-or-beginning-search
		bindkey -M "$keymap" '^[[B' down-line-or-beginning-search
		bindkey -M "$keymap" '^[OA' up-line-or-beginning-search
		bindkey -M "$keymap" '^[OB' down-line-or-beginning-search
	done
}
_history_prefix_search_line_init() {
	(( ${+terminfo[smkx]} )) && echoti smkx
	_bind_history_prefix_search
}
_history_prefix_search_line_finish() {
	(( ${+terminfo[rmkx]} )) && echoti rmkx
}
_bind_history_prefix_search
add-zle-hook-widget -d line-init _history_prefix_search_line_init 2>/dev/null
add-zle-hook-widget -d line-finish _history_prefix_search_line_finish 2>/dev/null
add-zle-hook-widget line-init _history_prefix_search_line_init
add-zle-hook-widget line-finish _history_prefix_search_line_finish

# 内联原 OMZL::history.zsh 的必要设置（HIST* 变量已在 .zshrc 开头重设）
# setopt extended_history 已在 .zshenv 中设置，此处不重复
setopt hist_expire_dups_first   # 历史满时优先删除重复
setopt hist_ignore_dups         # 不记录重复命令
setopt hist_verify              # 展开历史后让用户确认再执行
setopt share_history            # 多终端共享历史
# history 命令显示全部历史（zsh 内置只显示最近 16 条）
alias history='fc -l 1'

# 尾部空格使 sudo 后面的词继续展开 alias（如 sudo ll → sudo eza ...）
alias sudo='sudo '

# 内联原 OMZL::theme-and-appearance.zsh 的 eza 别名
# $commands[eza] 展开为绝对路径，确保 sudo ls/ll 也能找到 eza
# 显式开启颜色，避免外部环境的 NO_COLOR 让交互式 ls/ll 退化成纯色输出。
if (( $+commands[eza] )); then
	alias ls="$commands[eza] --color=always --icons -ha --time-style=iso"
	alias ll="$commands[eza] --color=always --icons -ha --long --time-style=iso"
fi

# ============================================
# Turbo 异步加载（prompt 显示后按优先级加载）
# ============================================
# 排序约束：
#   0a: 补全定义 → 0b: compinit + fzf-tab → 0c: 其余插件（按声明顺序）
#   zinit 只支持 a/b/c 三个子槽位，没有 0d
#   F-Sy-H 与 autosuggestions 共享 0c，需保持声明顺序：F-Sy-H 在前
#     F-Sy-H source 时绑定 widget 一次；autosuggestions 后加载直接包在外层，
#     产生干净的 autosuggest → fsh → 原始 调用链，无冗余包装层。

# ── wait'0a'：补全定义层（为 compinit 准备 FPATH）──

_ice wait'0a' as"completion"
zinit snippet "$HOME/.config/zsh/fzf/_fzf"

_ice wait'0a' blockf  # blockf: 阻止插件修改 FPATH（由 zinit 统一管理）
zinit light zsh-users/zsh-completions

# ── wait'0b'：补全系统激活 ──

# 对文件候选做“普通文件在前、dotfiles 在后”，并保留 zsh 已生成的顺序。
# 这里依赖 `file-sort modification` 先让标准文件补全按 mtime 产出候选，
# 然后在 fzf-tab 捕获到的原始 `_ftb_compcap` 上做稳定分桶，并对文件补全临时
# 关闭 fzf 自己的匹配分数排序，避免输入 query 后又把 dotfiles 顶回前面。
# 注意：这里直接依赖 fzf-tab 当前内部协议（`_ftb_compcap` 用 `\2` / `\0`
# 分隔，且文件候选带 `realdir` 键、插入词存于 `word`。`realdir` 在当前目录补全时
# 可能是空串，因此要判断键是否存在，不能判断值是否非空）；升级 fzf-tab 时要一并复查。
_ftb_reorder_file_candidates() {
	# 直接读源文件定义 orig 函数，绕开 autoload stub 无法复制的问题
	functions[-ftb-generate-complist-orig]=$(<"$FZF_TAB_HOME/lib/-ftb-generate-complist")
	functions[-ftb-fzf-orig]=$(<"$FZF_TAB_HOME/lib/-ftb-fzf")
	-ftb-generate-complist() {
		local -a _ndot=() _dot=()
		local -a _prev_sort=()
		local _ctx_sort_line _cap _meta
		local -A _v
		local -i _all_files=1 _has_compcap=$(( $#_ftb_compcap != 0 )) _had_exact_sort=0

		for _cap in "${_ftb_compcap[@]}"; do
			_meta=${_cap#*$'\2'}
			_v=("${(@0)_meta}")
			if (( ! ${+_v[realdir]} )); then
				_all_files=0
				break
			fi
			if [[ ${_v[word]} == .* ]]; then
				_dot+=("$_cap")
			else
				_ndot+=("$_cap")
			fi
		done

		if (( _has_compcap && _all_files )); then
			typeset -gi _ftb_file_completion_preserve_order=1
			_ftb_compcap=("${_ndot[@]}" "${_dot[@]}")
			_ctx_sort_line=$(zstyle -L ":completion:$_ftb_curcontext" sort)
			if [[ -n $_ctx_sort_line ]]; then
				_had_exact_sort=1
				_prev_sort=(${(z)_ctx_sort_line})
				_prev_sort=("${_prev_sort[@]:3}")
			fi
			# 仅对当前文件补全上下文临时关闭 fzf-tab 的二次字典序重排，
			# 让 `_ftb_compcap` 的 mtime 顺序完整保留下来。
			zstyle ":completion:$_ftb_curcontext" sort false
		else
			unset _ftb_file_completion_preserve_order 2>/dev/null
		fi

		-ftb-generate-complist-orig "$@"
		local _ret=$?

		if (( _has_compcap && _all_files )); then
			if (( _had_exact_sort )); then
				zstyle ":completion:$_ftb_curcontext" sort "${_prev_sort[@]}"
			else
				zstyle -d ":completion:$_ftb_curcontext" sort
			fi
		fi

		return _ret
	}
	-ftb-fzf() {
		local -a _prev_fzf_flags=()
		local _ctx_fzf_flags_line
		local -i _had_exact_fzf_flags=0 _had_no_sort=0

		if (( ${_ftb_file_completion_preserve_order:-0} )); then
			_ctx_fzf_flags_line=$(zstyle -L ":fzf-tab:$_ftb_curcontext" fzf-flags)
			if [[ -n $_ctx_fzf_flags_line ]]; then
				_had_exact_fzf_flags=1
				_prev_fzf_flags=(${(z)_ctx_fzf_flags_line})
				_prev_fzf_flags=("${_prev_fzf_flags[@]:3}")
				(( ${_prev_fzf_flags[(Ie)--no-sort]} )) && _had_no_sort=1
			fi
			if (( ! _had_no_sort )); then
				zstyle ":fzf-tab:$_ftb_curcontext" fzf-flags "${_prev_fzf_flags[@]}" --no-sort
			fi
		fi

		-ftb-fzf-orig "$@"
		local _ret=$?

		if (( ${_ftb_file_completion_preserve_order:-0} && ! _had_no_sort )); then
			if (( _had_exact_fzf_flags )); then
				zstyle ":fzf-tab:$_ftb_curcontext" fzf-flags "${_prev_fzf_flags[@]}"
			else
				zstyle -d ":fzf-tab:$_ftb_curcontext" fzf-flags
			fi
		fi
		unset _ftb_file_completion_preserve_order 2>/dev/null

		return _ret
	}
}

_ice wait'0b' atinit'
    # 恢复之前由 completion 框架提供的基础行为：
    # 1. 大小写不敏感 + 子串匹配
    # 2. 关闭 zsh 自带菜单，让 fzf-tab 接管候选展示
    # 3. 为 fzf-tab 提供描述和文件类型颜色
    # matcher-list 的每个元素都会单独跑一轮匹配，不能把“忽略大小写”和“子串匹配”拆开，
    # 否则 `cd W<Tab>` 这类大写子串只会落到区分大小写的子串轮次里。
    zstyle ":completion:*" matcher-list \
        "m:{[:lower:][:upper:]}={[:upper:][:lower:]}" \
        "m:{[:lower:][:upper:]}={[:upper:][:lower:]} r:|=*" \
        "m:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*"
    zstyle ":completion:*" menu no
    # 仅标准文件补全使用此样式；非文件补全会忽略它。
    # `modification` 默认是最近修改的排前面。
    zstyle ":completion:*" file-sort modification
    zstyle ":completion:*:descriptions" format "[%d]"
    if [[ -n "${LS_COLORS:-}" ]]; then
        zstyle ":completion:*" list-colors ${(s.:.)LS_COLORS}
    else
        zstyle ":completion:*" list-colors \
            "fi=0" "di=1;34" "ln=1;36" "pi=33" "so=1;35" "bd=1;33" "cd=1;33" \
            "or=31" "mi=0" "ex=1;32" "su=37;41" "sg=30;43" "tw=30;42" "ow=34;42" "st=37;44"
    fi
    autoload -Uz compinit
    local zcd="${ZSH_COMPDUMP:-$HOME/.cache/zsh/.zcompdump}"
    local need_update=0
    if [[ -f "$zcd" ]]; then
        for dir in $fpath; do
            [[ -d "$dir" && "$dir" -nt "$zcd" ]] && { need_update=1; break }
        done
    fi
    if [[ ! -f "$zcd" || $need_update -eq 1 ]]; then
        compinit -d "$zcd"
    else
        compinit -C -d "$zcd"
    fi
    zicdreplay
' atload'
    zstyle ":fzf-tab:complete:_zlua:*" query-string input
    zstyle ":fzf-tab:complete:kill:argument-rest" fzf-preview "ps -p \$word -o comm= 2>/dev/null"
    zstyle ":fzf-tab:complete:kill:argument-rest" fzf-flags "--preview-window=down:15:wrap"
    zstyle ":fzf-tab:complete:kill:*" popup-pad 0 3
    zstyle ":fzf-tab:complete:cd:*" fzf-preview "eza -1 --color=always \$realpath"
    zstyle ":fzf-tab:complete:cd:*" popup-pad 30 0
    zstyle ":fzf-tab:complete:code:*" fzf-preview "eza -1 --color=always \$realpath"
    zstyle ":fzf-tab:complete:code:*" popup-pad 30 0
    # fzf-tab 会把当前输入作为 fzf query；加 -i 避免大写输入触发 smart-case，
    # 例如 `cd W<Tab>` 也能匹配 `mihomo-party-wcloud/`。
    # 仅作用于 fzf-tab，不改变普通 fzf 的全局搜索习惯。
    zstyle ":fzf-tab:*" fzf-flags --color=dark,bg+:23 -i
    zstyle ":fzf-tab:*" switch-group "<" ">"
    _ftb_reorder_file_candidates; unfunction _ftb_reorder_file_candidates
'
zinit light Aloxaf/fzf-tab

# ── wait'0c'：功能插件层 ──

# OMZP::git 的别名（ggpush, gpsup 等）依赖此函数，原定义在 OMZL::git.zsh 中
git_current_branch() {
	local ref ret
	ref=$(command git symbolic-ref --quiet HEAD 2>/dev/null)
	ret=$?
	if [[ $ret != 0 ]]; then
		[[ $ret == 128 ]] && return
		ref=$(command git rev-parse --short HEAD 2>/dev/null) || return
	fi
	echo ${ref#refs/heads/}
}

_ice wait'0c'
zinit snippet OMZP::git/git.plugin.zsh

# F-Sy-H 默认会在 YANK_ACTIVE 时给整段粘贴内容套上 `paste standout`，
# 多行代码粘贴时会显得整块过亮；预先覆盖 zle 的 paste 样式，保留语法色。
zmodload zsh/zleparameter 2>/dev/null || :
typeset -ga zle_highlight
zle_highlight=(${zle_highlight:#paste:*} "paste:none")

_ice wait'0c' atload'FAST_HIGHLIGHT[chroma-which]="→chroma/-precommand.ch"'
zinit light zdharma-continuum/fast-syntax-highlighting

# ── wait'0c'：自动建议（最外层 widget 包装）──

# widget 只绑定一次，避免每个 precmd 都重绑 autosuggestions。
typeset -g ZSH_AUTOSUGGEST_MANUAL_REBIND=1
# 修复 fzf-tab 唯一补全后偶发残留的 autosuggestion 灰字：将 fzf-tab-complete 视为 clear widget，并在加载后立即重绑。
_ice wait'0c' atload'(( ${ZSH_AUTOSUGGEST_CLEAR_WIDGETS[(Ie)fzf-tab-complete]} )) || ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(fzf-tab-complete); _zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 清理：_ice 仅在 zinit.zsh 加载期间使用
unfunction _ice  # 删除辅助函数，防止泄漏到用户的全局命名空间
