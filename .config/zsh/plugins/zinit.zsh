# =============================================
# ======== Zinit
# =============================================


# 检查 git 是否安装......
if ! command -v git &>/dev/null; then
  echo "git is not installed, zinit installation skipped."
  return
fi

# 插件管理器 zinit 安装的路径
export ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"

# 如果插件管理器 zinit 没有安装......
if [[ ! -f "${ZINIT_HOME}/zinit.zsh" ]]; then
  printf "\033[33m\033[220mInstalling ZDHARMA-CONTINUUM Initiative Plugin Manager...\033[0m\n"
  sudo -u "$(whoami)" mkdir -p "${HOME}/.local/share/zinit"
  if git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
    printf "\033[33m\033[34mInstallation successful.\033[0m\n"
  else
    printf "\033[160mThe clone has failed.\033[0m\n"
    return
  fi
fi

source ${HOME}/.config/zsh/plugins/zinit-plugin.zsh