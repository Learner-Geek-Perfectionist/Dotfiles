# =============================================
# ======== Zinit
# =============================================

# 检测是否安装了git
if command -v git &>/dev/null; then
  # 定义 Zinit 安装目录
  ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

  # 检查Zinit是否已安装
  if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    mkdir -p "$(dirname $ZINIT_HOME)" && chmod g-rwX "$(dirname $ZINIT_HOME)"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" && \
      print -P "%F{33} %F{34}Installation successful.%f%b" || \
      print -P "%F{160} The clone has failed.%f%b"
  fi
  # 源Zinit脚本
  source "$ZINIT_HOME/zinit.zsh"
  autoload -Uz _zinit
  (( ${+_comps} )) && _comps[zinit]=_zinit

  # OMZ迁移和插件配置
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
  zinit light romkatv/powerlevel10k
  zinit light zsh-users/zsh-autosuggestions
  zinit wait lucid for \
      atinit"zicompinit; zicdreplay" \
      zdharma-continuum/fast-syntax-highlighting \
      blockf \
      zsh-users/zsh-completions
else
  echo "git is not installed, zinit installation skipped."
fi