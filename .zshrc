# 判断操作系统
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS specific settings
  export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export PATH="/opt/homebrew/opt/git/bin:$PATH"
  export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
  export HOMEBREW_NO_ENV_HINTS=1
else
  # Linux specific settings
  export PATH="/usr/local/bin:$PATH" # 假设软件安装在这些路径
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

###zsh主题
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ ! -f "${ZDOTDIR/.config/zsh:-$HOME}/.p10k.zsh" ]] || source "${ZDOTDIR/.config/zsh:-$HOME}/.p10k.zsh"


# Plugins
source "$ZPLUGINDIR/colorful_print.zsh"
source "$ZPLUGINDIR/homebrew.zsh"
source "$ZPLUGINDIR/zinit.zsh"

# 清除整个屏幕
alias clear='clear && printf '\''\e[3J'\'''

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh