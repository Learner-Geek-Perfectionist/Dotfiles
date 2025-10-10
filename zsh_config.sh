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

#!/bin/bash

# 判断操作系统类型
if [[ -f /etc/lsb-release ]]; then
    # Ubuntu 系统
    sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list

elif [[ -f /etc/fedora-release ]]; then
    # Fedora 系统
    sudo sed -e 's|^metalink=|#metalink=|g' \
        -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
        -i.bak \
        /etc/yum.repos.d/fedora.repo \
        /etc/yum.repos.d/fedora-updates.repo
fi

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

# 定义临时目录路径
TMP_DIR="/tmp/Dotfiles"

sudo rm -rf "$TMP_DIR"
sudo rm -rf /tmp/Fonts/
echo -e "${GREEN}🚀 Starting script...${NC}"

if [[ $(uname -s) == "Darwin" ]]; then
    brew update
    # 定义需要安装的工具
    tools=("fzf" "eza" "fd" "rg" "kitty" "bat" "fastfetch" "man-db" "lua")
    # 遍历工具列表，检查是否已安装
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            brew install "$tool"
        fi
    done
    # 浅克隆仓库到临时目录
    echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
    git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
        echo "Failed to clone repository"
        exit 1
    }

elif [[ $(uname -s) == "Linux" ]]; then

    # 检测操作系统
    os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    # 根据操作系统安装......
    if [[ $os_type == "ubuntu" ]]; then
        sudo apt update
        tools=("zsh" "git" "curl" "make" "g++" "gcc" "openssh-server" "man-db" "wget" "llvm" "gnupg" "pkg-config" "xz-utils" "gtk-update-icon-cache" "bc" "graphviz")
        # 遍历工具列表，检查是否已安装
        for tool in "${tools[@]}"; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                sudo apt install -y "$tool"
            fi
        done
        # 浅克隆仓库到临时目录
        echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
        git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
            echo "Failed to clone repository"
            exit 1
        }
        source /tmp/Dotfiles/ubuntu_install_tools.sh

    elif [[ $os_type == "fedora" ]]; then
        sudo dnf -y update
        tools=("zsh" "git" "curl" "make" "g++" "gcc" "openssh-server" "man-db" "wget" "llvm" "clang
" "clang-devel" "clang-tools-extra" "cmake" "fastfetch" "lua" "bat" "ripgrep" "fd-find" "eza" "fzf" "rustup" "graphviz")
        # 遍历工具列表，检查是否已安装
        for tool in "${tools[@]}"; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                sudo dnf install -y "$tool"
            fi
        done
        # 浅克隆仓库到临时目录
        echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
        git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
            echo "Failed to clone repository"
            exit 1
        }
        source /tmp/Dotfiles/fedora_install_tools.sh

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

# ================================= 开始安装 dotfiles =================================

# Ensure XDG base directories exist
mkdir -p "$HOME/.config/zsh/plugins" "${HOME}/.config/kitty" "$HOME/.cache/zsh" "${HOME}/.local/share/zinit" "$HOME/.local/state"

# 定义配置列表
configs=(".zshenv" ".zprofile" ".zshrc" ".config/kitty" ".config/zsh")

# 删除旧配置和复制新配置
echo -e "${YELLOW}🔍 Checking and removing old configuration files if they exist...${NC}"
for config in "${configs[@]}"; do
    if [[ -f "${HOME}/${config}" ]] || [[ -d "${HOME}/${config}" ]]; then
        echo -e "${RED}🗑️ Removing old ${HOME}/${config} ${NC}"
        sudo rm -rf "${HOME}/$config"
    fi
    echo -e "${PURPLE}📋 Moving new ${config} to ${HOME}/${config} ${NC}"
    cp -r "${TMP_DIR}/${config}" "${HOME}/${config}"
done

# 针对 macOS 的配置,
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

# 添加 karabiner 的配置文件：karabiner.json
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ -f "${HOME}/.config/karabiner/karabiner.json" ]]; then
        echo -e "${RED}🗑️ Removing old karabiner.json....${NC}"
        sudo rm -rf "${HOME}/.config/karabiner/karabiner.json"
    fi
    echo -e "${PURPLE}📋 Copying new karabiner.json to "${HOME}/.config/karabiner/karabiner.json"...${NC}"
    cp -r "${TMP_DIR}/.config/karabiner/karabiner.json" "${HOME}/.config/karabiner/karabiner.json"
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
~/.config/zsh/plugins/zinit-plugin.zsh

rm -rf $HOME/.zcompdump $HOME/.zsh_history

# ================================= 结束安装 dotfiles =================================
