
## 代理 ##
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


# =============================================
# ======== Powerlevel10k Instant Prompt
# =============================================

# 快速加载 Powerlevel10k 主题的 instant prompt 功能
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Source p10k configuration
[[ ! -f "${ZDOTDIR:-$HOME}/.p10k.zsh" ]] || source "${ZDOTDIR:-$HOME}/.p10k.zsh"

# 短路原则
# 如果 .p10k.zsh 文件存在，则执行 source 命令加载该文件。这种方式确保只有当配置文件存在时，才会尝试加载它。



# # -----------------------------------
# # -------- Plugins
# # -----------------------------------
source "$ZPLUGINDIR/colorful_print.zsh"
# # source "$ZPLUGINDIR/vpn.zsh" 
source "$ZPLUGINDIR/homebrew.zsh"
 
source "$ZPLUGINDIR/zinit.zsh"
 
 

# 清除整个滚动缓冲区。
alias clear='clear && printf '\''\e[3J'\'''


# fzf key bindings and completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

 
