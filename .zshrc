
if [[ "$HISTFILE" != "$XDG_CACHE_HOME/zsh/.zsh_history" ]];then
    export HISTFILE="$XDG_CACHE_HOME/zsh/.zsh_history"
    readonly HISTFILE
fi

if [[ "$ZSH_COMPDUMP" != "$XDG_CACHE_HOME/zsh/.zcompdump" ]];then
    export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump"
    readonly ZSH_COMPDUMP
fi



# 获取操作系统信息并设置 PATH
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS specific settings，设置 git 、clang++、ruby、make bash、VSCode、gre、less 等工具的环境变量
    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
    export PATH="/opt/homebrew/opt/git/bin:$PATH"
    export PATH="/opt/homebrew/opt/less/bin:$PATH"
    export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
    export PATH="/opt/homebrew/opt/bash/bin:$PATH"
    export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
    export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
    export PATH="/Applications/CLion.app/Contents/MacOS:$PATH"
    export PATH="/Applications/PyCharm.app/Contents/MacOS:$PATH"
    export PATH="/Applications/IntelliJ IDEA.app/Contents/MacOS:$PATH"
    export PATH="/opt/homebrew/anaconda3/bin:$PATH"
    export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
    export HOMEBREW_NO_ENV_HINTS=1
    # clion 映射到 cl
    alias cl=clion
    # pycharm 映射到 py
    alias py=pycharm

    alias fd='fd --strip-cwd-prefix --hidden --follow --exclude .git'
    # Setting fd as the default source for fzf
    export FZF_DEFAULT_COMMAND='fd --strip-cwd-prefix --hidden --follow --exclude .git'

elif [[ -f /etc/os-release ]]; then

    # 设置默认的语言环境
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8

    # 检查是否是 Ubuntu 系统
    if grep -q 'ID=ubuntu' /etc/os-release; then
        # 对于 Ubuntu 系统，添加 fzf、eza 的环境变量
        export PATH="$HOME/.fzf/bin:$PATH"
        export PATH="$HOME/.cargo/bin:$PATH"
        export PATH="$HOME/.local/kitty.app/bin:$PATH"
        # Setting fd as the default source for fzf
        export FZF_DEFAULT_COMMAND='fdfind --strip-cwd-prefix --hidden --follow --exclude .git'
    else
        # Setting fd as the default source for fzf
        export FZF_DEFAULT_COMMAND='fd --strip-cwd-prefix --hidden --follow --exclude .git'
        alias fd='fd --strip-cwd-prefix --hidden --follow --exclude .git'
    fi

fi


INSTALL_DIR="/opt/kotlin-native/"
COMPILER_INSTALL_DIR="/opt/kotlin-compiler/kotlinc/"
# 最后统一将 Kotlin/Native 安装路径添加到 PATH
[[ -d "$INSTALL_DIR" ]] && export PATH="$PATH:/opt/kotlin-native/bin/"
[[ -d "$COMPILER_INSTALL_DIR" ]] && export PATH="$PATH:/opt/kotlin-compiler/kotlinc/bin/"

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


# ip 映射到 ip-script
[[ "$(uname)" == "Darwin" ]] && alias ip="$HOME/sh-script/get-my-ip.sh"



# 设置 fzf 的默认预览
export FZF_DEFAULT_OPTS='--preview "${HOME}/.config/zsh/fzf/fzf-preview.sh {}" --bind "shift-left:preview-page-up,shift-right:preview-page-down"'
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
setopt GLOB_DOTS                 # 文件名展开（globbing）包括以点(dot)开始的文件

# 清除整个屏幕
alias clear='clear && printf '\''\e[3J'\'''

# python3 映射到 python
alias python=python3

alias cat=bat
# reload 映射到重启 .zshrc
alias reload="source ~/.zshrc;source ~/.zprofile;source ~/.zshenv;rm -rf $HOME/.cache/zsh/.zcompdump; "

alias md='mkdir -p'

alias g1='git clone --depth=1'

alias rm='sudo rm -rf'

alias show='kitty +kitten icat'

