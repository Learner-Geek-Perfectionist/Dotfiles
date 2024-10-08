# =============================================
# ======== Zinit
# =============================================

# 检测是否安装了 git
if command -v git &>/dev/null; then
  # 定义 Zinit 安装目录
  ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

  # 检查 Zinit 是否已安装
  if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    mkdir -p "$(dirname $ZINIT_HOME)" && chmod g-rwX "$(dirname $ZINIT_HOME)"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" && \
      print -P "%F{33} %F{34}Installation successful.%f%b" || \
      print -P "%F{160} The clone has failed.%f%b"
  fi

  # 执行 zinit.zsh，加载 zinit 插件管理器本身，将 zinit 命令引入 zsh 中。
  source "$ZINIT_HOME/zinit.zsh"
  # 延迟加载 zinit 补全函数。
  autoload -Uz _zinit
  # 将 _zinit 补全函数绑定到 zinit 命令，从而获得 zinit 命令的补全功能。
  (( ${+_comps} )) && _comps[zinit]=_zinit

  # OMZ 迁移和插件配置
  HYPHEN_INSENSITIVE='true'
  COMPLETION_WAITING_DOTS='true'
  zinit ice wait lucid depth=1
  zinit snippet OMZL::clipboard.zsh
  zinit snippet OMZL::completion.zsh
  zinit snippet OMZL::grep.zsh
  zinit snippet OMZL::key-bindings.zsh

  zinit ice depth=1
  zinit snippet OMZL::directories.zsh
  zinit snippet OMZL::history.zsh
  zinit snippet OMZL::theme-and-appearance.zsh
  zinit snippet OMZP::git

  zinit ice wait lucid depth=1 atload'unalias g grv ghh'
  zinit ice depth=1
  # 加载 p10k 主题
  zinit light romkatv/powerlevel10k
  zinit light zsh-users/zsh-autosuggestions

  # 使用 Zinit Turbo 模式加载补全插件，并初始化补全系统
  zinit wait lucid for \
   atinit"autoload -Uz compinit; compinit -d "$ZSH_COMPDUMP"; zicdreplay" \
      zdharma-continuum/fast-syntax-highlighting \
   blockf \
      zsh-users/zsh-completions \
   atload"!_zsh_autosuggest_start" \
      zsh-users/zsh-autosuggestions
else
  echo "git is not installed, zinit installation skipped."
fi
