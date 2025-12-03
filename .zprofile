# 加载 zprof 模块，分析 Zsh 脚本的性能。 执行 zprof 命令。
zmodload zsh/zprof

# 删除 Apple Terminal 的 .zsh_sessions 文件
[[ -e "$HOME/.zsh_sessions" ]] && rm -rf "$HOME/.zsh_sessions" && echo "已成功删除 $HOME/.zsh_sessions。"

# 添加 homebrew 的环境变量
if [[ -x "/opt/homebrew/bin/brew" ]]; then
	eval $(/opt/homebrew/bin/brew shellenv)
fi

# 添加 anaconda 的环境变量
if [[ -x "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]]; then
	source /opt/homebrew/anaconda3/etc/profile.d/conda.sh
fi

# 添加 orbstack 的环境变量
if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
	source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :
fi
