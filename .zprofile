# 加载 zprof 模块，分析 Zsh 脚本的性能。 执行 zprof 命令。
zmodload zsh/zprof

# Ensure XDG base directories exist
mkdir -p "$HOME/.config" "$HOME/.cache" "$HOME/.local/share" "$HOME/.local/state"

# Ensure Zsh directories exist
mkdir -p "$HOME/.config/zsh/plugins"

mkdir -p "$HOME/.cache/zsh"

# 删除 Apple Terminal 的 .zsh_sessions 文件
[[ -e "$HOME/.zsh_sessions" ]] && rm -r "$HOME/.zsh_sessions" && echo "已成功删除 $HOME/.zsh_sessions。"

# 删除 $HOME 目录下的 .zcompdump 缓存文件
[[ -f $HOME/.zcompdump ]] && rm "$HOME/.zcompdump" && echo "已成功删除 $HOME/.zcompdump。"

# 添加 homebrew 的环境变量
if [ -x "/opt/homebrew/bin/brew" ]; then
    eval $(/opt/homebrew/bin/brew shellenv)
fi
# 添加 anaconda 的环境变量
if [ -x "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
    source /opt/homebrew/anaconda3/etc/profile.d/conda.sh
fi


# 检查 .zprofile 文件是否存在并且包含特定的初始化命令
if [ -f "$HOME/.zprofile" ]; then
    if ! grep -qF "source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :" "$HOME/.zprofile"; then
        # 如果命令不在 .zprofile 中，执行它
        source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :
    fi
fi


