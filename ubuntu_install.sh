#!/bin/bash

# 一旦错误，就退出
set -e

# 设置国内源
sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list && sudo apt update && sudo apt upgrade -y 

# =================================开始安装 wireshark=================================
if ! command -v wireshark >/dev/null 2>&1; then
    print_centered_message   "${GREEN}开始安装 wireshark${NC}" "true" "false"
    sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:wireshark-dev/stable
    sudo DEBIAN_FRONTEND=noninteractive apt install -y wireshark
else
    print_centered_message   "${GREEN}Wireshark 已安装，跳过安装。${NC}" "true" "false"
fi
# =================================结束安装 wireshark=================================


# =================================开始安装 fastfetch=================================
if ! command -v fastfetch > /dev/null 2>&1; then
    FASTFETCH_LATEST_VERSION=$(curl -s -L -I https://github.com/fastfetch-cli/fastfetch/releases/latest | grep -i location | sed -E 's|.*tag/([0-9\.]+).*|\1|')
    
    # 确定架构
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) FASTFETCH_ARCH="amd64" ;;
        aarch64) FASTFETCH_ARCH="aarch64" ;;
        *) echo -e "${RED}Unsupported architecture: $ARCH${NC}" && exit 1 ;;
    esac
    
    
    # 确定系统类型
    case "$(uname -s)" in
        Linux)
            SYSTEM_TYPE="linux"
            ;;
        *)
            echo -e "${RED}Unsupported system type: $(uname -s)${NC}"
            exit 1
            ;;
    esac

    URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_LATEST_VERSION}/fastfetch-${SYSTEM_TYPE}-${FASTFETCH_ARCH}.deb"
    FILE_NAME=$(basename $URL)
    
    print_centered_message "${GREEN}正在下载 ${FILE_NAME}...... ${NC}" "true" "false"
    echo -e "${CYAN}The Latest Version is ${RED}${FASTFETCH_LATEST_VERSION}${NC}"
    echo -e "${YELLOW}Downloading ${BLUE}${FILE_NAME}${YELLOW} from ${MAGENTA}${URL}${NC}"
    
    
    # 使用 curl 下载文件，检查 URL 的有效性
    curl -L -f -s -S "${URL}" -o "/tmp/$FILE_NAME" || {
        print_centered_message  "${RED}❌ Failed to download ${FILE_NAME}.Please check your internet connection and URL.${NC}" "false" "false"
        return 0
    }
    
    sudo apt install -y /tmp/${FILE_NAME}
    
    print_centered_message "${GREEN} ${FILE_NAME} 安装完成 ✅${NC}" "false" "false"
else
     print_centered_message   "${GREEN} fastfetch 已安装，跳过安装。${NC}" "true" "false"
fi
# =================================结束安装 fastfetch=================================


# =================================开始安装 kitty=================================
if ! command -v kitty > /dev/null 2>&1; then
    print_centered_message  "${GREEN}开始安装 kitty... ${NC}" "true" "false"
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
    
    # 定义基础URL
    BASE_URL="http://kr.archive.ubuntu.com/ubuntu/pool/universe/k/kitty/"
    
    # 使用curl获取页面内容，并解析出最新的 kitty-terminfo .deb 文件的版本号
    TERMINFO_LATEST_VERSION=$(curl -s "$BASE_URL" | grep -oP 'href="kitty-terminfo_[^"]*\.deb"' | sed -E 's|.*kitty-terminfo_([^"]*)\.deb.*|\1|' | sort -V | tail -1)
    
    # 如果找不到文件，则退出
    if [ -z "$TERMINFO_LATEST_VERSION" ]; then
        echo -e "${RED}Failed to find the kitty-terminfo .deb file.${NC}"
        exit 1
    fi
    
    # 构建完整的.deb文件下载URL
    TERMINFO_URL="${BASE_URL}kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"
    
    # 下载和安装包
    echo -e "Downloading ${RED}kitty-terminfo${NC} version ${GREEN}${TERMINFO_LATEST_VERSION}${NC}"
    if curl -s -O "$TERMINFO_URL"; then
        echo "Installing kitty-terminfo..."
        if sudo dpkg -i "kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"; then
            echo -e "${GREEN}kitty 安装完成 ✅${NC}"
        else
            echo -e "${RED}Installation failed.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Download failed.${NC}"
        exit 1
    fi

    # 清理下载的文件
    sudo rm -rf "kitty-terminfo_${TERMINFO_LATEST_VERSION}.deb"

    # 检查是否在 WSL2 中运行或在自动化脚本环境中
    if grep -qi microsoft /proc/version || [[ "$AUTO_RUN" == "true" ]]; then
        print_centered_message  "${RED}在 WSL2 中或者 Dockerfile 中不需要安装 kitty 桌面图标${NC}" "false" "false"
    else
        sudo mkdir -p /usr/local/bin/ ~/.local/share/applications/
        sudo ln -s ~/.local/kitty.app/bin/kitty /usr/local/bin/
        # For Application Launcher:
        sudo cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/
        sudo cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/
        # Add Icon:
        sudo sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
        sudo sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
        sudo chmod a+x $HOME/.local/kitty.app/share/applications/kitty-open.desktop $HOME/.local/kitty.app/share/applications/kitty.desktop $HOME/.local/share/applications/kitty-open.desktop $HOME/.local/share/applications/kitty.desktop
    fi
else
    print_centered_message   "${GREEN} kitty 已安装，跳过安装。${NC}" "true" "false"
fi

# =================================结束安装 kitty=================================


# =================================开始安装 fzf=================================
if command -v fzf > /dev/null 2>&1; then
    print_centered_message  "${GREEN}fzf 已安装，跳过安装。${NC}"  "true" "true"
else
    print_centered_message  "${GREEN}开始安装 fzf... ${NC}" "true" "false"
    [[ -d "$HOME/.fzf" ]] && rm -rf "$HOME/.fzf"

    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    yes | $HOME/.fzf/install --no-update-rc
    print_centered_message "${GREEN} fzf 安装完成 ✅${NC}" "false" "true"
fi 
# =================================结束安装 fzf=================================


# =================================开始安装 Kotlin/Native =================================
# 设置 Kotlin 的变量
setup_kotlin_environment
# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR
# =================================结束安装 Kotlin/Native =================================


# 更新索引
sudo apt update && sudo apt upgrade -y


# 获取Ubuntu版本号并比较
if [[ $(echo "$(lsb_release -sr) >= 22.04" | bc) -eq 1 ]]; then
    install_packages "packages_ubuntu_22_04_plus"
else
    install_packages "packages_ubuntu_20_04"
    download_and_extract_kotlin $KOTLIN_COMPILER_URL $COMPILER_INSTALL_DIR
fi


# 取消最小化安装
sudo apt update -y && sudo apt upgrade -y && sudo apt search unminimize 2> /dev/null | grep -q "^unminimize/" && (sudo apt install unminimize -y && yes | sudo unminimize) || echo -e "${RED}unminimize包不可用。${NC}"


# =================================开始安装 eza=================================
if command -v eza > /dev/null 2>&1; then
    print_centered_message  "${GREEN}eza 已安装，跳过安装。${NC}"  "true" "true"
else
    print_centered_message  "${GREEN}开始安装 eza... ${NC}" "true" "false"
    # 安装 eza, 在 oracular (24.10)  之后的 Ubuntu 发行版才有 eza
    cargo install eza
    print_centered_message "${GREEN} eza 安装完成 ✅" "false" "true"
fi 
# =================================结束安装 eza=================================


# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone > /dev/null
sudo dpkg-reconfigure --frontend noninteractive tzdata

# 生成指定的 locale 数据
sudo locale-gen zh_CN.UTF-8

# 合并写入 LANG 和 LC_ALL 设置到 /etc/default/locale
echo "LANG=zh_CN.UTF-8" | sudo tee /etc/default/locale
echo "LC_ALL=zh_CN.UTF-8" | sudo tee -a /etc/default/locale

# 可选：立即应用这些设置
source /etc/default/locale



# 搜索可用的 OpenJDK 包并尝试获取最新版本
jdk_version=$(apt search openjdk | grep -oP 'openjdk-\d+-jdk' | sort -V | tail -n1)
sudo apt install -y $jdk_version && print_centered_message  "${GREEN}成功安装 ${jdk_version}${NC}" "true" "false"


# 为了避免 Dockerfile 交互式
if [[ "$AUTO_RUN" == "true" ]]; then
    echo -e "${GREEN}在 Docker 中无需安装 Docker${NC}"
else
    # 调用函数以安装和配置 Docker
    install_and_configure_docker
fi

sudo apt clean

echo -e "${RED}当前目录: $(pwd) ${NC}"
