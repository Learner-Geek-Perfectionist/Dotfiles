# # 加载 zprof 模块，分析 Zsh 脚本的性能。 执行 zprof 命令。
# zmodload zsh/zprof

# 缓存模式：把外部命令的输出缓存到文件，仅在原始二进制更新时重新生成
# 避免每次启动都 fork 外部进程（如 brew shellenv、direnv hook zsh）
# 添加 homebrew 的环境变量（缓存输出，仅 brew 二进制更新时重新生成）
if [[ -x "/opt/homebrew/bin/brew" ]]; then
	_brew_cache="$ZSH_CACHE_DIR/brew-shellenv.zsh"
	if [[ ! -f "$_brew_cache" || "/opt/homebrew/bin/brew" -nt "$_brew_cache" ]]; then
		/opt/homebrew/bin/brew shellenv > "$_brew_cache"
	fi
	source "$_brew_cache"
	unset _brew_cache
fi

# 延迟加载 anaconda（首次调用 conda 时才初始化）
if [[ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]]; then
	conda() {
		unfunction conda  # 移除这个包装函数自身，让后续调用走真正的 conda
		source /opt/homebrew/anaconda3/etc/profile.d/conda.sh
		conda "$@"
	}
fi

# 添加 orbstack 的环境变量
if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
	source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :  # || : 静默忽略错误（: 是 true 的别名）
fi
