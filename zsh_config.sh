#!/bin/bash

# 设置脚本在遇到错误时退出
set -e

# 定义打印居中消息的函数
print_centered_message() {
    local message="$1"
    local single_flag="${2:-true}" # 如果没有提供第二个参数，默认为 true
    local double_flag="${3:-true}" # 如果没有提供第三个参数，默认为 true
    local cols=$(stty size | cut -d ' ' -f 2)
    local line=''

    # 创建横线，长度与终端宽度相等
    for ((i = 0; i < cols; i++)); do
        line+='-'
    done

    if [[ $single_flag == "true" ]]; then
        # 如果是 true，执行打印上边框的操作
        echo "$line"
    fi

    # 计算居中的空格数
    local pad_length=$(((cols - ${#message}) / 2))

    # 打印居中的消息
    printf "%${pad_length}s" '' # 打印左边的空格以居中对齐
    echo -e "$message"

    if [[ $double_flag == "true" ]]; then
        # 如果是 true，执行打印下边框的操作
        echo "$line"
    fi
}

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

# 安装依赖工具 eza、fzf、kitty

if [[ $(uname -s) == "Darwin" ]]; then
    if ! command -v fzf >/dev/null 2>&1; then
        brew install -y fzf
    fi

    if ! command -v eza >/dev/null 2>&1; then
        brew install -y eza
    fi

    if ! command -v kitty >/dev/null 2>&1; then
        brew install -y kitty
    fi

elif [[ $(uname -s) == "Linux" ]]; then

    # 检测操作系统
    os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    # 根据操作系统安装......
    if [[ $os_type == "ubuntu" ]]; then

        # 解压的依赖工具 xz
        sudo apt install -y xz-utils
        if ! command -v zsh >/dev/null 2>&1; then
            sudo apt install -y zsh
        fi

        if ! command -v git >/dev/null 2>&1; then
            sudo apt install -y git
        fi
        if ! command -v curl >/dev/null 2>&1; then
            sudo apt install -y curl
        fi
        # =================================开始安装 kitty=================================
        if ! command -v kitty >/dev/null 2>&1; then
            print_centered_message "${GREEN}开始安装 kitty... ${NC}" "true" "false"
            curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n

            # 定义基础 URL
            BASE_URL="http://kr.archive.ubuntu.com/ubuntu/pool/universe/k/kitty/"

            # 使用 curl 获取页面内容，并解析出最新的 kitty-terminfo .deb 文件的版本号
            TERMINFO_LATEST_VERSION=$(curl -s "$BASE_URL" | grep -oP 'href="kitty-terminfo_[^"]*\.deb"' | sed -E 's|.*kitty-terminfo_([^"]*)\.deb.*|\1|' | sort -V | tail -1)

            # 如果找不到文件，则退出
            if [ -z "$TERMINFO_LATEST_VERSION" ]; then
                echo -e "${RED}Failed to find the kitty-terminfo .deb file.${NC}"
                exit 1
            fi

            # 构建完整的 .deb 文件下载 URL（kitty-terminfo）
            TERMINFO_URL="${BASE_URL}kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"

            # 下载和安装包（kitty-terminfo）
            echo -e "Downloading ${RED}kitty-terminfo${NC} version ${GREEN}${TERMINFO_LATEST_VERSION}${NC}"
            if curl -s -O "$TERMINFO_URL"; then
                echo "Installing kitty-terminfo..."
                if sudo dpkg -i "kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"; then
                    echo -e "${GREEN}kitty 安装完成 ✅${NC}"
                else
                    echo -e "${RED}Installation failed.${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}Download failed.${NC}"
                exit 1
            fi

            # 清理下载的文件
            sudo rm -rf "kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"

            # 检查是否在 WSL2 中运行或在自动化脚本环境中
            if grep -qi microsoft /proc/version || [[ "$AUTO_RUN" == "true" ]]; then
                print_centered_message "${RED}在 WSL2 中或者 Dockerfile 中不需要安装 kitty 桌面图标${NC}" "false" "false"
            else
                mkdir -p /usr/local/bin/ ~/.local/share/applications/
                sudo ln -s ~/.local/kitty.app/bin/kitty /usr/local/bin/
                # For Application Launcher:
                sudo cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
                sudo cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
                # Add Icon:
                sudo sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
                sudo sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
                sudo chmod a+x $HOME/.local/kitty.app/share/applications/kitty-open.desktop $HOME/.local/kitty.app/share/applications/kitty.desktop $HOME/.local/share/applications/kitty-open.desktop $HOME/.local/share/applications/kitty.desktop
            fi
        else
            print_centered_message "${GREEN} kitty 已安装，跳过安装。${NC}" "true" "false"
        fi

        # =================================结束安装 kitty=================================

        # =================================开始安装 fzf=================================
        if command -v fzf >/dev/null 2>&1; then
            print_centered_message "${GREEN}fzf 已安装，跳过安装。${NC}" "true" "false"
        else
            print_centered_message "${GREEN}开始安装 fzf... ${NC}" "true" "false"
            [[ -d "$HOME/.fzf" ]] && rm -rf "$HOME/.fzf"

            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
            yes | $HOME/.fzf/install --no-update-rc
            print_centered_message "${GREEN} fzf 安装完成 ✅${NC}" "false" "false"
        fi
        # =================================结束安装 fzf=================================

        # =================================开始安装 eza=================================
        if command -v eza >/dev/null 2>&1; then
            print_centered_message "${GREEN}eza 已安装，跳过安装。${NC}" "true" "true"
        else
            print_centered_message "${GREEN}开始安装 eza... ${NC}" "true" "false"
            # 安装 eza, 在 oracular (24.10)  之后的 Ubuntu 发行版才有
            ! command -v cargo >/dev/null 2>&1 && sudo apt install -y cargo
            cargo install eza
            print_centered_message "${GREEN} eza 安装完成 ✅${NC}" "false" "true"
        fi
    # =================================结束安装 eza=================================

    elif [[ $os_type == "fedora" ]]; then
        if ! command -v fzf >/dev/null 2>&1; then
            sudo dnf install -y fzf
        fi

        if ! command -v eza >/dev/null 2>&1; then
            sudo dnf install -y eza
        fi

        if ! command -v kitty >/dev/null 2>&1; then
            sudo dnf install -y kitty
        fi

        if ! command -v zsh >/dev/null 2>&1; then
            sudo dnf install -y zsh
        fi
        if ! command -v git >/dev/null 2>&1; then
            sudo dnf install -y git
        fi
        if ! command -v curl >/dev/null 2>&1; then
            sudo dnf install -y curl
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

# 浅克隆仓库到临时目录
echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
    echo "Failed to clone repository"
    exit 1
}

# Ensure XDG base directories exist
mkdir -p "$HOME/.config/zsh/plugins" "${HOME}/.config/kitty" "$HOME/.cache/zsh" "${HOME}/.local/share/zinit" "$HOME/.local/state"

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
/bin/zsh -c "source $HOME/.config/zsh/plugins/zinit-plugin.zsh"

rm -rf $HOME/.zcompdump $HOME/.zsh_history

