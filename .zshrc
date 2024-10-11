# -----------------------------------
# -------- XDG Base Directory
# -----------------------------------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Ensure XDG base directories exist
 mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

# -----------------------------------
# -------- Zsh Directory
# -----------------------------------
export ZDOTDIR="$HOME"
export ZPLUGINDIR="$ZDOTDIR/.config/zsh/plugins"
export ZSCRIPTDIR="$ZDOTDIR/.config/zsh/scripts"
export HISTFILE="$XDG_CACHE_HOME/zsh/.zsh_history" # HISTFILE 也是 zsh 内置的环境变量

# Ensure Zsh directories exist
 mkdir -p "$ZPLUGINDIR" "$ZSCRIPTDIR"


# Set the location for the zcompdump file to be in the cache directory
 export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump"

# Ensure the directory for zcompdump exists
 mkdir -p "$(dirname "$ZSH_COMPDUMP")"





# 判断操作系统
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS specific settings，设置 git 、clang++、ruby、make bash 等工具的环境变量
  export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export PATH="/opt/homebrew/opt/git/bin:$PATH"
  export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
  export PATH="/opt/homebrew/opt/bash/bin:$PATH"
  export HOMEBREW_NO_ENV_HINTS=1
else
  # Linux specific settings
  
  # 其他 Linux 特有的设置
fi


## 代理配置
function proxy() {
    export https_proxy="http://127.0.0.1:7897"
    export http_proxy="http://127.0.0.1:7897"
    export all_proxy="socks5://127.0.0.1:7897"
    echo "Proxy enabled"
}

function unproxy() {
    unset https_proxy
    unset http_proxy
    unset all_proxy
    echo "Proxy disabled"
}

# Plugins
source "$ZPLUGINDIR/colorful_print.zsh"
source "$ZPLUGINDIR/homebrew.zsh"
source "$ZPLUGINDIR/zinit.zsh"

# 加载 p10k 主题的配置文件
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh


# p10k 的 prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi



# 清除整个屏幕
alias clear='clear && printf '\''\e[3J'\'''

# 感叹号「!」是 zsh 中特殊的前缀，用于历史扩展，禁止它。
setopt NO_BANG_HIST

# 检查 fzf 是否已安装
if command -v fzf >/dev/null 2>&1; then
    # 如果 fzf 存在，则加载 fzf 的 zsh 配置
    source <(fzf --zsh)
else
    echo "fzf is not installed. Please install fzf to enable its features."
fi
