# 双击 ESC 清除当前输入行
# ============================================

# ESC 键等待时间（单位：1/100秒）
# SSH 中网络延迟可能导致箭头键序列被拆分，适当放大
if [[ -n "$SSH_CONNECTION" ]]; then
	KEYTIMEOUT=5   # 50ms（SSH 中兼顾响应速度和键位序列完整性）
else
	KEYTIMEOUT=1   # 10ms（本地终端，double-esc 响应更快）
fi

typeset -g _esc_pressed=0
typeset -gi _esc_timer_job=0

_reset_esc_flag() {
	_esc_pressed=0
	if (( _esc_timer_job > 0 )); then
		sched -$_esc_timer_job 2>/dev/null || :
		_esc_timer_job=0
	fi
}

double-esc-clear() {
	if (( _esc_pressed )); then
		BUFFER=""
		CURSOR=0
		_reset_esc_flag
		zle reset-prompt
	else
		# 用 zsh/sched 避免每次按 ESC 都 fork 一个 sleep 进程。
		if ! zmodload -F zsh/sched b:sched 2>/dev/null; then
			_esc_pressed=1
			return 0
		fi
		_reset_esc_flag
		_esc_pressed=1
		sched +0.5 _reset_esc_flag
		_esc_timer_job=${${(k)zsh_scheduled_events}[-1]}
	fi
}

zle -N double-esc-clear
bindkey '^[' double-esc-clear
