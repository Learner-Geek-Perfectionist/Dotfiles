# 加载 zprof 模块，分析 Zsh 脚本的性能。 执行 zprof 命令。
zmodload zsh/zprof

# -----------------------------------
# -------- XDG Base Directory
# -----------------------------------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# -----------------------------------
# -------- Zsh Directory
# -----------------------------------
export ZPLUGINDIR="$HOME/.config/zsh/plugins"
export ZSCRIPTDIR="$HOME/.config/zsh/scripts"

# Ensure XDG base directories exist
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

# Ensure Zsh directories exist
mkdir -p "$ZPLUGINDIR" "$ZSCRIPTDIR"

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
