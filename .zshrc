# 加载 zprof 模块，分析 Zsh 脚本的性能。 执行 zprof 命令。
zmodload zsh/zprof 

# 修改默认的登录 shell 为 zsh
[[ $SHELL != */zsh ]] && chsh -s $(which zsh) 

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



# 获取操作系统信息并设置 PATH
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS specific settings，设置 git 、clang++、ruby、make bash、VSCode、grep 等工具的环境变量
    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
    export PATH="/opt/homebrew/opt/git/bin:$PATH"
    export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
    export PATH="/opt/homebrew/opt/bash/bin:$PATH"
    export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
    export HOMEBREW_NO_ENV_HINTS=1
    
elif [[ -f /etc/os-release ]]; then

    # 设置默认的语言环境
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8

    # 执行 sdkman 初始化脚本，对所有 Linux 系统执行
    if [[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    fi

    # 检查是否是 Ubuntu 系统
    if grep -q 'ID=ubuntu' /etc/os-release; then
        # 对于 Ubuntu 系统，添加 fzf 的环境变量
        export PATH="$HOME/.fzf/bin:$PATH"
    fi
fi

else
    # 其他操作系统的设置
    echo "Unsupported OS"
    return 1
fi


# 最后统一将 Kotlin/Native 安装路径添加到 PATH
if [[ -n "$INSTALL_DIR" ]]; then
    export PATH="$PATH:/opt/kotlin-native/bin"
else
    echo "安装目录未设置，脚本中止。"
    return 1
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

# python3 映射到 python
alias python=python3 

# 感叹号「!」是 zsh 中特殊的前缀，用于历史扩展，禁止它。
setopt NO_BANG_HIST
# 禁用忽略以空格开头的命令的历史记录功能。
setopt no_hist_ignore_space

# 检查 .zprofile 是否包含特定的初始化命令
if ! grep -q 'source ~/.orbstack/shell/init.zsh 2>/dev/null || :' ~/.zprofile; then
    # 如果 .zprofile 没有包含该命令，那么在当前 shell 中执行它
    source ~/.orbstack/shell/init.zsh 2>/dev/null || :
fi

# 检查 fzf 是否已安装
if command -v fzf >/dev/null 2>&1; then
    # 如果 fzf 存在，则加载 fzf 的 zsh 配置
    source <(fzf --zsh)
else
    echo "fzf is not installed. Please install fzf to enable its features."
fi
