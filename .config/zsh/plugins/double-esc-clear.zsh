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
typeset -g _esc_timer_fd

_reset_esc_flag() {
	_esc_pressed=0
	if [[ -n "$_esc_timer_fd" ]]; then
		zle -F "$_esc_timer_fd" 2>/dev/null
		exec {_esc_timer_fd}<&- 2>/dev/null
		unset _esc_timer_fd
	fi
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
