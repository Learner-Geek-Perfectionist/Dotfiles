# 检测操作系统类型
OS_TYPE=$(uname -s)

# macOS
if [ "$OS_TYPE" = "Darwin" ]; then
    export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
    export HOMEBREW_API_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api
    export HOMEBREW_PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval $(/opt/homebrew/bin/brew shellenv) #ckbrew
    fi
fi

# 这里可以添加Linux特有的环境变量或者其他设置
if [ "$OS_TYPE" = "Linux" ]; then
    # Linux specific settings here
    # 例如：export SOME_LINUX_ONLY_ENV_VAR=some_value
fi