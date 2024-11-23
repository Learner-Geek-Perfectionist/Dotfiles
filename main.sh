#!/bin/bash

# 一旦错误，就退出
set -e

# 定义日志文件路径
LOG_FILE="install.log"

# 重定向整个脚本的输出到日志文件，并覆盖之前的日志
exec > >(tee "$LOG_FILE") 2>&1

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

    if [[ "$AUTO_RUN" == "true" ]]; then
        echo "Dockerfile 中无需设置 $(whoami) 权限"
    else
        # 赋予用户 sudo 权限
        if [[ $os_type == "ubuntu" ]]; then
            sudo usermod -aG sudo "$username"
        elif [[ $os_type == "fedora" ]]; then
            sudo usermod -aG wheel "$username"
        fi
    fi

    # 根据操作系统安装......
    if [[ $os_type == "ubuntu" ]]; then
        source ./ubuntu_install.sh

    elif [[ $os_type == "fedora" ]]; then
        source ./fedora_install.sh

    else
        print_centered_message "${RED}不支持的发行版，目前只支持 fedora、ubuntu${NC}"
    fi

    # 修改默认的登录 shell 为 zsh
    [[ $SHELL != */zsh ]] && echo "修改默认的 shell 为 zsh " && sudo chsh -s $(which zsh)
    
    echo $(which tcpdump)
    echo $(which dumpcap)
    echo $(which tshark)
    # 设置工具权限
    /bin/zsh -c 'sudo chmod u+s $(which tcpdump); sudo chmod u+s $(which dumpcap); sudo chmod u+s $(which tshark)'
    
else
    echo -e "${MAGENTA}未知的操作系统类型${NC}"
fi


# 针对 macos、linux 统一配置 zsh
source ./zsh_install.sh

    
