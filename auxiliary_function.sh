#!/bin/bash

# 一旦错误，就退出
set -e

# 定义全局变量
KOTLIN_NATIVE_URL=""
KOTLIN_COMPILER_URL=""
INSTALL_DIR=""
COMPILER_INSTALL_DIR=""
LATEST_VERSION=""

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

get_latest_version() {
    # 使用 curl 获取 GitHub releases 最新的重定向地址，并且 grep 最新的版本号
    LATEST_VERSION=$(curl -s -L -I https://github.com/JetBrains/kotlin/releases/latest | grep -i location | sed -E 's/.*tag\/(v[0-9\.]+).*/\1/')
}

# 设置 kotlin 安装环境
setup_kotlin_environment() {
    # 获取系统架构
    ARCH=$(uname -m)

    # 安装目录初始化
    INSTALL_DIR="/opt/kotlin-native/"
    COMPILER_INSTALL_DIR="/opt/kotlin-compiler/"

    # 架构映射
    case "$ARCH" in
        arm64 | aarch64)
            ARCH="aarch64"
            ;;
        x86_64)
            ARCH="x86_64"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac

    # 获取最新的 Kotlin 版本
    get_latest_version

    # 确定系统类型
    case "$(uname -s)" in
        Darwin)
            SYSTEM_TYPE="macos"
            ;;
        Linux)
            SYSTEM_TYPE="linux"
            ;;
        *)
            echo -e "${RED}Unsupported system type: $(uname -s)${NC}"
            exit 1
            ;;
    esac

    # 构建下载 URL
    KOTLIN_NATIVE_URL="https://github.com/JetBrains/kotlin/releases/download/$LATEST_VERSION/kotlin-native-prebuilt-${SYSTEM_TYPE}-${ARCH}-${LATEST_VERSION#v}.tar.gz"
    KOTLIN_COMPILER_URL="https://github.com/JetBrains/kotlin/releases/download/$LATEST_VERSION/kotlin-compiler-${LATEST_VERSION#v}.zip"
}

# 下载和解压 Kotlin
download_and_extract_kotlin() {
    URL=$1
    TARGET_DIR=$2
    FILE_NAME=$(basename $URL)
    # 检测 Kotlin 是否已经安装
    if [ -d "$TARGET_DIR" ]; then
        print_centered_message "${GREEN}${FILE_NAME}${NC} is already installed in ${YELLOW}${TARGET_DIR}${NC}." "true" "true"
        return 0
    fi

    # 输出最新的版本号，添加颜色
    print_centered_message "${LIGHT_BLUE}正在下载 ${FILE_NAME}...... ${NC}" "true" "false"
    echo -e "${CYAN}The Latest Version is ${RED}${LATEST_VERSION}${NC}"
    echo -e "${YELLOW}Downloading ${BLUE}$FILE_NAME${YELLOW} from ${MAGENTA}$URL${YELLOW}...${NC}"

    # 使用 curl 下载文件，检查 URL 的有效性
    curl -L -f -s -S "${URL}" -o "/tmp/${FILE_NAME}" || {
        echo -e "${RED}❌ Failed to download $FILE_NAME.Please check your internet connection and URL.${NC}"
        return 0
    }

    echo -e "${YELLOW}Installing ${GREEN}$FILE_NAME${YELLOW} to ${BLUE}$TARGET_DIR${YELLOW}...${NC}"
    sudo mkdir -p $TARGET_DIR
    if [[ $FILE_NAME == *.tar.gz ]]; then
        sudo tar -xzf "/tmp/$FILE_NAME" -C $TARGET_DIR --strip-components=1 --overwrite
    elif [[ $FILE_NAME == *.zip ]]; then
        sudo unzip -o "/tmp/$FILE_NAME" -d $TARGET_DIR
    fi

    echo -e "${GREEN}$FILE_NAME has been installed successfully to $TARGET_DIR${NC}"
}

# 获取系统类型和相应的包管理器命令
detect_package_manager() {
    case "$(uname -s)" in
        Linux)
            if type apt > /dev/null 2>&1; then
                echo "apt"
            elif type dnf > /dev/null 2>&1; then
                echo "dnf"
            else
                echo -e "${RED}Unsupported package manager${NC}"
            fi
            ;;
        Darwin)
            echo "brew"
            ;;
        *)
            echo -e "${RED}Unsupported operating system${NC}"
            ;;
    esac
}

# 主函数
install_packages() {
    local package_manager=$(detect_package_manager)
    local package_group_name="$1"
    local packages
    local uninstalled_packages=()

    # 获取要安装的包数组
    eval "packages=(\"\${${package_group_name}[@]}\")"

    # 根据包管理器获取已安装的包
    case "$package_manager" in
        brew)
            installed_packages=$(brew list)
            ;;
        apt)
            installed_packages=$(dpkg -l | awk '{print $2}')
            ;;
        dnf)
            installed_packages=$(dnf list installed | awk '{print $1}')
            ;;
        *)
            echo -e "${RED}Unsupported package manager${NC}"
            return 1
            ;;
    esac

   # 筛选出尚未安装的包
    for package in "${packages[@]}"; do
        if ! echo "$installed_packages" | grep -q -E "^$package(:.*)?$"; then
            uninstalled_packages+=("$package")
        fi
    done


    # 如果未安装包的数组为空，打印消息并返回
    if [[ ${#uninstalled_packages[@]} -eq 0 ]]; then
        print_centered_message "🎉 ${GREEN}All packages were already installed.${NC}"
        return 0
    else
        # 如果数组不为空，打印需要安装的包
        print_centered_message "${RED}The following packages need to be installed:${NC}"
        for package in "${uninstalled_packages[@]}"; do
            echo "- $package"
        done
    fi
    
    # 一次性安装所有未安装的包
    print_centered_message "${LIGHT_BLUE}Installing ${#uninstalled_packages[@]} packages...${NC}"
    sudo $package_manager install -y "${uninstalled_packages[@]}"
}


install_docker() {
    echo -e "${BLUE}获取 Docker 安装脚本...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh || {
        echo -e "${DARK_RED}下载安装脚本失败${NC}"
        exit 1
    }
    echo -e "${BLUE}运行安装脚本...${NC}"
    sudo sh get-docker.sh || {
        echo -e "${DARK_RED}安装 Docker 失败${NC}"
        exit 1
    }

    echo -e "${BLUE}将当前用户添加到 docker 组...${NC}"
    sudo usermod -aG docker ${USER} || {
        echo -e "${DARK_RED}添加用户到 docker 组失败${NC}"
        exit 1
    }
    echo -e "${BLUE}启动并设置 Docker 服务开机自启...${NC}"
    sudo systemctl start docker && sudo systemctl enable docker || {
        echo -e "${DARK_RED}启动或设置开机自启失败${NC}"
        exit 1
    }
    echo -e "${GREEN}Docker 安装完成。请考虑重新登录或重启以使组设置生效。${NC}"

}

# Docker 安装和配置函数
install_and_configure_docker() {
    print_centered_message "${LIGHT_BLUE}开始检查 Docker 环境..." "true" "false"

    # 检查是否在 WSL2 中运行
    if grep -qi microsoft /proc/version; then
        echo -e "${YELLOW}在 WSL2 环境中运行${NC}"
        docker_path=$(command -v docker)
        if [ -n "$docker_path" ] && [[ "$docker_path" == "/mnt/c/"* ]]; then
            echo -e "${YELLOW}检测到 Docker 运行在 Windows Docker Desktop 上。${NC}"
            echo -e "${YELLOW}准备在 WSL2 中安装独立的 Docker 版本...${NC}"
            install_docker
        elif [ -n "$docker_path" ]; then
            echo -e "${GREEN}Docker 已安装在 WSL2 中，跳过安装步骤。${NC}"
        else
            echo -e "${YELLOW}Docker 未安装，开始安装过程...${NC}"
            install_docker
        fi
    else
        # 检查是否在普通 Linux 环境中运行
        if command -v docker > /dev/null; then
            echo -e "${GREEN}Docker 已安装✅，跳过安装步骤。${NC}"
        else
            echo -e "${YELLOW}Docker 未安装，开始安装过程...${NC}"
            install_docker
        fi
    fi

    # 配置 Docker 镜像
    echo -e "${CYAN}配置 Docker 镜像...${NC}"
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

    print_centered_message "${GREEN}Docker 镜像配置完成。✅${NC}" "false" "true"
}

# 安装字体
install_fonts() {
    # 为了避免 Dockerfile 交互式
    if [[ "$AUTO_RUN" == "true" ]]; then
        return 0
    fi

    # 如果不是自动运行，显示提示并读取用户输入
    echo -ne "${GREEN}是否需要下载字体以支持终端模拟器的渲染？(y/n): ${NC}"
    read download_confirm

    if [[ $download_confirm != 'y' ]]; then
        print_centered_message "${GREEN}跳过字体下载。${NC}"
        return 0
    fi
    
    # 定义字体的源目录
    font_source="/tmp/Fonts/"
    
    git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Fonts.git ${font_source} && print_centered_message "${GREEN}✅Fonts 完成下载${NC}" "true" "false"


    # 根据操作系统设置字体的安装目录
    if [[ "$(uname)" == "Darwin" ]]; then
        font_dest="$HOME/Library/Fonts"
    else
        font_dest="$HOME/.local/share/fonts/"
    fi

    # 打印提示消息
    print_centered_message "正在安装字体......" "true" "false"

    # 确认字体源目录存在
    if [ ! -d "$font_source" ]; then
        echo "字体目录 '$font_source' 不存在，请确认当前目录下有 ${dest_Fonts} 文件夹。"
        exit 1
    fi

    # 创建目标目录如果它不存在
    sudo mkdir -p "$font_dest"

    # 复制字体文件到目标目录
    print_centered_message "正在复制字体文件到 $font_dest..." "false" "false"

    # 使用 find 来查找字体源目录中的字体文件，排除 README 文件
    find "$font_source" -type f \( -iname "*.ttf" -o -iname "*.otf" \) ! -iname "README*" -exec cp -v {} "$font_dest" \;

    # 更新字体缓存
    print_centered_message "更新字体缓存..."
    if [ "$(uname)" == "Darwin" ]; then
        # macOS 不需要手动更新字体缓存
        print_centered_message "在 macOS 上，字体缓存将自动更新。" "false" "true"
    else
        # Linux
        print_centered_message "在 Linux 上，刷新字体缓存" "false" "true"
        fc-cache -fv
    fi
    # 打印提示消息
    print_centered_message "字体安装完成。✅" "false" "true"

}

# 定义提示头🔔函数
prompt_open_proxy() {
    # 首先检查 clash-verge-rev 是否已经安装
    if brew list clash-verge-rev &> /dev/null; then
        print_centered_message "clash-verge-rev 已安装，无需重新下载" "true" "false"
        return 0 # 如果已安装，直接退出函数
    fi

    echo -n "是否需要开启代理软件？(y/n): "
    read open_confirm
    if [[ $open_confirm == 'y' ]]; then
        print_centered_message "正在下载 clash-verge-rev ......"
        brew install clash-verge-rev
        print_centered_message "重新执行脚本命令:" "true" "false"
        print_centered_message '/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/main.sh)"' "false" "true"
        exit 1
    else
        print_centered_message "不开启代理，继续执行脚本"
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
        if read -t 1 -r -n1 str; then
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
