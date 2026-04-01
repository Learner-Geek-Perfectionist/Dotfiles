# 双击 ESC 清除当前输入行
# ============================================

# ESC 键等待时间（单位：1/100秒）
# SSH 中网络延迟可能导致箭头键序列被拆分，适当放大
if [[ -n "$SSH_CONNECTION" ]]; then
	KEYTIMEOUT=5   # 50ms（SSH 中兼顾响应速度和键位序列完整性）
else
	KEYTIMEOUT=1   # 10ms（本地终端，double-esc 响应更快）
fi

typeset -gF _esc_last_pressed_at=0
typeset -gF _esc_double_window=0.5
typeset -gi _esc_uses_realtime=0

if zmodload -F zsh/datetime p:EPOCHREALTIME 2>/dev/null; then
	_esc_uses_realtime=1
else
	_esc_double_window=1
fi

double-esc-clear() {
	local -F now

	if (( _esc_uses_realtime )); then
		now=$EPOCHREALTIME
	else
		now=$SECONDS
	fi

	if (( _esc_last_pressed_at > 0 && now - _esc_last_pressed_at <= _esc_double_window )); then
		BUFFER=""
		CURSOR=0
		_esc_last_pressed_at=0
		zle reset-prompt
	else
		_esc_last_pressed_at=$now
	fi
}

zle -N double-esc-clear
bindkey '^[' double-esc-clear
