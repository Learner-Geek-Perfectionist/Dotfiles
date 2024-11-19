#!/bin/bash

# macOS 逻辑
print_centered_message "${CYAN}检测到操作系统为: macOS${NC}" "true" "false"

# 进入 Documents 目录
cd $HOME/Documents

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # 没有颜色

if ! xcode-select --print-path &> /dev/null; then
    print_centered_message "${RED}⚠️ Xcode 命令行工具未安装${NC}" "true" "false"
    xcode-select --install 2> /dev/null
    print_centered_message "${RED}请手动点击屏幕中的弹窗，选择“安装”，安装完成之后再次运行脚本(提示命令通常在终端的背面)${NC}" "false" "false"
    echo -e "${RED}脚本命令: ${NC}"
    print_centered_message "${RED}/bin/zsh -c \"$(curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/refs/heads/master/install.sh)\"${NC}" "false" "true"
    exit 1
fi

# 检查 Homebrew 是否已安装
if command -v brew > /dev/null 2>&1; then
    print_centered_message "${GREEN}Homebrew 已经安装，跳过安装步骤。${NC}" "true" "false"
else
    print_centered_message "${GREEN}正在安装 Homebrew...${NC}" "true" "false"
    curl -O "https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh"
    chmod +x ./Homebrew.sh
    source ./Homebrew.sh
    print_centered_message "${GREEN}重新加载 .zprofile 文件以启用 brew 环境变量 ${NC}" "false" "true"
    # 刷新 brew 配置，启用 brew 环境变量
    source ${HOME}/.zprofile
fi

[[ -f "./Homebrew.sh" ]] && rm "./Homebrew.sh" && echo "Homebrew.sh 文件已被删除。"

# 定义颜色
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # 没有颜色

# 提示开启代理
echo -e "${YELLOW}为了能顺利安装 Homebrew 的 cask 包，请打开代理软件，否则下载速度很慢（推荐选择香港 🇭🇰  或者 新加坡 🇸🇬  节点，如果速度还是太慢，可以通过客户端查看代理情况）${NC}"
echo -e "${YELLOW}如果下载进度条卡住，在代理客户端中，多次切换「全局模式」或者「规则模式」，并且打开 TUN 选项。${NC}"

prompt_open_proxy

print_centered_message "正在安装 macOS 常用的开发工具......" "true" "false"

# 安装 brew_formulas 包
check_and_install_brew_packages "brew_formulas"

print_centered_message "${GREEN}开发工具安装完成✅${NC}" "false" "true"

print_centered_message "正在安装 macOS 常用的带图形用户界面的应用程序......" "false" "false"

# 安装 brew_casks 包
check_and_install_brew_packages "brew_casks"

# 安装 wireshark --cask 工具，因为 wireshark 既有命令行版本又有 cask 版本，因此手动加上 --cask 参数
brew install --cask wireshark

brew cleanup

print_centered_message "${GREEN}图形界面安装完成✅${NC}" "false" "true"

print_centered_message "准备安装 Kotlin/Native" "false" "false"
# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR "Kotlin/Native" && print_centered_message "Kotlin/Native 安装完成" "false" "true"

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

print_centered_message "${GREEN}所有应用安装完成。🎉${NC}"

# 配置 zsh
source ./zsh_install.sh
