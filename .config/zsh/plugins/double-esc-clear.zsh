# 双击 ESC 清除当前输入行
# ============================================

# 减少 ESC 键等待时间（单位：1/100秒，1=10ms）
KEYTIMEOUT=1

typeset -g _esc_pressed=0
typeset -g _esc_timer_fd

_reset_esc_flag() {
	_esc_pressed=0
	[[ -n "$_esc_timer_fd" ]] && zle -F "$_esc_timer_fd" 2>/dev/null
	exec {_esc_timer_fd}<&-
	unset _esc_timer_fd
}

double-esc-clear() {
	if (( _esc_pressed )); then
		BUFFER=""
		CURSOR=0
		_reset_esc_flag
		zle reset-prompt
	else
		_esc_pressed=1
		# 使用管道作为定时器
		exec {_esc_timer_fd}< <(sleep 0.5)
		zle -F "$_esc_timer_fd" _reset_esc_flag
	fi
}

zle -N double-esc-clear
bindkey '^[' double-esc-clear
