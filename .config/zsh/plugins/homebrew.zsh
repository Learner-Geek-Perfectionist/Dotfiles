# 检测操作系统类型

# 仅在 macOS 上执行
if [[ "$(uname -s)" = "Darwin" ]]; then
    # 设置 Homebrew 镜像源
    export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
    export HOMEBREW_API_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api
    export HOMEBREW_PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

elif [[ "$(uname -s)" = "Linux" ]]; then
    # 查找 /usr/share/zsh 目录下第一层的所有目录并有选择地添加到 FPATH
    for dir in $(find /usr/share/zsh -maxdepth 1 -type d); do
        # 跳过添加 /usr/share/zsh 本身，只添加其子目录
        if [[ "$dir" != "/usr/share/zsh" ]] && [[ ":$FPATH:" != *":$dir:"* ]]; then
            FPATH="$dir:$FPATH" # 只有当目录不在 FPATH 中时才添加
        fi
    done
fi

# 导出 FPATH 以确保设置生效
export FPATH
