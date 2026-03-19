# 禁用 direnv 加载提示（必须在最早阶段设置）
export DIRENV_LOG_FORMAT=""

# 跳过系统的 compinit（我们在 zinit 中自己调用）
export skip_global_compinit=1

# 缓存目录（所有 zsh 缓存文件统一放在这里）
export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"  # ${X:-default}: X 为空时用 default
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

# compdump 路径（compinit 缓存文件；/etc/zshrc 不会覆盖此值，设一次即可）
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"
# HISTFILE / HISTSIZE / SAVEHIST 在 .zshrc 中设置
# （macOS /etc/zshrc 会覆盖 .zshenv 的值，放这里无效）

# 记录命令执行时间戳
setopt EXTENDED_HISTORY

# 本地终端：跳过 p10k 的 SSH 检测（节省 ~30% 启动时间）
# SSH 会话中 $SSH_CONNECTION 非空，p10k 会正常检测
[[ -z "$SSH_CONNECTION" ]] && export P9K_SSH=0
