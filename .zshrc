# Ensure XDG base directories exist
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

# Ensure Zsh directories exist
mkdir -p "$ZPLUGINDIR" "$ZSCRIPTDIR"

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
    export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
    export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
    export PATH="/Applications/CLion.app/Contents/MacOS:$PATH"
    export PATH="/Applications/PyCharm.app/Contents/MacOS:$PATH"
    export PATH="/Applications/IntelliJ IDEA.app/Contents/MacOS:$PATH"
    export HOMEBREW_NO_ENV_HINTS=1
    
elif [[ -f /etc/os-release ]]; then

    # 设置默认的语言环境
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8

    # 检查是否是 Ubuntu 系统
    if grep -q 'ID=ubuntu' /etc/os-release; then
        # 对于 Ubuntu 系统，添加 fzf 的环境变量
        export PATH="$HOME/.fzf/bin:$PATH"
    fi
fi


INSTALL_DIR="/opt/kotlin-native/"
# 最后统一将 Kotlin/Native 安装路径添加到 PATH
if [[ -n "$INSTALL_DIR" ]]; then
    export PATH="$PATH:/opt/kotlin-native/bin"
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


# 清除整个屏幕
alias clear='clear && printf '\''\e[3J'\'''

# python3 映射到 python
alias python=python3 

# pycharm 映射到 py
alias py=pycharm

# clion 映射到 cl
alias cl=clion

# reload 映射到重启 .zshrc
alias reload='source ~/.zshrc'

alias md='mkdir -p'

alias g1='git clone --depth=1'

unalias ls
alias ls='eza --icons -lha'

# ip 映射到 ip-script
if [[ "$OSTYPE" == "darwin"* ]]; then
    # 仅在 macOS 上设置别名
    alias ip="$HOME/sh-script/get-my-ip.sh"
fi

# 禁用忽略以空格开头的命令的历史记录功能。
setopt no_hist_ignore_space
setopt interactive_comments      # 注释行不报错
setopt no_nomatch                # 通配符 * 匹配不到文件也不报错
setopt autocd                    # 输入目录名自动cd
# setopt correct                 # 自动纠正拼写错误
setopt nocaseglob                # 路径名匹配时忽略大小写
setopt notify                    # 后台任务完成后通知
setopt no_beep                   # 关闭终端提示音
setopt no_bang_hist              # 不对双引号当中的叹号做历史记录拓展 "!"

# 检查 .zprofile 文件是否存在并且包含特定的初始化命令
if [ -f "$HOME/.zprofile" ]; then
    if ! grep -qF "source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :" "$HOME/.zprofile"; then
        # 如果命令不在 .zprofile 中，执行它
        source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :
    fi
fi


# Plugins
source "$ZPLUGINDIR/colorful_print.zsh"
source "$ZPLUGINDIR/homebrew.zsh"   
source "$ZPLUGINDIR/zinit.zsh"

# 执行 sdkman 初始化脚本，对所有 Linux 系统执行
if [[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# 检查 fzf 是否已安装
if command -v fzf >/dev/null 2>&1; then
    # 如果 fzf 存在，则加载 fzf 的 zsh 配置
    source <(fzf --zsh)
else
    echo "fzf is not installed. Please install fzf to enable its features."
fi


 
