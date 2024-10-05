#!/bin/bash

# 获取当前操作系统类型
OS_TYPE=$(uname)

if [[ "$OS_TYPE" == "Darwin" ]]; then
    # macOS 逻辑
    echo "检测到 macOS 系统"
    unzip master.zip
    # 检查 Xcode 命令行工具是否已安装
    xcode-select --print-path &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Xcode 命令行工具未安装，现在将进行安装..."
        xcode-select --install
        # 等待用户完成 Xcode 命令行工具的安装
        read -p "请按回车继续..." < /dev/tty
    fi

    # 检查 Git 是否已安装
    if ! type git &>/dev/null; then
        echo "Git 未安装，现在将通过 Xcode 命令行工具安装 Git..."
        xcode-select --reset
    fi

    # 安装 Homebrew
    echo "正在安装 Homebrew..."
    /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
elif [[ "$OS_TYPE" == "Linux" ]]; then

    # 检测操作系统
    os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    
    echo "检测到操作系统为: $os_type"
    
    # 询问是否创建用户
    read -p "是否需要创建用户？(y/n): " create_confirm < /dev/tty

    # 定义用户名
    username=""
    
    # 检查并设置密码的函数
    set_password_if_needed() {
        if ! sudo passwd -S "$1" | grep -q ' P '; then
            echo "用户 $1 的密码未设置，现在将密码设置为 $default_password"
            echo "$1:$default_password" | sudo chpasswd
            echo "密码已设置。"
        else
            echo "用户 $1 的密码已经存在。"
        fi
    }
    
    # 主逻辑
    if [[ $create_confirm == 'y' ]]; then
        read -p "请输入你想创建的用户名: " username < /dev/tty
        read -p "请输入默认密码（将用于新用户）: " default_password < /dev/tty
        
        if id "$username" &>/dev/null; then
            echo "用户 $username 已存在。"
            set_password_if_needed "$username"
        else
            sudo useradd -m "$username"  # 创建用户
            echo "$username:$default_password" | sudo chpasswd  # 设置密码
            echo "用户 $username 已创建，密码设置为 $default_password"
        fi
    else
        echo "不创建用户"
        set_password_if_needed "$username"
    fi
    
    # 配置用户无需 sudo 密码
    if [[ $os_type == "ubuntu" ]]; then
        sudo usermod -aG sudo "$username"
    elif [[ $os_type == "fedora" ]]; then
        sudo usermod -aG wheel "$username"
    fi

    # 如果 username 变量未设置或为空，则默认为当前登录用户的用户名
    username="${username:-$(whoami)}"
    echo "testtesttest"
    # 将用户添加到 sudoers 文件以免输入密码
    echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
    echo "已配置用户 $username 无需 sudo 密码。"
    
    echo "testtesttest"
    
    # 设置时区和环境变量
    sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    sudo sh -c 'echo "Asia/Shanghai" > /etc/timezone'
    sudo sh -c 'echo "export TZ=Asia/Shanghai" >> /etc/profile'
    
    # 根据操作系统设置软件源
    if [[ $os_type == "ubuntu" ]]; then
        sudo sed -i.bak -r 's|^#?(deb|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y openssh-server net-tools git unzip fzf ninja-build neovim ruby-full cmake nodejs iputils-ping procps htop traceroute tree coreutils zsh fontconfig
    elif [[ $os_type == "fedora" ]]; then
        sudo sed -i.bak -e 's|^metalink=|#metalink=|g' \
            -e 's|^#baseurl=https://download.example.com/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
            /etc/yum.repos.d/fedora.repo \
            /etc/yum.repos.d/fedora-updates.repo
        sudo dnf makecache
        sudo dnf update -y && sudo dnf install -y openssh-server iproute net-tools fd-find git unzip ripgrep fzf ninja-build neovim ruby kitty cmake nodejs iputils procps-ng htop traceroute fastfetch tree coreutils zsh fontconfig
        sudo dnf group install -y "C Development Tools and Libraries"
        sudo dnf clean all
    else
        echo "\n不支持的发行版，目前只支持 fedora、ubuntu\n"
    fi



else
    echo "未知的操作系统类型"
fi



print_centered_message() {
    local message="$1"  # 传入的消息文本
    local padding=4     # 设置消息两侧的填充空间

    # 获取终端宽度
    local term_width=$(tput cols)

    # 计算边框宽度，确保至少有两个字符作为边框
    local width=$((term_width - padding))

    # 计算居中位置
    local center=$(( (term_width - width) / 2 ))

    # 打印上边框
    printf "%s\n" "$(printf "%*s" $width | tr ' ' '*')"
    # 打印间距
    printf "\n"
    # 打印居中消息
    printf "%*s\n" $((center + ${#message} / 2)) "$message"
    # 打印间距
    printf "\n"
    # 打印下边框
    printf "%s\n" "$(printf "%*s" $width | tr ' ' '*')"
}



# 打印提示消息
print_centered_message "按任意键继续，否则超时停止"

# 设置倒计时时间
timeout=60 

# 开始倒计时
for ((i=timeout; i>0; i--)); do
    echo -ne "\r${message} (timeout in $i seconds): "
    read -t 1 -r str < /dev/tty && break  # 如果用户提前输入，则跳出循环，从终端设备读取
    echo -ne "\r"  # 清除当前行
done

if [[ -n $str || $str == "" ]]; then
    echo -e "\n准备配置zsh...\n"
else
    echo "\nTime out.\n"
fi


# 字体链接
REPO_URL="https://github.com/Learner-Geek-Perfectionist/dotfiles/archive/refs/heads/master.zip"

# 定义一个函数来处理压缩包的下载和解压
handle_zip_file() {
    local zip_file="master.zip"
    local dest_dir="dotfiles-master"

    # 检查 zip 文件是否存在
    if [ ! -f "$zip_file" ]; then
        echo "压缩包不存在，开始下载..."
        # 下载压缩包
        curl -L -o "$zip_file" "$REPO_URL"
    else
        echo "压缩包已存在，跳过下载。"
    fi

    # 确保压缩包一定存在后，检查目录是否存在
    if [ -d "$dest_dir" ]; then
        echo "目录 '$dest_dir' 已存在，跳过解压。"
    else
        # 检查 zip 文件是否存在再解压
        if [ -f "$zip_file" ]; then
            echo "开始解压缩..."
            unzip -o "$zip_file"
        else
            echo "压缩包不存在，无法解压。"
        fi
    fi
}




# 提示用户是否需要下载字体
prompt_download_fonts() {
    echo "某些终端模拟器可能需要特定的字体以正确显示字符。如果你在使用的终端模拟器对字体渲染有特殊要求，或者你希望确保字符显示的美观和一致性，可能需要下载和安装额外的字体。"
    echo "下载字体可以改善字符显示效果，特别是对于多语言支持或特殊符号的显示。"
    echo "在虚拟机中运行时，字体渲染依赖虚拟机特定的字体，因此需要安装字体。"
    echo "在 Docker 容器(或 WSL)中运行时，通常不需要在容器(或WSL)内安装字体，但应确保宿主机已安装适当的字体以支持任何可能的字体渲染需求。"
    echo "宿主机一般需要良好的字体支持来确保所有应用和终端模拟器都能正常渲染字符。"
    read -p "是否需要下载字体以支持终端模拟器的渲染？(y/n): " download_confirm < /dev/tty
    if [[ $download_confirm == 'y' ]]; then
        handle_zip_file
    else
        echo "跳过字体下载。"
    fi
}


destination="$HOME"

# 进入目录并复制配置文件到用户的 home 目录的函数
copy_config_files_to_home() {
    local dir_name="dotfiles-master"
    local files_to_copy=(".zshrc" ".zprofile" ".config")

    # 进入仓库目录
    if [ -d "$dir_name" ]; then
        echo "已进入 '$dir_name' 目录。"
        cd "$dir_name"
    else
        echo "目录 '$dir_name' 不存在，无法进入。"
        return 1  # 返回非零状态表示失败
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


# 打印提示消息
print_centered_message "复制完成。"



font_source="./fonts"

# 定义一个函数来复制字体文件并更新字体缓存
install_fonts() {
    local os_type="$1"      # 从函数调用中传入操作系统类型作为参数

    # 确认字体源目录存在
    if [ ! -d "$font_source" ]; then
        echo "字体目录 '$font_source' 不存在，请确认当前目录下有 'fonts' 文件夹。"
        exit 1
    fi

    # 复制字体文件到目标目录
    echo "正在复制字体文件到 $destination..."
    cp -v "$font_source"/* "$destination"

    # 更新字体缓存
    echo "更新字体缓存..."
    if [ "$os_type" = "Darwin" ]; then
        # macOS不需要手动更新字体缓存
        echo "在 macOS 上，字体缓存将自动更新。"
    else
        # Linux
        fc-cache -fv
    fi
}

install_fonts "${OS_TYPE}"

# 打印提示消息

print_centered_message "字体安装完成。"


print_centered_message "进入 zsh ......"


# 进入 zsh
zsh
