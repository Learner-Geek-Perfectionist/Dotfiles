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
#     # Linux 逻辑
#     echo "检测到 Linux 系统"

#     # 首先询问是否要创建用户
#     read -p "是否需要创建用户？(y/n): " create_confirm < /dev/tty
    
#     # 检查并设置密码
#     set_password_if_needed() {
#         if ! sudo passwd -S "$1" | grep -q ' P '; then
#             echo "用户 $1 的密码未设置，现在将密码设置为 $default_password"
#             echo "$1:$default_password" | sudo chpasswd
#             echo "密码已设置。"
#         else
#             echo "用户 $1 的密码已经存在。"
#         fi
#     }
    
#     # 主逻辑
#     if [[ $create_confirm == 'y' ]]; then
#         read -p "请输入你想创建的用户名: " username < /dev/tty
#         read -p "请输入默认密码（将用于新用户）: " default_password < /dev/tty
    
#         if id "$username" &>/dev/null; then
#             echo "用户 $username 已存在。"
#             set_password_if_needed "$username"
#         else
#             sudo useradd -m "$username"  # 创建用户
#             echo "$username:$default_password" | sudo chpasswd  # 设置密码
#             echo "用户 $username 已创建，密码设置为 $default_password"
#         fi
#     else
#         echo "不创建用户"
#         set_password_if_needed "$username"
#     fi

    
#     # 配置用户无需 sudo 密码
#     sudo usermod -aG wheel "$username"
#     echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
#     echo "已配置用户 $username 无需 sudo 密码。"

        
#    # 配置用户无需 sudo 密码
#     echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
#     echo "已配置用户 $username 无需 sudo 密码。"

#     sudo -v
#      # 设置环境变量
#     sudo sh -c 'export TZ=Asia/Shanghai'

#     # 设置时区
#     sudo sh -c 'echo Asia/Shanghai > /etc/timezone && ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime'

#     # 设置中科大镜像
#     sudo sed -e 's|^metalink=|#metalink=|g' \
#          -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
#          -i.bak \
#          /etc/yum.repos.d/fedora.repo \
#          /etc/yum.repos.d/fedora-updates.repo

#     # 更新软件源缓存
#     sudo dnf makecache
#     # 安装必要的软件
#     sudo dnf update -y && \
#     sudo dnf install -y \
#     openssh-server \
#     iproute \
#     net-tools \
#     fd-find \
#     git \
#     unzip \
#     ripgrep \
#     fzf \
#     ninja-build \
#     neovim \
#     ruby \
#     kitty \
#     cmake \
#     nodejs \
#     iputils \
#     procps-ng \
#     htop \
#     traceroute \
#     fastfetch \
#     tree \
#     coreutils \
#     zsh && \
#     sudo dnf group install -y "C Development Tools and Libraries" && \
#     sudo dnf clean all


    # 检测操作系统
    os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    
    echo "检测到操作系统为: $os_type"
    
    # 询问是否创建用户
    read -p "是否需要创建用户？(y/n): " create_confirm < /dev/tty
    
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
    
    echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
    echo "已配置用户 $username 无需 sudo 密码。"
    
    # 设置时区和环境变量
    sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    sudo sh -c 'echo "Asia/Shanghai" > /etc/timezone'
    sudo sh -c 'echo "export TZ=Asia/Shanghai" >> /etc/profile'
    
    # 根据操作系统设置软件源
    if [[ $os_type == "ubuntu" ]]; then
        sudo sed -i.bak -r 's|^#?(deb|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y openssh-server net-tools git unzip fzf ninja-build neovim ruby-full cmake nodejs iputils-ping procps htop traceroute tree coreutils zsh
    elif [[ $os_type == "fedora" ]]; then
        sudo sed -i.bak -e 's|^metalink=|#metalink=|g' \
            -e 's|^#baseurl=https://download.example.com/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
            /etc/yum.repos.d/fedora.repo \
            /etc/yum.repos.d/fedora-updates.repo
        sudo dnf makecache
        sudo dnf update -y && sudo dnf install -y openssh-server iproute net-tools fd-find git unzip ripgrep fzf ninja-build neovim ruby kitty cmake nodejs iputils procps-ng htop traceroute fastfetch tree coreutils zsh
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




# 仓库的 URL
REPO_URL="https://github.com/Learner-Geek-Perfectionist/dotfiles/archive/refs/heads/master.zip"

# 检查 zip 文件是否存在
if [ ! -f "master.zip" ]; then
    echo "压缩包不存在，开始下载..."
    # 下载压缩包
    curl -L -o master.zip "$REPO_URL"
else
    echo "压缩包已存在，跳过下载。"
fi

# 检查目录是否存在
if [ -d "dotfiles-master" ]; then
    echo "目录 'dotfiles-master' 已存在，跳过解压。"
else
    # 检查 zip 文件是否存在再解压
    if [ -f "master.zip" ]; then
        echo "开始解压缩..."
        unzip -o master.zip
    else
        echo "压缩包不存在，无法解压。"
    fi
fi

# 进入仓库目录
[ -d "dotfiles-master" ] && cd ./dotfiles-master && echo "已进入 'dotfiles-master' 目录。" || { echo "目录 'dotfiles-master' 不存在，无法进入。" && exit 1; }

# 定义需要复制的文件和目录
files_to_copy=(".zshrc" ".zprofile" ".config")

# 获取用户的 home 目录路径
destination="$HOME"

# 循环遍历每个文件和目录
for item in "${files_to_copy[@]}"; do
    # 检查当前目录中文件或目录是否存在
    if [ -e "$item" ]; then
        echo "正在复制 $item 到 $destination"
        # 复制文件或目录到 home 目录，如果存在则替换
        cp -r "$item" "$destination"
    else
        echo "$item 不存在，跳过复制。"
    fi
done


# 打印提示消息
print_centered_message "复制完成。"


# 字体源目录
font_source="./fonts"

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
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS不需要手动更新字体缓存
    echo "在 macOS 上，字体缓存将自动更新。"
else
    # Linux
    fc-cache -fv
fi

# 打印提示消息

print_centered_message "字体安装完成。"


print_centered_message "进入 zsh ......"


# 进入 zsh
zsh
