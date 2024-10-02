# 检测操作系统
OS_TYPE=$(uname -s)

# 仅在macOS上执行Homebrew相关命令
if [ "$OS_TYPE" = "Darwin" ]; then
  if type brew &>/dev/null; then
    # 设置zsh的FPATH环境变量，加入brew提供的site-functions
    FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"

    # 加载并执行zsh的compinit初始化，用于命令行补全
    autoload -Uz compinit
    compinit
  fi
fi