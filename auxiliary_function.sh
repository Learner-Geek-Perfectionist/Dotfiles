#!/bin/bash

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

install_docker() {
    echo "获取 Docker 安装脚本..."
    curl -fsSL https://get.docker.com -o get-docker.sh || { echo "下载安装脚本失败"; exit 1; }
    echo "运行安装脚本..."
    sudo sh get-docker.sh || { echo "安装 Docker 失败"; exit 1; }
    echo "将当前用户添加到 docker 组..."
    sudo usermod -aG docker ${USER} || { echo "添加用户到 docker 组失败"; exit 1; }
    echo "启动并设置 Docker 服务开机自启..."
    sudo systemctl start docker && sudo systemctl enable docker || { echo "启动或设置开机自启失败"; exit 1; }
    echo "Docker 安装完成。请考虑重新登录或重启以使组设置生效。"
}


install_and_configure_docker() {
    print_centered_message "检查 Docker 命令..." "true" "false"

    if grep -qi microsoft /proc/version; then
        echo "在 WSL2 环境中运行"
        if command -v docker >/dev/null; then
            if [ "$(docker context show 2>/dev/null)" = "desktop-windows" ]; then
                echo "检测到 Docker 运行在 Windows Docker Desktop 上。"
                echo "准备在 WSL2 中安装独立的 Docker 版本..."
                install_docker
            else
                echo "Docker 已安装在 WSL2 中，跳过安装步骤。"
            fi
        else
            echo "Docker 未安装，开始安装过程..."
            install_docker
        fi
    else
        if command -v docker >/dev/null; then
            echo "Docker 已安装，跳过安装步骤。"
        else
            echo "Docker 未安装，开始安装过程..."
            install_docker
        fi
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

    print_centered_message "Docker 镜像配置完成。" "false" "true"
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
