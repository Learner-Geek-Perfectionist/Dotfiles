# 跳过系统的 compinit（我们在 zinit 中自己调用）
export skip_global_compinit=1

# 确保缓存目录存在
[[ -d "$HOME/.cache/zsh" ]] || mkdir -p "$HOME/.cache/zsh"

# 设置 compdump 路径（compinit 缓存文件）
export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump"
# 设置历史文件路径（覆盖 /etc/zshrc 中的设置）
export HISTFILE="$HOME/.cache/zsh/.zsh_history"
# 让 history 命令的最大容量为无限
export HISTSIZE=10000000
export SAVEHIST=10000000

# 记录命令执行时间戳
setopt EXTENDED_HISTORY

# history 命令显示时间格式（年-月-日 时:分:秒）
export HIST_STAMPS="%Y-%m-%d %H:%M:%S"
