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

fi
