# =============================================
# ======== Zinit
# =============================================


# Check if git is installed
if ! command -v git &>/dev/null; then
  echo "git is not installed, zinit installation skipped."
  return
fi

# Define Zinit installation directory
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Install Zinit if not already installed
if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
  print -P "%F{33} %F{220}Installing ZDHARMA-CONTINUUM Initiative Plugin Manager...%f"
  mkdir -p "$(dirname $ZINIT_HOME)" && chmod g-rwX "$(dirname $ZINIT_HOME)"
  if git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
    print -P "%F{33} %F{34}Installation successful.%f%b"
  else
    print -P "%F{160} The clone has failed.%f%b"
    return
  fi
fi


# 执行 zinit.zsh，加载 zinit 插件管理器本身，将 zinit 命令引入 zsh 中。
source "$ZINIT_HOME/zinit.zsh"

# 延迟加载 zinit 补全函数。
autoload -Uz _zinit

# 将 _zinit 补全函数绑定到 zinit 命令，从而获得 zinit 命令的补全功能。
(( ${+_comps} )) && _comps[zinit]=_zinit


# 最先加载 p10k 主题
zinit light romkatv/powerlevel10k

# General options for all plugins
HYPHEN_INSENSITIVE='true'
COMPLETION_WAITING_DOTS='true'


# OMZ 迁移和插件配置
HYPHEN_INSENSITIVE='true'
COMPLETION_WAITING_DOTS='true'
# clipboard
zinit ice wait lucid depth=1
zinit snippet OMZL::clipboard.zsh
# completion
zinit ice wait lucid depth=1
zinit snippet OMZL::completion.zsh
# grep
zinit ice wait lucid depth=1
zinit snippet OMZL::grep.zsh
# key-bindings
zinit ice wait lucid depth=1
zinit snippet OMZL::key-bindings.zsh
# directories
zinit ice depth=1
zinit snippet OMZL::directories.zsh
# history
zinit ice depth=1  
zinit snippet OMZL::history.zsh
# theme
zinit ice depth=1
zinit snippet OMZL::theme-and-appearance.zsh
# git
zinit ice depth=1  
zinit snippet OMZP::git

zinit ice wait lucid depth=1 atload'unalias g grv ghh'

# autosuggestions
#（直到 shell 初始化之后，才）延迟加载 zsh-users/zsh-autosuggestions 插件，atload 用于保障启动 autosuggest 功能。
zinit ice wait lucid atload='_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 使用 Zinit Turbo 模式加载补全插件，并初始化补全系统
zinit wait lucid for \
 atinit"autoload -Uz compinit; compinit -C -d "$ZSH_COMPDUMP"" \
    zdharma-continuum/fast-syntax-highlighting \
 blockf \
    zsh-users/zsh-completions \
#   atload"!_zsh_autosuggest_start" \
#      zsh-users/zsh-autosuggestions


