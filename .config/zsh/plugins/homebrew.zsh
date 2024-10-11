# 检测操作系统类型
OS_TYPE=$(uname -s)

# 仅在 macOS 上执行
if [ "$OS_TYPE" = "Darwin" ]; then
    # 设置 Homebrew 镜像源
    export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
    export HOMEBREW_API_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api
    export HOMEBREW_PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

    # 检测 Homebrew 是否安装在默认位置，并执行环境变量设置
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval $(/opt/homebrew/bin/brew shellenv) # 加载 Homebrew 环境变量
    fi

    # 检查 'brew' 命令是否存在
    if type brew &>/dev/null; then
        # 设置 zsh 的 FPATH 环境变量，加入 brew 提供的 site-functions
        FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
    fi

    # 手动设置
    export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
    
    # 设置 homebrew/core 和 homebrew/cask 镜像。
    brew tap --custom-remote --force-auto-update --force homebrew/core https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
    brew tap --custom-remote --force-auto-update --force homebrew/cask https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-cask.git
    
    # 除 homebrew/core 和 homebrew/cask 仓库外的 tap 仓库仍然需要设置镜像
    brew tap --custom-remote --force-auto-update homebrew/command-not-found https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-command-not-found.git
    brew update

fi
