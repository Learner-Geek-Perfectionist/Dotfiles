# 跳过系统的 compinit（我们在 zinit 中自己调用）
export skip_global_compinit=1

# 确保缓存目录存在
[[ -d "$HOME/.cache/zsh" ]] || mkdir -p "$HOME/.cache/zsh"

# 设置 compdump 路径（compinit 缓存文件）
export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump"
# 设置历史文件路径（覆盖 /etc/zshrc 中的设置）
export HISTFILE="$HOME/.cache/zsh/.zsh_history"
