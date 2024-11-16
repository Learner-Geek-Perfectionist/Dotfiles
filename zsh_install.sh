#!/bin/bash

# 打印提示消息
# print_centered_message "按任意键继续，否则超时停止"

# 打印倒计时提示
#countdown "60" # 根据需求，是否倒计时。

# 定义是否安装字体的标志符
install_flag=false

# 打印提示消息
print_centered_message "\n⏰ 注意：某些终端模拟器可能需要特定的字体以正确显示字符。如果你正在使用的终端模拟器对字体渲染有特殊要求，或者你希望确保字符显示的美观和一致性，可能需要下载和安装额外的字体。\n\n下载字体可以改善字符显示效果，特别是对于多语言支持或特殊符号的显示。🌐\n\n\t1️⃣ 在虚拟机中运行时，字体渲染依赖虚拟机特定的字体，因此需要安装字体。\n\t2️⃣ 在 Docker 容器（或 WSL）中运行时，通常不需要在容器（或 WSL）内安装字体，但应确保宿主机已安装适当的字体以支持任何可能的字体渲染需求。\n\n‼️ 宿主机一般需要良好的字体支持来确保所有应用和终端模拟器都能正常渲染字符。\n"

# 加载提示头
prompt_download_fonts

# 定义 Dotfiles 和 Fonts 链接
Dotfiles_REPO_URL="https://github.com/Learner-Geek-Perfectionist/dotfiles/archive/refs/heads/master.zip"
Fonts_REPO_URL="https://github.com/Learner-Geek-Perfectionist/Fonts/archive/refs/heads/master.zip"

# 定义文件和目标目录名称
zip_Fonts_file="Fonts-master.zip"
zip_Dotfiles_file="Dotfiles-master.zip"

dest_Fonts="Fonts-master"
dest_Dotfiles="Dotfiles-master"




# 对 Fonts 的处理：
# 如果安装标志（$install_flag）为真，并且ZIP文件不存在，则下载并解压ZIP文件；如果ZIP文件已经存在，则检查目录是否存在，不存在则解压，存在则跳过解压。

if [[ $install_flag == "true" ]]; then
  if [ ! -f "$zip_Fonts_file" ]; then
    print_centered_message "Fonts ZIP 文件不存在，开始下载..."
    download_and_extract "$zip_Fonts_file" "$dest_Fonts" "$Fonts_REPO_URL"
  else
    print_centered_message "Fonts ZIP 文件已存在，不需要下载。"
    if [ ! -d "$dest_Fonts" ]; then
      print_centered_message "开始解压已存在的 Fonts ZIP 文件..."
      unzip -o "$zip_Fonts_file" -d "$dest_Fonts"
    else
      print_centered_message "Fonts 目录已存在，跳过解压。"
    fi
  fi
fi


# 总是下载和解压 Dotfiles
download_and_extract "$zip_Dotfiles_file" "$dest_Dotfiles" "$Dotfiles_REPO_URL"


# 打印提示消息
print_centered_message "Dotfile 完成下载和解压"

# 定义字体的源目录
font_source="./${dest_Fonts}/fonts"
# 根据操作系统设置字体的安装目录
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS 用户目录，通常不需要 sudo 权限
  font_dest="$HOME/Library/Fonts"
else
  # Linux 用户目录，通常不需要 sudo 权限
  font_dest="$HOME/.local/share/fonts"
fi

# 安装字体
install_fonts

# 打印提示消息
print_centered_message "接下来配置 zsh......"

# 定义 zsh 的配置文件目录
destination="$HOME"

# 对 zsh 进行配置
copy_config_files_to_home

echo -e "\n"
# 打印提示消息
print_centered_message "zsh 配置文件已配置到 Home 目录"

print_centered_message "进入 zsh，准备下载 zsh 插件......"

# 修改默认的登录 shell 为 zsh
[[ $SHELL != */zsh ]] && echo "修改默认的 shell 为 zsh " && chsh -s $(which zsh)

# 进入 zsh
/bin/zsh


print_centered_message "对于 macOS 的用户，XApp、腾讯文档、FastZip、State、WeLink 只能通过 App Store 手动安装！！！"

# 提示：需要注销并重新登录以应用用户组更改
print_centered_message "Please log out and back in to apply user group changes."
