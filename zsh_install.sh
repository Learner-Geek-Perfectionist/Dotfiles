#!/bin/bash

# 打印提示消息
# print_centered_message "按任意键继续，否则超时停止"

# 打印倒计时提示
#countdown "60" # 根据需求，是否倒计时。

# 打印提示消息
# 输出重复的 "-" 直到填满一行
printf '%*s' "$(tput cols)" | tr ' ' '-'

echo -e "${YELLOW}⏰ 注意：某些终端模拟器可能需要特定的字体以正确显示字符。如果你正在使用的终端模拟器对字体渲染有特殊要求，或者你希望确保字符显示的美观和一致性，可能需要下载和安装额外的字体。\n${NC}"

echo -e "${BLUE}下载字体可以改善字符显示效果，特别是对于多语言支持或特殊符号的显示。🌐${NC}"

echo -e "${GREEN}\t1️⃣ 在虚拟机中运行时，字体渲染依赖虚拟机特定的字体，因此需要安装字体。${NC}"
echo -e "${GREEN}\t2️⃣ 在 Docker 容器（或 WSL）中运行时，通常不需要在容器（或 WSL）内安装字体，但应确保宿主机已安装适当的字体以支持任何可能的字体渲染需求。\n${NC}"

echo -e "${RED}‼️ 宿主机一般需要良好的字体支持来确保所有应用和终端模拟器都能正常渲染字符。${NC}"


# 加载提示头
install_fonts

#if [[ "$install_flag" == true ]]; then
#    git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Fonts.git /tmp/Fonts/
#    # 打印提示消息
#    print_centered_message "${GREEN}✅Fonts 完成下载${NC}" "true" "false"
#    # 定义字体的源目录
#    font_source="/tmp/Fonts/"
#
#    # 根据操作系统设置字体的安装目录
#    if [[ "$(uname)" == "Darwin" ]]; then
#        font_dest="$HOME/Library/Fonts"
#    else
#        font_dest="$HOME/.local/share/fonts"
#    fi
#
#    if [ "$AUTO_RUN" == "true" ]; then
#        echo "Dockerfile 中无需安装字体"
#    else
#        # 安装字体
#        install_fonts
#
#        # 打印提示消息
#        print_centered_message "${GREEN}Fonts 完成安装${NC}" "false" "false"
#    fi
#else
#    print_centered_message "${RED}❌不安装 Fonts${NC}" "true" "false"
#fi

# 打印提示消息
print_centered_message "${GREEN}接下来配置 zsh......${NC}" "false" "false"

# 对 zsh 进行配置
source ./zsh_config.sh

# 打印提示消息
print_centered_message "${GREEN}zsh 配置文件已复制到 Home 目录${NC}" "true" "false"

# 修改默认的登录 shell 为 zsh
[[ $SHELL != */zsh ]] && echo "修改默认的 shell 为 zsh " && chsh -s $(which zsh)

print_centered_message "${GREEN}进入 zsh ......${NC}" "false" "true"

# 进入 zsh
/bin/zsh

print_centered_message "对于 macOS 的用户，腾讯文档、FastZip、State、WeLink 只能通过 App Store 手动安装！！！"
