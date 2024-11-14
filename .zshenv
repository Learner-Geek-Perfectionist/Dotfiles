
export skip_global_compinit=1

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
export HISTFILE="$XDG_CACHE_HOME/zsh/.zsh_history" # HISTFILE 也是 zsh 内置的环境变量


# Set the location for the zcompdump file to be in the cache directory
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump"
