#!/bin/bash

# 设置脚本在遇到错误时退出
set -e
source /tmp/Dotfiles/auxiliary_function.sh

# 定义颜色
export RED='\033[0;31m' \
	GREEN='\033[0;32m' \
	YELLOW='\033[1;33m' \
	BLUE='\033[0;34m' \
	ORANGE='\033[0;93m' \
	MAGENTA='\033[0;35m' \
	PURPLE='\033[0;35m' \
	CYAN='\033[0;36m' \
	LIGHT_BLUE='\033[1;34m' \
	DARK_RED='\033[1;31m' \
	NC='\033[0m' # 没有颜色

# 判断操作系统类型
if [[ -f /etc/lsb-release ]]; then
	# 获取Ubuntu版本代号（如focal、jammy、plucky等）
	CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)

	# 获取系统架构
	ARCH=$(dpkg --print-architecture)

	if [[ $ARCH =~ ^(arm|arm64|aarch64|powerpc|s390x)$ ]]; then
		REPO_PATH="ubuntu-ports" # 非x86架构（含arm64）使用ports源
	else
		REPO_PATH="ubuntu" # x86架构使用标准源
	fi

	# 选择国内镜像（清华镜像支持plucky的ubuntu-ports源）
	MIRROR_DOMAIN="mirrors.tuna.tsinghua.edu.cn"

	# 替换源地址（确保路径为ubuntu-ports，保留发行版和组件）
	sudo sed -i -E "s|http://[^/]*/ubuntu(-ports)?|https://${MIRROR_DOMAIN}/${REPO_PATH}|g" /etc/apt/sources.list

	# 更新源缓存
	sudo apt update
elif [[ -f /etc/fedora-release ]]; then
	# Fedora 系统
	sudo sed -e 's|^metalink=|#metalink=|g' \
		-e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
		-i.bak \
		/etc/yum.repos.d/fedora.repo \
		/etc/yum.repos.d/fedora-updates.repo
	sudo dnf -y upgrade --refresh
fi

# 定义临时目录路径
TMP_DIR="/tmp/Dotfiles"

sudo rm -rf "$TMP_DIR"
sudo rm -rf /tmp/Fonts/
echo -e "${GREEN}🚀 Starting script...${NC}"

if [[ $(uname -s) == "Darwin" ]]; then
	brew update
	# 定义需要安装的工具
	tools=("fzf" "eza" "fd" "rg" "kitty" "bat" "fastfetch" "man-db" "lua")
	install_packages "tools"
	# 先安装 git，再 clone
	echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
	git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
		echo "Failed to clone repository"
		exit 1
	}

elif [[ $(uname -s) == "Linux" ]]; then

	# 检测操作系统
	os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

	# 根据操作系统安装......
	if [[ $os_type == "ubuntu" ]]; then
		sudo apt update
		tools=("zsh" "git" "curl" "make" "g++" "gcc" "openssh-server" "man-db" "wget" "gnupg" "pkg-config" "xz-utils" "gtk-update-icon-cache" "bc" "graphviz" "language-pack-zh-hans" "language-pack-zh-hans-base")
		install_packages "tools"

		echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
		git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
			echo "Failed to clone repository"
			exit 1
		}
		source /tmp/Dotfiles/ubuntu_install_tools.sh

	elif [[ $os_type == "fedora" ]]; then
		sudo dnf -y update
		tools=("zsh" "git" "curl" "make" "gcc-c++" "gcc" "openssh-server" "man-db" "wget" "shfmt" "llvm" "clang
" "clang-devel" "clang-tools-extra" "lldb" "lld" "cmake" "fastfetch" "lua" "bat" "ripgrep" "fd-find" "fzf" "rustup" "graphviz")
		install_packages "tools"

		# 先安装 git，再 clone
		echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
		git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR" || {
			echo "Failed to clone repository"
			exit 1
		}
		source /tmp/Dotfiles/fedora_install_tools.sh

	else

		print_centered_message "${RED}不支持的发行版，目前只支持 fedora、ubuntu${NC}"
	fi

	# 修改默认的登录 shell 为 zsh
	# 获取当前用户的默认 shell
	current_shell=$(getent passwd "$(whoami)" | cut -d: -f7)
	# 如果当前 shell 不是 zsh，则更改为 zsh
	[[ "$(command -v zsh)" != "$current_shell" ]] && sudo chsh -s "$(command -v zsh)" "$(whoami)"
else
	echo -e "${MAGENTA}未知的操作系统类型${NC}"
fi

# 安装 zsh 的 dotfiles
source /tmp/Dotfiles/update_dotfiles.sh
