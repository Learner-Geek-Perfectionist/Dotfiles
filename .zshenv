# 跳过系统的 compinit（我们在 zinit 中自己调用）
export skip_global_compinit=1

# ============================================
# 尽早设置 zsh 缓存文件路径，防止被 /etc/zsh/ 下的系统配置覆盖
# .zshenv 是 zsh 启动时最先加载的用户配置文件
# ============================================

# 确保缓存目录存在
[[ -d "$HOME/.cache/zsh" ]] || mkdir -p "$HOME/.cache/zsh"

# 设置历史文件路径并锁定
export HISTFILE="$HOME/.cache/zsh/.zsh_history"
# 使用 typeset -r 比 readonly 更可靠，即使变量已存在也能锁定
typeset -gr HISTFILE 2>/dev/null || true

# 设置 compdump 路径（compinit 缓存文件）
export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump"
