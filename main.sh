#!/bin/bash

# 一旦错误，就退出
set -e

# 加载 packages
source /tmp/Dotfiles/package.sh

# 加载辅助函数
source /tmp/Dotfiles/auxiliary_function.sh

if [[ $(uname -s) == "Darwin" ]]; then
    source /tmp/Dotfiles/macos_install.sh

elif [[ $(uname -s) == "Linux" ]]; then

    # 检测操作系统
    os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    print_centered_message "${CYAN}检测到操作系统为: $os_type${NC}"

    # 根据操作系统安装......
    if [[ $os_type == "ubuntu" ]]; then
        source /tmp/Dotfiles/ubuntu_install.sh

    elif [[ $os_type == "fedora" ]]; then
        source /tmp/Dotfiles/fedora_install.sh

    else
        print_centered_message "${RED}不支持的发行版，目前只支持 fedora、ubuntu${NC}"
    fi

    # 设置抓包工具权限。设置 setuid 位，无论当前用户是谁，执行 tcpdump 的时候，把用户修改为该程序文件所有者的 ID（通常是 root）。即假装是 root 用户执行 tcpdump 命令。
    sudo chmod u+s $(command -v tcpdump)
    sudo chmod u+s $(command -v dumpcap)
    sudo chmod u+s $(command -v tshark)

else
    echo -e "${MAGENTA}未知的操作系统类型${NC}"
fi

# 针对 macos、linux 统一配置 zsh
source /tmp/Dotfiles/zsh_install.sh
