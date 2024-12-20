#!/bin/bash

# 一旦错误，就退出
set -e

# 加载 packages
source ./package.sh

# 加载辅助函数
source ./auxiliary_function.sh

if [[ $(uname -s) == "Darwin" ]]; then
    source ./macos_install.sh

elif [[ $(uname -s) == "Linux" ]]; then

    # 检测操作系统
    os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    print_centered_message "${CYAN}检测到操作系统为: $os_type${NC}"

    # 根据操作系统安装......
    if [[ $os_type == "ubuntu" ]]; then
        source ./ubuntu_install.sh

    elif [[ $os_type == "fedora" ]]; then
        source ./fedora_install.sh

    else
        print_centered_message "${RED}不支持的发行版，目前只支持 fedora、ubuntu${NC}"
    fi

    # 修改默认的登录 shell 为 zsh
    # 获取当前用户的默认 shell
    current_shell=$(getent passwd "$(whoami)" | cut -d: -f7)
    # 如果当前 shell 不是 zsh，则更改为 zsh
    [[ "$(command -v zsh)" != "$current_shell" ]] && sudo chsh -s "$(command -v zsh)" "$(whoami)"
    
    # 设置抓包工具权限
    sudo chmod u+s $(command -v tcpdump); sudo chmod u+s $(command -v dumpcap); sudo chmod u+s $(command -v tshark)
    
else
    echo -e "${MAGENTA}未知的操作系统类型${NC}"
fi

# 更改 kotlin 目录权限
[[ -d "/opt/kotlin-native/" ]] && sudo chmod -R a+rw /opt/kotlin-native/
[[ -d "/opt/kotlin-compiler/" ]] && sudo chmod -R a+rw /opt/kotlin-compiler/

# 针对 macos、linux 统一配置 zsh
source ./zsh_install.sh

    
