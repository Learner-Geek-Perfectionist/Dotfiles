# =============================================
# ======== Zinit
# =============================================
# -----------------------------------
# -------- Zinit Installer
# -----------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
  print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
  command mkdir -p "$(dirname $ZINIT_HOME)" && command chmod g-rwX "$(dirname $ZINIT_HOME)"
  command git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" && \
    print -P "%F{33} %F{34}Installation successful.%f%b" || \
    print -P "%F{160} The clone has failed.%f%b"
fi
# 安装 zinit 插件管理器
source "$ZINIT_HOME/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit



# -----------------------------------
# -------- OMZ Migration
# -----------------------------------
# For OMZ completion
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

# -----------------------------------
# -------- Zinit Plugins
# -----------------------------------
# CASE 1: Use `startship`.
# zinit ice as"command" from"gh-r" \
#           atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
#           atpull"%atclone" src"init.zsh"
# zinit light starship/starship
# CASE 2: Use `starship` if available; otherwise `powerlevel10k`
# if command -v starship &> /dev/null; then eval "$(starship init zsh)"
# else zinit ice depth=1; zinit light romkatv/powerlevel10k
# fi
# CASE 3: Use `powerlevel10k`.
zinit ice depth=1; 

zinit light romkatv/powerlevel10k
zinit light zsh-users/zsh-autosuggestions

zinit wait lucid for \
    atinit"zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
    blockf \
    zsh-users/zsh-completions
