#!/bin/bash

# 定义日志文件路径
LOG_FILE="install.log"

# 重定向整个脚本的输出到日志文件，并覆盖之前的日志
exec > >(tee "$LOG_FILE") 2>&1

# 一旦错误，就退出
set -e 



# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # 没有颜色

# 定义打印居中消息的函数
print_centered_message() {
  local message="$1"
  local single_flag="${2:-true}" # 如果没有提供第二个参数，默认为 true
  local double_flag="${3:-true}" # 如果没有提供第三个参数，默认为 true
  local cols=$(tput cols)
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

LATEST_VERSION=""

get_latest_version() {
    
    # 使用 curl 获取 GitHub releases 最新的重定向地址，并且 grep 最新的版本号
    LATEST_VERSION=$(curl -s -L -I https://github.com/JetBrains/kotlin/releases/latest | grep -i location | sed -E 's/.*tag\/(v[0-9\.]+).*/\1/')
    # 输出最新的版本号，添加颜色
    print_centered_message "${LIGHT_BLUE}正在下载Kotlin/Native...... ${NC}" "true" "false"
    echo -e "${CYAN}The Latest Version of Kotlin/Native is $LATEST_VERSION${NC}" 
}



install_kotlin_native() {
    # 获取系统类型参数
    SYSTEM_TYPE=$1
    
    # 获取最新版本号
    get_latest_version

    # 获取系统架构
    ARCH=$(uname -m)
    
    case "$ARCH" in
        arm64 | armd64)
            ARCH="aarch64"  # 将 arm64 和 armd64 统一处理为 aarch64
            ;;
        x86_64)
            ARCH="x86_64"
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # 判断系统类型和架构支持
    case "$SYSTEM_TYPE" in
        "macos" | "linux")
            if [[ "$ARCH" == "x86_64" || "$ARCH" == "aarch64" ]]; then
                # 根据系统类型和架构构造下载 URL 和安装目录
                SUFFIX="kotlin-native-prebuilt-${SYSTEM_TYPE}-${ARCH}-${LATEST_VERSION#v}.tar.gz"
                DOWNLOAD_URL="https://github.com/JetBrains/kotlin/releases/download/$LATEST_VERSION/$SUFFIX"
                INSTALL_DIR="/opt/kotlin-native/"
            else
                echo "不支持的 ${SYSTEM_TYPE} 架构: $ARCH"
                return 0
            fi
            ;;
        *)
            echo "未知系统类型，请使用 'macos' 或 'linux' 作为参数。"
            return 0
            ;;
    esac
    
     # 显示下载和安装信息
    echo -e "${MAGENTA}下载 URL: $DOWNLOAD_URL${NC}"
    echo -e "${BLUE}安装目录: $INSTALL_DIR${NC}"
    
    # 检查是否已安装 Kotlin/Native
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${GREEN}Kotlin/Native 已安装在 $INSTALL_DIR。跳过安装。${NC}"
        return 0
    fi
    
    # 检查下载链接是否有效
    echo -e "${YELLOW}Checking the validity of the download URL: $DOWNLOAD_URL${NC}"


    HTTP_STATUS=$(curl -L -o /dev/null -s -w "%{http_code}" "$DOWNLOAD_URL")

    if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
        echo -e "${GREEN}下载链接有效，开始下载。${NC}"
    else
        print_centered_message "${RED}下载链接无效，HTTP 状态码: $HTTP_STATUS。请检查版本号或网络连接。${NC}" "false" "true"
        return 0
    fi

    # 下载 Kotlin/Native 二进制包
    echo "Downloading Kotlin/Native from: $DOWNLOAD_URL"
    curl -L $DOWNLOAD_URL -o /tmp/kotlin-native.tar.gz

    if [ $? -ne 0 ]; then
        print_centered_message   "下载失败，请检查网络连接和下载地址。"
        return 0
    fi

    # 解压并安装
    echo "Installing Kotlin/Native to: $INSTALL_DIR"
    sudo mkdir -p $INSTALL_DIR
    sudo tar -xzf /tmp/kotlin-native.tar.gz -C $INSTALL_DIR --strip-components=1

    if [ $? -ne 0 ]; then
        echo "解压失败，检查下载的文件是否正确。"
        return 0
    fi

    # 清理临时文件
    rm /tmp/kotlin-native.tar.gz

    # 检查是否成功安装
    if [ -d "$INSTALL_DIR" ]; then
        echo "Kotlin/Native $LATEST_VERSION 已成功安装到 $INSTALL_DIR"
    else
        echo "安装失败，目标目录未找到。"
        return 0
    fi
}

# 使用方法：传递 macos 或 linux 作为参数
# 示例： install_kotlin_native macos
# 示例： install_kotlin_native linux

# 定义 packages 安装函数，接受一个包组(packages group)作为参数
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

  # 获取需要安装的包的数组
  eval "packages=(\"\${${package_group_name}[@]}\")"

  # 获取通过 Homebrew 已安装的包
  local installed_packages=($(brew list))

  for package in "${packages[@]}"; do
    echo "🔍 检查是否已安装 $package ..."
  
    # 直接使用 brew list 检查包是否已安装
    if brew list "$package" &>/dev/null; then
      print_centered_message "🟢 $package 已通过 Homebrew 安装。" "false" "true"
    else
      print_centered_message "❌ $package 未安装，尝试通过 Homebrew 安装..." "false" "false"
      # 如果包未安装，则通过 Homebrew 安装
      if brew install "$package"; then
        print_centered_message "✅ $package 安装成功。" "false" "true"
      else
        print_centered_message "☹️ 通过 Homebrew 安装 $package 失败。" "false" "true"
        uninstalled_packages+=("$package")
        echo "📝 $package 安装失败。" >>"$log_file"
      fi
    fi
  done

  # 总结结果
  if [[ ${#uninstalled_packages[@]} -gt 0 ]]; then
    echo "⚠️ 以下包未能成功安装或找到，详情请查看 $log_file："
    printf '🚫 %s\n' "${uninstalled_packages[@]}"
  else
    print_centered_message "🎉 所有包均已成功处理。"
  fi
}


install_and_configure_docker() {
    # 检查 Docker 是否已经安装
    echo "检查 Docker 命令..."
    if ! docker_cmd=$(command -v docker); then
        echo "Docker 未安装或未正确配置在WSL2中，开始安装过程..."
        # 1. 获取安装脚本
        curl -fsSL https://get.docker.com -o get-docker.sh
        # 2. 运行安装脚本
        sudo sh get-docker.sh
        # 3. 将当前登录的用户添加到 docker 组
        sudo usermod -aG docker ${USER}
        # 4. 启动并且开机自启 Docker 服务
        sudo systemctl start docker && sudo systemctl enable docker
        echo "Docker 安装完成。"
    else
        print_centered_message "Docker 已安装，跳过安装步骤。" "true" "false"
        print_centered_message "Docker 命令位置：$docker_cmd" "true" "false"
    fi

    # 配置 Docker 镜像
    echo "配置 Docker 镜像..."
    sudo mkdir -p /etc/docker

    # 写入指定的镜像源到 daemon.json
    echo '{
      "registry-mirrors": [
        "https://docker.m.daocloud.io",
        "https://mirror.baidubce.com",
        "http://hub-mirror.c.163.com"
      ]
    }' | sudo tee /etc/docker/daemon.json > /dev/null

    # 重启 Docker 服务以应用新的配置
    sudo systemctl restart docker

    echo "Docker 镜像配置完成。"
}

# 定义设置用户密码函数
set_password_if_needed() {
  local user=$1
  local default_password=$2
  if ! sudo passwd -S "$user" | grep -q ' P '; then
    echo -n "用户 $user 的密码未设置，现在将密码设置为 「$default_password」 。"
    echo "$user:$default_password" | sudo chpasswd
    echo "密码已设置。"
  else
    echo "用户 $user 的密码已经存在。"
  fi
}

# 定义提示头🔔函数
prompt_download_fonts() {
  echo -n "是否需要下载字体以支持终端模拟器的渲染？(y/n): "
  read download_confirm
  if [[ $download_confirm == 'y' ]]; then
    print_centered_message "正在下载字体......"
    install_flag=true
  else
    print_centered_message "跳过字体下载。"
  fi
}

# 定义提示头🔔函数
prompt_open_proxy() {
  # 首先检查 clash-verge-rev 是否已经安装
  if brew list clash-verge-rev &>/dev/null; then
    print_centered_message "clash-verge-rev 已安装，无需重新下载"
    return 0  # 如果已安装，直接退出函数
  fi

  echo -n "是否需要开启代理软件？(y/n): "
  read open_confirm
  if [[ $open_confirm == 'y' ]]; then
    print_centered_message "正在下载 clash-verge-rev ......"
    brew install clash-verge-rev
    print_centered_message "重新执行脚本命令:" "true" "false"
    print_centered_message '/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh)"' "false" "true"
    exit 1
  else
    print_centered_message "不开启代理，继续执行脚本"
  fi
}

# 定义下载、解压函数
download_and_extract() {
  # 压缩包名称
  local zip_file="$1"
  # 目录
  local dest_dir="$2"
  # 压缩包 URL
  local repo_url="$3"

  # 检查 ZIP 文件是否存在，如果不存在则下载
  if [ ! -f "$zip_file" ]; then
    print_centered_message "ZIP文件 '$zip_file' 不存在，开始下载..."
    curl -L -f -o "${zip_file}" "$repo_url"
    if [ -f "$zip_file" ]; then
      echo -e "\n"
      print_centered_message "ZIP文件 '$zip_file' 下载完成✅"
    else
      print_centered_message "ZIP文件 '$zip_file' 下载失败☹️"
    fi
  else
    echo "ZIP文件 '$zip_file' 已存在，跳过下载。"
  fi

  # 解压 ZIP 文件
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

# 定义倒计时函数
countdown() {
  local timeout=${1:-60}                  # 默认倒计时时间为60秒，可通过函数参数定制
  local message=${2:-"Waiting for input"} # 默认提示信息
  local str                               # 用户输入的字符串
  local key_pressed=0                     # 标志是否有按键被按下

  # 开始倒计时
  for ((i = timeout; i > 0; i--)); do
    echo -ne "\r${message} (timeout in $i seconds): "
    if read -t 1 -r -n1 str ; then
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

# 定义安装字体函数
install_fonts() {
  # 检查是否执行安装
  if [ "$install_flag" != "true" ]; then
    echo -e "\n"
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
    # macOS 不需要手动更新字体缓存
    print_centered_message "\n在 macOS 上，字体缓存将自动更新。\n"
  else
    # Linux
    print_centered_message "\n在 Linux 上，刷新字体缓存\n"
    fc-cache -fv
  fi

  # 打印提示消息
  print_centered_message "字体安装完成。✅"
}

# 进入目录并复制配置文件到用户的 home 目录的函数
copy_config_files_to_home() {
  print_centered_message "正在配置......"
  local dir_name="${dest_Dotfiles}"
  local files_to_copy=(".zshrc" ".zprofile" ".config")
  local home_dir="$HOME"

  # 删除已有的 zshrc、zprofile 和 config
  print_centered_message "检查并删除已有的 .zshrc、.zprofile 和 .config 文件/文件夹..."
  for file in ".zshrc" ".zprofile" ".config"; do
    if [ -e "$home_dir/$file" ]; then
      echo "删除 $home_dir/$file"
      rm -rf "$home_dir/$file"
    fi
  done

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

# 获取当前操作系统类型
OS_TYPE=$(uname)

if [[ $OS_TYPE == "Darwin" ]]; then
  # macOS 逻辑
  echo -e "\n"
  
  print_centered_message "检测到 macOS 系统"

  # 进入 Documents 目录
  cd ~/Documents

  


  if ! xcode-select --print-path &>/dev/null; then
    print_centered_message "⚠️ Xcode 命令行工具未安装"
    xcode-select --install 2>/dev/null
    # 等待用户完成 Xcode 命令行工具的安装
    print_centered_message "请手动点击屏幕中的弹窗，选择“安装”，安装完成之后再次运行脚本(提示命令通常在终端的背面)"
    print_centered_message "脚本命令:" "true" "false"
    print_centered_message '/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh)"' "false" "true"
    exit 1
  fi

  # 检查 Homebrew 是否已安装
  if command -v brew >/dev/null 2>&1; then
    print_centered_message "Homebrew 已经安装，跳过安装步骤。"
  else
    print_centered_message "正在安装 Homebrew..."
    #    /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
    curl -O "https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh"
    chmod +x ./Homebrew.sh
    ./Homebrew.sh
    echo -e "\n"
    print_centered_message "重新加载 .zprofile 文件以启用 brew 环境变量 "
    # 刷新 brew 配置，启用 brew 环境变量
    source ${HOME}/.zprofile
  fi

  [[ -f "./Homebrew.sh" ]] && rm "./Homebrew.sh" && echo "文件已被删除。" || echo "文件不存在。"
   
  print_centered_message "为了能顺利安装 Homebrew 的 cask 包，请打开代理软件，否则下载速度很慢（推荐选择香港 🇭🇰  或者 新加坡 🇸🇬  节点，如果速度还是太慢，可以通过客户端查看代理情况）" "true" "false"
  print_centered_message "如果下载进度条卡住，在代理客户端中，多次切换「全局模式」或者「规则模式」，并且打开 TUN 选项。" "false" "true"
  
  prompt_open_proxy
  
  print_centered_message "正在安装 macOS 常用的开发工具......"

  brew_formulas=(
    gettext msgpack ruby graphviz kotlin python
    brotli git lpeg ncurses sqlite openjdk grep
    c-ares htop lua neovim tree-sitter bash tcpdump
    ca-certificates icu4c luajit node unibilium
    cmake libnghttp2 luv openssl@3 vim perl
    cmake-docs libsodium lz4 pcre2 xz llvm
    fastfetch libuv lzip z3 tree rust
    fd libvterm make readline zstd
    fzf libyaml mpdecimal ripgrep go
    gcc ninja wget mas pkg-config jq
  )


  echo -e "\n"

  print_centered_message "准备安装 Kotlin/Native"

  # 安装 Kotlin/Native
  install_kotlin_native "macos"

  # 安装 brew_formulas 包
  check_and_install_brew_packages "brew_formulas"

  print_centered_message "开发工具安装完成✅"

  print_centered_message "正在安装 macOS 常用的带图形用户界面的应用程序......"

  brew_casks=(
    alfred videofusion wpsoffice tencent-meeting google-chrome
    orbstack dingtalk baidunetdisk anaconda iina KeepingYouAwake
    pycharm android-studio input-source-pro qq chatgpt fleet
    intellij-idea qqmusic  jetbrains-gateway telegram
    clion jordanbaird-ice visual-studio-code discord keycastr wechat
    douyin kitty feishu microsoft-edge Eudic
  )

  # 安装 brew_casks 包
  check_and_install_brew_packages "brew_casks"

  # 安装 wireshark --cask 工具，因为 wireshark 既有命令行版本又有 cask 版本，因此手动加上 --cask 参数
  brew install --cask wireshark

  brew cleanup
  
  print_centered_message "图形界面安装完成✅"  

  # 通过 UUID 安装 Application，但是目前 macOS 15 sequoia 不支持！
  # print_centered_message "通过 uuid 安装 Application"

  # 定义一个包含应用 UUID 的数组
  # declare -A 来声明关联数组（也称为哈希表），在 Bash 4.0 版本中引入的。因此 macOS(的 shell 版本为 3.2.57)不支持。
  # declare -A apps
  # apps=(
  #   ["XApp-应用程序完全卸载清理专家"]="2116250207"
  #   ["腾讯文档"]="1370780836"
  #   ["FastZip - 专业的 RAR 7Z ZIP 解压缩工具"]="1565629813"
  #   ["State-管理电脑CPU、温度、风扇、内存、硬盘运行状态"]="1472818562"
  #   ["HUAWEI CLOUD WeLink-办公软件"]="1530487795"
  # )

  #  # 检查是否已安装mas
  #  if ! command -v mas &>/dev/null; then
  #    echo "mas-cli 未安装。正在通过Homebrew安装..."
  #    brew install mas
  #    if [ $? -ne 0 ]; then
  #      echo "安装mas失败，请手动安装后重试。"
  #      exit 1
  #    fi
  #  fi
  #
  #  # 登录App Store（如果尚未登录）
  #  if ! mas account >/dev/null; then
  #    echo "你尚未登录App Store。请先登录。"
  #    open -a "App Store"
  #    read -p "登录后请按回车继续..."
  #  fi
  #
  #  # 安装应用
  #  for app in "${!apps[@]}"; do
  #    echo "正在安装: $app"
  #    mas install ${apps[$app]}
  #    echo "$app 安装完成"
  #  done

  print_centered_message "所有应用安装完成。"

elif [[ $OS_TYPE == "Linux" ]]; then

  # 检测操作系统
  os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

  print_centered_message "检测到操作系统为: $os_type"

  # 询问是否创建用户
  read -p "是否需要创建用户？(y/n): " create_confirm

  # 检查并设置密码的函数

  # 主逻辑
  if [[ $create_confirm == 'y' ]]; then
    read -p "请输入你想创建的用户名: " username
    read -p "请输入默认密码（将用于新用户，若按下 Enter ，密码默认为 1）: " default_password
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

  
  # 根据操作系统设置软件源
  if [[ $os_type == "ubuntu" ]]; then
  
    # 设置国内源
    sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list

    # 取消最小化安装
    sudo apt update && sudo apt upgrade -y && sudo apt install -y unminimize
    yes | sudo unminimize
    
    # 安装必要的工具 🔧 
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y openssh-server debconf-utils net-tools git unzip zip ninja-build neovim ruby-full fd-find ripgrep cmake nodejs iputils-ping procps htop traceroute tree coreutils zsh fontconfig python3 iproute2 kitty wget pkg-config graphviz sudo tcpdump kotlin golang rustc software-properties-common valgrind curl tar locales man-db jq


    # 设置 Debconf，允许非root用户捕获数据包
    echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
    # 以非交互模式安装 Wireshark
    sudo DEBIAN_FRONTEND=noninteractive apt install -y wireshark
    # 设置 wireshark 权限
    # 1. 将 dumpcap 设置为允许 wireshark 组的成员执行：
    sudo chgrp wireshark /usr/bin/dumpcap
    sudo chmod 4755 /usr/bin/dumpcap
    sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap
    # 2.将用户添加到 wireshark 组：
    sudo usermod -aG wireshark $USER
    


    # 设置时区
    sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null
    sudo dpkg-reconfigure --frontend noninteractive tzdata

    # 设置地区
    sudo locale-gen zh_CN.UTF-8

    # 设置默认的语言环境
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    
    # 定义 fzf 的安装目录
    FZF_DIR="$HOME/.fzf"
    
    # 检查 fzf 是否已安装
    if command -v fzf >/dev/null 2>&1; then
        # 目录存在，跳过安装
        echo "fzf 已安装，跳过安装。"
    else
        # 目录不存在，克隆并安装 fzf
        echo "正在安装 fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
        yes | $FZF_DIR/install --no-update-rc
        echo "fzf 安装完成。"
    fi
    
    # 手动安装 fastfetch
    # 检查 fastfetch 是否已经安装
    if command -v fastfetch >/dev/null 2>&1; then
        echo "fastfetch 已经安装。跳过安装步骤。"
    else
        echo "开始安装 fastfetch..."
    
        # 克隆 fastfetch 源码
        git clone https://github.com/LinusDierheimer/fastfetch.git
        cd fastfetch
    
        # 创建构建目录并编译项目
        mkdir build && cd build
        cmake ..
        make
    
        # 安装 fastfetch
        sudo make install
    
        # 清理（可选）
        cd ../.. && rm -rf fastfetch
    
        echo "fastfetch 安装完成。"
    fi
    
    # 安装 Kotlin/Native
    install_kotlin_native "linux"
    
    # 安装 SDKMAN 和 java
    # 定义 SDKMAN 的安装目录
    
    # 检查 SDKMAN 是否已经安装
    if command -v sdk >/dev/null 2>&1; then
        echo "SDKMAN 已经安装。"
    else
        echo "开始安装 SDKMAN..."
        # 1. 下载并安装 SDKMAN
        curl -s "https://get.sdkman.io" | bash
    
        # 2. 初始化 SDKMAN 环境
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    
        echo "SDKMAN 安装完成。"
    fi
    
    # 检查 Java 是否已经安装
    if sdk list java | grep -q 'installed'; then
        echo "Java 已经安装。"
    else
        echo "开始安装 Java..."
        # 安装 Java
        sdk install java
        echo "Java 安装完成。"
    fi

   
    # 调用函数以安装和配置 Docker
    install_and_configure_docker
    
  elif [[ $os_type == "fedora" ]]; then
  
    # 注释 tsflags=nodocs，从而安装 manual 手册
    sudo sed -i '/tsflags=nodocs/s/^/#/' /etc/dnf/dnf.conf

    # 设置国内源
    sudo sed -e 's|^metalink=|#metalink=|g' \
      -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
      -i.bak \
      /etc/yum.repos.d/fedora.repo \
      /etc/yum.repos.d/fedora-updates.repo

    # 安装必要的工具 🔧
    sudo dnf -y update && sudo dnf install -y glibc glibc-common openssh-server iproute net-tools fd-find git unzip zip ripgrep fastfetch fzf ninja-build neovim ruby kitty cmake nodejs iputils procps-ng htop traceroute tree coreutils zsh fontconfig python3 wget pkgconf-pkg-config graphviz wireshark tcpdump java-latest-openjdk golang rust glibc-locale-source glibc-langpack-zh jq openssl && sudo dnf install -y --setopt=tsflags= coreutils coreutils-common man-pages man-db && sudo dnf group install -y --setopt=strict=0 "c-development" 

    # 设置 wireshark 权限 
    # 1. 将 dumpcap 设置为允许 wireshark 组的成员执行：
    sudo chgrp wireshark /usr/bin/dumpcap
    sudo chmod 4755 /usr/bin/dumpcap
    sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap
    # 2.将用户添加到 wireshark 组：
    sudo usermod -aG wireshark $username
    
    
    
    # 设置时区
    sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null

    # 设置语言环境变量
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8

    sudo localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8
    
    # 安装 kotlin
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk install kotlin


    # 安装 Kotlin/Native
    install_kotlin_native "linux"
    
 
    # 调用函数以安装和配置 Docker
    install_and_configure_docker

    sudo dnf clean all && sudo dnf makecache

    # 确保安装必要的 manual 手册
    sudo dnf -y reinstall $(rpm -qads --qf "PACKAGE: %{NAME}\n" | sed -n -E '/PACKAGE: /{s/PACKAGE: // ; h ; b }; /^not installed/ { g; p }' | uniq)
    # 生成和更新手册页的数据库
    sudo mandb -c
    
  else
    print_centered_message -e "不支持的发行版，目前只支持 fedora、ubuntu"
  fi

else
  echo "未知的操作系统类型"
fi

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


# 进入 zsh
/bin/zsh

if [ "$SHELL" = "/bin/zsh" ]; then
  print_centered_message "已进入 zsh shell。"
fi

print_centered_message "对于 macOS 的用户，XApp、腾讯文档、FastZip、State、WeLink 只能通过 App Store 手动安装！！！"

# 提示：需要注销并重新登录以应用用户组更改
print_centered_message "Please log out and back in to apply user group changes."
