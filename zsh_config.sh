#!/bin/bash

# 设置脚本在遇到错误时退出
set -e

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
ORANGE='\033[0;93m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_BLUE='\033[1;34m'
DARK_RED='\033[1;31m'
NC='\033[0m' # 没有颜色

# 定义临时目录路径
TMP_DIR="/tmp/Dotfiles"

sudo rm -rf "$TMP_DIR"
sudo rm -rf /tmp/Fonts/
echo -e "${GREEN}🚀 Starting script...${NC}"
cd $HOME


# 浅克隆仓库到临时目录
echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
  echo "Failed to clone repository"
  exit 1
}

# Ensure XDG base directories exist
mkdir -p "$HOME/.config/zsh/plugins" "${HOME}/.config/kitty" "$HOME/.cache/zsh" "${HOME}/.local/share/zinit" "$HOME/.local/state"


if ! command -v zsh > /dev/null 2>&1 ; then
  echo -e "${RED}zsh 未安装${NC}"
  exit 1
fi

# 安装依赖工具 eza、fzf

if [[ $(uname -s) == "Darwin" ]]; then
  if ! command -v fzf > /dev/null 2>&1; then
      brew install -y fzf
  fi

  if ! command -v eza > /dev/null 2>&1; then
      brew install -y eza
  fi

elif [[ $(uname -s) == "Linux" ]]; then

    # 检测操作系统
    os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    # 根据操作系统安装......
    if [[ $os_type == "ubuntu" ]]; then

        # =================================开始安装 fzf=================================
        if command -v fzf > /dev/null 2>&1; then
            print_centered_message  "${GREEN}fzf 已安装，跳过安装。${NC}"  "true" "false"
        else
            print_centered_message  "${GREEN}开始安装 fzf... ${NC}" "true" "false"
            [[ -d "$HOME/.fzf" ]] && rm -rf "$HOME/.fzf"

            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
            yes | $HOME/.fzf/install --no-update-rc
            print_centered_message "${GREEN} fzf 安装完成 ✅${NC}" "false" "false"
        fi
        # =================================结束安装 fzf=================================


        # =================================开始安装 eza=================================
        if command -v eza > /dev/null 2>&1; then
            print_centered_message  "${GREEN}eza 已安装，跳过安装。${NC}"  "true" "true"
        else
            print_centered_message  "${GREEN}开始安装 eza... ${NC}" "true" "false"
            # 安装 eza, 在 oracular (24.10)  之后的 Ubuntu 发行版才有
            ! command -v cargo > /dev/null 2>&1 && sudo apt install -y cargo
            cargo install eza
            print_centered_message "${GREEN} eza 安装完成 ✅${NC}" "false" "true"
        fi
        # =================================结束安装 eza=================================

    elif [[ $os_type == "fedora" ]]; then
         if ! command -v fzf > /dev/null 2>&1; then
              sudo dnf install -y fzf
         fi

         if ! command -v eza > /dev/null 2>&1; then
              sudo dnf install -y eza
         fi

    else
        print_centered_message "${RED}不支持的发行版，目前只支持 fedora、ubuntu${NC}"
    fi

    # 修改默认的登录 shell 为 zsh
    # 获取当前用户的默认 shell
    current_shell=$(getent passwd "$(whoami)" | cut -d: -f7)
    # 如果当前 shell 不是 zsh，则更改为 zsh
    [[ "$(command -v zsh)" != "$current_shell" ]] && sudo chsh -s "$(command -v zsh)" "$(whoami)"
else
    echo -e "${MAGENTA}未知的操作系统类型${NC}"
fi


# 定义配置列表
configs=(".zshenv" ".zprofile" ".zshrc" ".config/kitty" ".config/zsh")

# 删除旧配置和复制新配置
echo -e "${YELLOW}🔍 Checking and removing old configuration files if they exist...${NC}"
for config in "${configs[@]}"; do
  if [[ -f "${HOME}/${config}" ]] || [[ -d "${HOME}/${config}" ]]; then
    echo -e "${RED}🗑️ Removing old ${config}...${NC}"
    sudo rm -rf "${HOME}/$config"
  fi
  echo -e "${PURPLE}📋 Moving new ${config} to ${HOME}...${NC}"
    cp -r "${TMP_DIR}/${config}" "${HOME}/${config}"
done

# 在文件中添加以下代码
  [[ "$(uname)" == "Darwin" ]] && cp -r "$TMP_DIR/sh-script/" "$HOME/sh-script/"

# 添加 .hammerspoon 文件夹
if [[ "$(uname)" == "Darwin" ]]; then
  if [[ -d "${HOME}/.hammerspoon" ]]; then
    echo -e "${RED}🗑️ Removing old .hammerspoon...${NC}"
    sudo rm -rf "${HOME}/.hammerspoon"
  fi
  echo -e "${PURPLE}📋 Copying new .hammerspoon to "${HOME}/.hammerspoon"...${NC}"
    cp -r "${TMP_DIR}/.hammerspoon" "${HOME}/.hammerspoon"
fi

# 添加 Karabiner 配置文件：capslock2hyper.json
if [[ "$(uname)" == "Darwin" ]]; then
  if [[ -f "${HOME}/.config/karabiner/assets/complex_modifications/capslock2hyper.json" ]]; then
    echo -e "${RED}🗑️ Removing old capslock2hyper.json...${NC}"
    sudo rm -rf "${HOME}/.config/karabiner/assets/complex_modifications/capslock2hyper.json"
  fi
  echo -e "${PURPLE}📋 Copying new capslock2hyper.json to ${HOME}/.config/karabiner/assets/complex_modifications/capslock2hyper.json...${NC}"
    cp -r "${TMP_DIR}/capslock2hyper.json" "${HOME}/.config/karabiner/assets/complex_modifications/capslock2hyper.json"
fi

echo -e "${GREEN}🧹 Old configuration files removed and new ones copied.${NC}"
echo -e "${GREEN}✔️ New configuration files copied.${NC}"

# 清理临时目录
echo -e "${YELLOW}🧼 Cleaning up temporary files...${NC}"
sudo rm -rf "$TMP_DIR"
sudo rm -rf /tmp/Fonts/

echo -e "${GREEN}✔️ Temporary files removed.${NC}"
echo -e "${GREEN}✅ Script completed successfully. Files have been successfully copied to the user's home directory.${NC}"


# 安装 zsh 插件
/bin/zsh

rm -rf $HOME/.zcompdump;rm -rf $HOME/.zsh_history;