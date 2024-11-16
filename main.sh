#!/bin/bash

# 一旦错误，就退出
set -e

# 定义日志文件路径
LOG_FILE="install.log"

# 重定向整个脚本的输出到日志文件，并覆盖之前的日志
exec > >(tee "$LOG_FILE") 2>&1





# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # 没有颜色


# 加载 packages
source ./package.sh

# 加载辅助函数
source ./auxiliary_function.sh

# 获取当前操作系统类型
OS_TYPE=$(uname)

if [[ $OS_TYPE == "Darwin" ]]; then
  source ./macos_install.sh

elif [[ $OS_TYPE == "Linux" ]]; then

  # 检测操作系统
  os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

  print_centered_message "检测到操作系统为: $os_type"

  # 询问是否创建用户
  read -p "是否需要创建用户？(y/n): " create_confirm

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
    source ./ubuntu_install.sh

  elif [[ $os_type == "fedora" ]]; then
    source ./fedora_install.sh

  else
    print_centered_message -e "不支持的发行版，目前只支持 fedora、ubuntu"
  fi

else
  echo "未知的操作系统类型"
fi

source ./zsh_install.sh
