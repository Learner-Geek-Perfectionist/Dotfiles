if [[ "$HISTFILE" != "$HOME/.cache/zsh/.zsh_history" ]]; then
    export HISTFILE="$HOME/.cache/zsh/.zsh_history"
    if [[ -f "$HOME/.cache/zsh/.zsh_history" ]]; then
        readonly HISTFILE
    fi
fi

if [[ "$ZSH_COMPDUMP" != "$HOME/.cache/zsh/.zcompdump" ]]; then
    export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump"
    if [[ -f "$HOME/.cache/zsh/.zcompdump" ]]; then
        readonly ZSH_COMPDUMP
    fi
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
    alias rg='rg -uuu -i --threads=$(sysctl -n hw.ncpu)'

else
    alias rg='rg -uuu -i --threads=$(nproc)'

fi
# rust 工具的环境变量
export RUSTUP_HOME=/opt/rust/rustup
export CARGO_HOME=/opt/rust/cargo
export PATH="/opt/rust/cargo/bin:$PATH"

INSTALL_DIR="/opt/kotlin-native/"
COMPILER_INSTALL_DIR="/opt/kotlin-compiler/kotlinc/"
# 最后统一将 Kotlin/Native 安装路径添加到 PATH
[[ -d "$INSTALL_DIR" ]] && export PATH="$PATH:/opt/kotlin-native/bin/"
[[ -d "$COMPILER_INSTALL_DIR" ]] && export PATH="$PATH:/opt/kotlin-compiler/kotlinc/bin/"

# ip 映射到 ip-script
[[ "$(uname)" == "Darwin" ]] && alias getip="$HOME/sh-script/get-my-ip.sh"

# 加载 Plugins
source "${HOME}/.config/zsh/plugins/homebrew.zsh"
source "$HOME/.config/zsh/plugins/zinit.zsh"

# 禁用忽略以空格开头的命令的历史记录功能。
setopt no_hist_ignore_space
setopt interactive_comments # 注释行不报错
setopt no_nomatch           # 通配符 * 匹配不到文件也不报错
setopt autocd               # 输入目录名自动cd
# setopt correct                 # 自动纠正拼写错误
setopt nocaseglob   # 路径名匹配时忽略大小写
setopt notify       # 后台任务完成后通知
setopt no_beep      # 关闭终端提示音
setopt no_bang_hist # 不对双引号当中的叹号做历史记录拓展 "!"
setopt GLOB_DOTS    # 文件名展开（globbing）包括以点(dot)开始的文件

# 加载 fzf 的环境变量
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

# 设置 fzf 的默认预览
export FZF_DEFAULT_OPTS='--preview "${HOME}/.config/zsh/fzf/fzf-preview.sh {}" --bind "shift-left:preview-page-up,shift-right:preview-page-down"'

export FZF_DEFAULT_COMMAND='fd -L -g -HIia'
最新🩷6
alias fd='fd -L -g -HIia'

# 清除整个屏幕
alias clear='clear && printf '\''\e[3J'\'''

# python3 映射到 python
alias python=python3

# bat 映射到 cat
alias cat=bat

# reload 映射到重启 .zshrc
alias reload="source ~/.zshenv;source ~/.zprofile;source ~/.zshrc"

# 更新 zsh 配置
alias upgrade='/bin/bash -c "$(curl -H '\''Cache-Control: no-cache'\'' -fsSL "https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/zsh_config.sh?$(date +%s)")" && reload'

alias md='mkdir -p'

alias g1='git clone --depth=1'

alias rm='sudo rm -rf'

alias show='kitty +kitten icat'
