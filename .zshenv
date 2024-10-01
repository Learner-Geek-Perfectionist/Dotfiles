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
export ZDOTDIR="$XDG_CONFIG_HOME/zsh" # zsh shell 专用的环境变量，用来指定 .zshrc 配置文件的存放路径。
export ZPLUGINDIR="$ZDOTDIR/plugins"
export ZSCRIPTDIR="$ZDOTDIR/scripts"
export HISTFILE="$ZDOTDIR/.zsh_history" # HISTFILE  也是 zsh 内置的环境变量