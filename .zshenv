# 跳过系统的 compinit（我们在 zinit 中自己调用）
export skip_global_compinit=1

# 确保缓存目录存在
[[ -d "$HOME/.cache/zsh" ]] || mkdir -p "$HOME/.cache/zsh"

# 设置 compdump 路径（compinit 缓存文件）
# 这个变量系统配置通常不会覆盖
export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump"
