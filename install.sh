#!/bin/bash

# 当脚本出现错误时，打印出错误信息和发生错误的行号
trap 'echo "Error at line $LINENO: $BASH_COMMAND"' ERR

# 设置脚本在运行中遇到错误时立即退出
set -e

# 定义打印 message 的函数
print_centered_message() {
  local message="$1"
  local cols=$(tput cols)
  local line=''

  # 创建横线，长度与终端宽度相等
  for ((i = 0; i < cols; i++)); do
    line+='-'
  done

  # 打印上边框
  echo "$line"

  # 计算并居中打印消息
  local padded_message="$(printf '%*s' $(((cols + ${#message}) / 2)) "$message")"
  echo -e "$padded_message"

  # 打印下边框
  echo "$line"
}

# 获取当前操作系统类型
OS_TYPE=$(uname)

if [[ $OS_TYPE == "Darwin" ]]; then
  # macOS 逻辑
  print_centered_message "检测到 macOS 系统"
  

  if ! xcode-select --print-path &>/dev/null; then
     print_centered_message "Xcode 命令行工具未安装"
     xcode-select --install
     # 等待用户完成 Xcode 命令行工具的安装
     print_centered_message "请手动点击屏幕中的弹窗，选择“安装”，安装完成之后再次运行脚本"
     print_centered_message "脚本命令：\n(curl -sSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/dotfiles/master/install.sh | bash) && zsh"
     exit 1
  fi

  

  # 检查 Homebrew 是否已安装
  if command -v brew >/dev/null 2>&1; then
    print_centered_message "Homebrew 已经安装，跳过安装步骤。"
  else
    print_centered_message "正在安装 Homebrew..."
    /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
  fi
  
  # 刷新 brew 配置
  source ${HOME}/.zprofile
  
  print_centered_message "正在安装 macOS 常用的开发工具......"

  # 定义函数，接受一个包含包名的数组变量名作为参数
  check_and_install_brew_packages() {
    local package_group_name="$1"
    local package
    local uninstalled_packages=()
    local timestamp
    local log_file

    # 生成时间戳和日志文件名
    timestamp=$(date +"%Y%m%d_%H%M%S")
    log_file="./brew_install_logs/failed_to_install_$timestamp.txt" # 指定日志文件路径

    # 确保日志文件目录存在
    mkdir -p ./brew_install_logs

    # 使用间接扩展访问数组
    eval "packages=(\"\${${package_group_name}[@]}\")"

    # 获取已安装的 Homebrew 包列表，存入数组
    IFS=$'\n' read -d '' -r -a installed_packages < <(brew list && printf '\0')

    for package in "${packages[@]}"; do
      echo "检查是否已安装 $package ..."

      if printf '%s\n' "${installed_packages[@]}" | grep -q "^$package$"; then
        echo "$package 已通过 Homebrew 安装。"
        continue
      fi

      echo "$package 未通过 Homebrew 安装，正在检查 Homebrew 信息..."
      if brew info "$package" | grep -q "Not installed"; then
        echo "使用 Spotlight 搜索 $package ..."
        # 使用 Spotlight 搜索程序路径
        found_path=$(mdfind "kMDItemDisplayName == '$package'wc" | head -n 1)
        if [[ -n $found_path ]]; then
          echo "$package 已通过系统中的 Spotlight 找到，路径为: $found_path"
        else
          echo "$package 未通过 Spotlight 找到，尝试通过 Homebrew 安装..."
          if brew install "$package"; then
            echo "$package 安装成功。"
          else
            echo "通过 Homebrew 安装 $package 失败。"
            uninstalled_packages+=("$package")
            echo "$package 安装失败。" >>"$log_file"
          fi
        fi
      else
        echo "Homebrew 中没有 $package 的信息，无法安装。"
        uninstalled_packages+=("$package")
        echo "$package 无法通过 Homebrew 安装。" >>"$log_file"
      fi
    done

    # 总结结果
    if [[ ${#uninstalled_packages[@]} -gt 0 ]]; then
      echo "以下包未能成功安装或找到，详情请查看 $log_file："
      printf '%s\n' "${uninstalled_packages[@]}"
    else
      echo "所有包均已成功处理。"
    fi
  }

  brew_formulas=(
    bash gettext llvm msgpack ruby
    brotli git lpeg ncurses sqlite
    c-ares htop lua neovim tree-sitter
    ca-certificates icu4c luajit node unibilium
    cmake libnghttp2 luv openssl@3 vim
    cmake-docs libsodium lz4 pcre2 xz
    fastfetch libuv lzip python z3
    fd libvterm make readline zstd
    fzf libyaml mpdecimal ripgrep
    gcc ninja wget mas pkg-config
  )

  # 安装 brew_formulas 包
  check_and_install_brew_packages "brew_formulas"

  print_centered_message "开发工具安装完成✅"

  print_centered_message "正在安装 macOS 常用的带图形用户界面的应用程序......"

  brew_casks=(
    alfred videofusion wpsoffice tencent-meeting google-chrome
    orbstack dingtalk baidunetdisk anaconda iina
    pycharm android-studio input-source-pro qq chatgpt
    intellij-idea qqmusic clash-verge-rev jetbrains-gateway telegram
    clion jordanbaird-ice visual-studio-code discord keycastr wechat
    douyin kitty feishu microsoft-edge
  )

  # 安装 brew_casks 包
  check_and_install_brew_packages "brew_casks"

  print_centered_message "图形界面安装完成✅"

  print_centered_message "通过 uuid 安装 Application"
  
  # 定义一个包含应用UUID的数组
  declare -A apps
  apps=(
      ["XApp-应用程序完全卸载清理专家"]="2116250207"
      ["腾讯文档"]="1370780836"
      ["FastZip - 专业的 RAR 7Z ZIP 解压缩工具"]="1565629813"
      ["State-管理电脑CPU、温度、风扇、内存、硬盘运行状态"]="1472818562"
      ["HUAWEI CLOUD WeLink-办公软件"]="1530487795"
  )
  
  # 检查是否已安装mas
  if ! command -v mas &> /dev/null
  then
      echo "mas-cli 未安装。正在通过Homebrew安装..."
      brew install mas
      if [ $? -ne 0 ]; then
          echo "安装mas失败，请手动安装后重试。"
          exit 1
      fi
  fi
  
  # 登录App Store（如果尚未登录）
  if ! mas account > /dev/null; then
      echo "你尚未登录App Store。请先登录。"
      open -a "App Store"
      read -p "登录后请按回车继续..."
  fi
  
  # 安装应用
  for app in "${!apps[@]}"
  do
      echo "正在安装: $app"
      mas install ${apps[$app]}
      echo "$app 安装完成"
  done

print_centered_message "所有应用安装完成。"

elif [[ $OS_TYPE == "Linux" ]]; then

  # 检测操作系统
  os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

  print_centered_message "检测到操作系统为: $os_type"

  # 询问是否创建用户
  read -p "是否需要创建用户？(y/n): " create_confirm </dev/tty

  # 检查并设置密码的函数
  set_password_if_needed() {
    local user=$1
    local default_password=$2
    if ! sudo passwd -S "$user" | grep -q ' P '; then
      echo "用户 $user 的密码未设置，现在将密码设置为 $default_password"
      echo "$user:$default_password" | sudo chpasswd
      echo "密码已设置。"
    else
      echo "用户 $user 的密码已经存在。"
    fi
  }

  # 主逻辑
  if [[ $create_confirm == 'y' ]]; then
    read -p "请输入你想创建的用户名: " username </dev/tty
    read -p "请输入默认密码（将用于新用户，若按下 Enter ，密码默认为 1）: " default_password </dev/tty
    # 如果未输入任何内容，则默认密码为 1
    default_password="${default_password:-1}"

    if id "$username" &>/dev/null; then
      echo "用户 $username 已存在。"
      set_password_if_needed "$username" "$default_password"
    else
      sudo useradd -m "$username" # 创建用户
      echo "$username:$default_password" | sudo chpasswd
      echo "用户 $username 已创建，密码设置为 $default_password"
    fi
  else
    echo "不创建用户"
    # 默认密码为 1
    default_password=1
    # 如果 username 变量未设置或为空，则默认为当前登录用户的用户名
    username="${username:-$(whoami)}"
    set_password_if_needed "$username" "$default_password"
  fi

  # 赋予用户 sudo 权限
  if [[ $os_type == "ubuntu" ]]; then
    sudo usermod -aG sudo "$username"
  elif [[ $os_type == "fedora" ]]; then
    sudo usermod -aG wheel "$username"
  fi

  # 将用户添加到 sudoers 文件以免输入密码
  echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
  print_centered_message "已配置用户 $username 无需 sudo 密码。"

  # 设置时区和环境变量
  sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  sudo sh -c 'echo "Asia/Shanghai" > /etc/timezone'
  sudo sh -c 'echo "export TZ=Asia/Shanghai" >> /etc/profile'

  # 根据操作系统设置软件源
  if [[ $os_type == "ubuntu" ]]; then
    sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y openssh-server net-tools git unzip fzf ninja-build neovim ruby-full cmake nodejs iputils-ping procps htop traceroute tree coreutils zsh fontconfig python3 iproute2 kitty wget2 pkg-config
  elif [[ $os_type == "fedora" ]]; then
    sudo sed -e 's|^metalink=|#metalink=|g' \
      -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
      -i.bak \
      /etc/yum.repos.d/fedora.repo \
      /etc/yum.repos.d/fedora-updates.repo

    sudo dnf makecache
    sudo dnf update -y && sudo dnf install -y openssh-server iproute net-tools fd-find git unzip ripgrep fzf ninja-build neovim ruby kitty cmake nodejs iputils procps-ng htop traceroute fastfetch tree coreutils zsh fontconfig python3 wget2 pkgconf-pkg-config
    sudo dnf group install -y "C Development Tools and Libraries"
    sudo dnf clean all
  else
    print_centered_message -e "\n不支持的发行版，目前只支持 fedora、ubuntu\n"
  fi

else
  echo "未知的操作系统类型"
fi

# 打印提示消息
print_centered_message "按任意键继续，否则超时停止"

countdown() {
  local timeout=${1:-60}                  # 默认倒计时时间为60秒，可通过函数参数定制
  local message=${2:-"Waiting for input"} # 默认提示信息
  local str                               # 用户输入的字符串
  local key_pressed=0                     # 标志是否有按键被按下

  # 开始倒计时
  for ((i = timeout; i > 0; i--)); do
    echo -ne "\r${message} (timeout in $i seconds): "
    if read -t 1 -r -n1 str </dev/tty; then
      key_pressed=1 # 如果用户提前输入，则设置标志并跳出循环
      break
    fi
  done

  # 检查用户是否输入了内容或者时间是否超时
  if [[ $key_pressed -eq 0 ]]; then
    echo -e "\nTime out. No input received.\n"
    exit 1 # 使用 exit 1 终止脚本，表示因超时而结束
  else
    echo -e "\nUser input received: '$str'\n"
    return 0 # 返回 0 表示成功接收到用户输入
  fi
}

# 打印倒计时提示
countdown "60"

install_flag=false

# 提示用户是否需要下载字体
prompt_download_fonts() {
  read -p "是否需要下载字体以支持终端模拟器的渲染？(y/n): " download_confirm </dev/tty
  if [[ $download_confirm == 'y' ]]; then
    print_centered_message "正在下载字体......"
    install_flag=true
  else
    print_centered_message "跳过字体下载。"
  fi
}

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

# 定义下载和解压函数
download_and_extract() {
  # 压缩包名字
  local zip_file="$1"
  # 目录
  local dest_dir="$2"
  # 压缩包 URL
  local repo_url="$3"

  # 检查ZIP文件是否存在，如果不存在则下载
  if [ ! -f "$zip_file" ]; then
    print_centered_message "ZIP文件 '$zip_file' 不存在，开始下载..."
    curl -L -f -o "${zip_file}" "$repo_url"
    if [ -f "$zip_file" ]; then
      print_centered_message "ZIP文件 '$zip_file' 下载完成✅"
    else
      print_centered_message "ZIP文件 '$zip_file' 下载失败☹️"
    fi
  else
    echo "ZIP文件 '$zip_file' 已存在，跳过下载。"
  fi

  # 解压ZIP文件
  if [ -f "$zip_file" ]; then
    if [ ! -d "$dest_dir" ]; then
      echo "开始解压ZIP文件 '$zip_file' 到目录 '$dest_dir'..."
      unzip -o "$zip_file"
    else
      echo "目录 '$dest_dir' 已存在，跳过解压。"
    fi
  else
    echo "ZIP文件 '$zip_file' 不存在或损坏，无法进行解压。"
  fi
}

# 打印提示消息
print_centered_message "Dotfile 完成下载和解压"

# 对 Fonts 的处理，只在 ZIP 文件不存在时下载
if [[ $install_flag == "true" ]]; then
  download_and_extract "$zip_Fonts_file" "$dest_Fonts" "$Fonts_REPO_URL"
elif [[ $install_flag == "true" ]]; then
  print_centered_message "Fonts ZIP 文件已存在，不需要下载。"
  if [ ! -d "$dest_Fonts" ]; then
    if [ -f "$zip_Fonts_file" ]; then
      print_centered_message "开始解压已存在的 Fonts ZIP文件..."
      unzip -o "$zip_Fonts_file"
    else
      print_centered_message "Fonts ZIP 文件不存在或损坏，无法进行解压。"
    fi
  else
    print_centered_message "Fonts 目录已存在，跳过解压。"
  fi
fi

# 总是下载和解压Dotfiles
download_and_extract "$zip_Dotfiles_file" "$dest_Dotfiles" "$Dotfiles_REPO_URL"

# 定义字体的源目录
font_source="./${dest_Fonts}/fonts"
# 根据操作系统设置字体的安装目录
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS 用户目录，通常不需要sudo权限
  font_dest="$HOME/Library/Fonts"
else
  # Linux 用户目录，通常不需要sudo权限
  font_dest="$HOME/.local/share/fonts"
fi

# 定义一个函数来复制字体文件并更新字体缓存
install_fonts() {
  # 检查是否执行安装
  if [ "$install_flag" != "true" ]; then
    print_centered_message "安装标志设置为 'false'，跳过字体安装。"
    return 0 # 如果不安装，则正常退出
  fi

  # 打印提示消息
  print_centered_message "正在安装字体......"

  # 确认字体源目录存在
  if [ ! -d "$font_source" ]; then
    echo "字体目录 '$font_source' 不存在，请确认当前目录下有 ${dest_Fonts} 文件夹。"
    exit 1
  fi

  # 创建目标目录如果它不存在
  mkdir -p "$font_dest"

  # 复制字体文件到目标目录
  print_centered_message "正在复制字体文件到 $font_dest..."

  # 使用 find 来查找字体源目录中的字体文件，排除 README 文件
  find "$font_source" -type f \( -iname "*.ttf" -o -iname "*.otf" \) ! -iname "README*" -exec cp -v {} "$font_dest" \;

  # 更新字体缓存
  print_centered_message "更新字体缓存..."
  if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS不需要手动更新字体缓存
    print_centered_message "\n在 macOS 上，字体缓存将自动更新。\n"
  else
    # Linux
    print_centered_message "\n在 Linux 上，刷新字体缓存\n"
    fc-cache -fv
  fi

  # 打印提示消息
  print_centered_message "字体安装完成。✅"
}

# 安装字体
install_fonts

# 打印提示消息
print_centered_message "接下来配置 zsh......"

# 定义 zsh 的配置文件目录
destination="$HOME"

# 进入目录并复制配置文件到用户的 home 目录的函数
copy_config_files_to_home() {
  print_centered_message "正在配置......"
  local dir_name="${dest_Dotfiles}"
  local files_to_copy=(".zshrc" ".zprofile" ".config")

  # 进入仓库目录
  if [ -d "$dir_name" ]; then
    echo "已进入 '$dir_name' 目录。"
    cd "$dir_name"
  else
    echo "目录 '$dir_name' 不存在，无法进入。"
    return 1 # 返回非零状态表示失败
  fi

  # 循环遍历每个文件和目录
  for item in "${files_to_copy[@]}"; do
    if [ -e "$item" ]; then
      echo "正在复制 $item 到 $destination"
      # 复制文件或目录到 home 目录，如果存在则替换
      cp -r "$item" "$destination"
    else
      echo "$item 不存在，跳过复制。"
    fi
  done
}

# 对 zsh 进行配置
copy_config_files_to_home

# 打印提示消息
print_centered_message "zsh 配置文件已配置到 Home 目录"

print_centered_message "进入 zsh，准备下载 zsh 插件......"
