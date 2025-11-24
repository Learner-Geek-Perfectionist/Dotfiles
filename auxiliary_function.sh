set -e

KOTLIN_NATIVE_URL=""
KOTLIN_COMPILER_URL=""
INSTALL_DIR=""
COMPILER_INSTALL_DIR=""
LATEST_VERSION=""

# 全局变量，记录是否是第一次调用
PRINT_LINE_STATE=0

print_centered_message() {
	local message="$1"
	local cols=$(tput cols)
	local line=$(printf '%*s' "$cols" '' | tr ' ' '-')

	# 第一次打印：先打印横线
	if [[ $PRINT_LINE_STATE -eq 0 ]]; then
		echo "$line"
		PRINT_LINE_STATE=1
	fi

	# 居中 message
	local pad=$(((cols - ${#message}) / 2))
	printf "%*s%s\n\n" "$pad" "" "$message"

	# 每次调用之后自动打印横线
	echo "$line"
}

get_latest_version() {
	LATEST_VERSION=$(curl -s -L -I https://github.com/JetBrains/kotlin/releases/latest | grep -i location | sed -E 's/.*tag\/(v[0-9\.]+).*/\1/')
}

setup_kotlin_environment() {
	ARCH=$(uname -m)
	INSTALL_DIR="/opt/kotlin-native/"
	COMPILER_INSTALL_DIR="/opt/kotlin-compiler/"
	case "$ARCH" in
	arm64 | aarch64)
		ARCH="aarch64"
		;;
	x86_64)
		ARCH="x86_64"
		;;
	*)
		echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
		exit 1
		;;
	esac
	get_latest_version
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
	KOTLIN_NATIVE_URL="https://github.com/JetBrains/kotlin/releases/download/$LATEST_VERSION/kotlin-native-prebuilt-$SYSTEM_TYPE-$ARCH-${LATEST_VERSION#v}.tar.gz"
	KOTLIN_COMPILER_URL="https://github.com/JetBrains/kotlin/releases/download/$LATEST_VERSION/kotlin-compiler-${LATEST_VERSION#v}.zip"
}

download_and_extract_kotlin() {
	URL=$1
	TARGET_DIR=$2
	FILE_NAME=$(basename "${URL}")
	if [[ -d "$TARGET_DIR" ]]; then
		print_centered_message "${GREEN}${FILE_NAME}${NC} is already installed in ${YELLOW}${TARGET_DIR}${NC}." "true" "false"
		return 0
	fi
	print_centered_message "$LIGHT_BLUE正在下载 $FILE_NAME...... ${NC}" "true" "false"
	echo -e "${CYAN}The Latest Version is $RED$LATEST_VERSION${NC}"
	echo -e "${YELLOW}Downloading $BLUE$FILE_NAME$YELLOW from ${MAGENTA}${URL}${NC}"
	curl -L -f -s -S "${URL}" -o "/tmp/${FILE_NAME}" || {
		echo -e "$RED❌ Failed to download $FILE_NAME.Please check your internet connection and URL.${NC}"
		return 0
	}
	echo -e "${YELLOW}Installing $GREEN$FILE_NAME$YELLOW to $BLUE$TARGET_DIR$YELLOW...${NC}"
	sudo mkdir -p $TARGET_DIR
	if [[ $FILE_NAME == *.tar.gz ]]; then
		if [[ $(uname) == "Darwin" ]]; then
			sudo tar -xzf "/tmp/$FILE_NAME" -C $TARGET_DIR --strip-components=1
		else
			sudo tar -xzf "/tmp/$FILE_NAME" -C $TARGET_DIR --strip-components=1 --overwrite
		fi
	elif [[ $FILE_NAME == *.zip ]]; then
		sudo unzip -o "/tmp/$FILE_NAME" -d $TARGET_DIR
	fi
	# 更改 kotlin 目录权限，添加符号链接到系统的 PATH 中
	[[ -d "/opt/kotlin-native/" ]] && sudo chmod -R a+rw /opt/kotlin-native/ && sudo ln -snf /opt/kotlin-native/bin/* /usr/local/bin/
	[[ -d "/opt/kotlin-compiler/" ]] && sudo chmod -R a+rw /opt/kotlin-compiler/ && sudo ln -snf /opt/kotlin-compiler/kotlinc/bin/* /usr/local/bin/
	print_centered_message "${GREEN}${FILE_NAME} has been installed successfully to ${TARGET_DIR}${NC}" "false" "false"
}

detect_package_manager() {
	if command -v brew &>/dev/null; then
		echo "brew"
	elif command -v apt &>/dev/null; then
		echo "apt"
	elif command -v dnf &>/dev/null; then
		echo "dnf"
	else
		echo "unsupported"
	fi
}

install_packages() {
	local pkg_manager
	pkg_manager=$(detect_package_manager)
	if [[ "$pkg_manager" == "unsupported" ]]; then
		echo -e "${RED}Unsupported package manager${NC}"
		return 1
	fi

	local package_group_name="$1"
	local packages
	# 注意：确保传入的 package_group_name 是受信任的变量名
	eval "packages=(\"\${${package_group_name}[@]}\")"

	local installed_packages
	case "$pkg_manager" in
	"brew")
		installed_packages=$(brew list)
		;;
	"apt")
		installed_packages=$(dpkg -l | awk '/^ii/ {print $2}')
		;;
	"dnf")
		installed_packages=$(dnf list installed | awk 'NR>1 {print $1}')
		;;
	esac

	local uninstalled_packages=()
	for package in "${packages[@]}"; do
		if ! echo "$installed_packages" | grep -qi -E "^$package.*$"; then
			uninstalled_packages+=("$package")
		fi
	done

	if [[ ${#uninstalled_packages[@]} -eq 0 ]]; then
		print_centered_message "🎉 ${GREEN}All packages were already installed.${NC}" "false" "false"
		return 0
	else
		print_centered_message "${RED}The following packages need to be installed:${NC}"
		for package in "${uninstalled_packages[@]}"; do
			echo "- $package"
		done
	fi

	print_centered_message "${LIGHT_BLUE}Installing ${#uninstalled_packages[@]} packages...${NC}"
	case "$pkg_manager" in
	"brew")
		brew install "${uninstalled_packages[@]}"
		;;
	"apt")
		sudo apt install -y "${uninstalled_packages[@]}"
		;;
	"dnf")
		sudo dnf install -y "${uninstalled_packages[@]}"
		;;
	esac
}

install_and_configure_docker() {
	print_centered_message "$LIGHT_BLUE开始检查 Docker 环境..." "true" "false"
	if grep -qi microsoft /proc/version || [[ "$AUTO_RUN" == "true" ]]; then
		echo -e "${GREEN}在 WSL2 中或者 Docker 中不需要安装 Docker${NC}"
	else
		if command -v docker >/dev/null; then
			echo -e "${GREEN}Docker 已安装✅，跳过安装步骤。${NC}"
		else
			echo -e "${YELLOW}Docker 未安装，开始安装过程...${NC}"
			install_docker
		fi
	fi
}

install_docker() {
	echo -e "$BLUE获取 Docker 安装脚本...${NC}"
	curl -fsSL https://get.docker.com -o get-docker.sh || {
		echo -e "$DARK_RED下载安装脚本失败${NC}"
		exit 1
	}
	echo -e "$BLUE运行安装脚本...${NC}"
	sudo sh get-docker.sh || {
		echo -e "$DARK_RED安装 Docker 失败${NC}"
		exit 1
	}
	rm -rf get-docker.sh
	echo -e "$BLUE将当前用户添加到 docker 组...${NC}"
	sudo usermod -aG docker "$USER" || {
		echo -e "$DARK_RED添加用户到 docker 组失败${NC}"
		exit 1
	}
	echo -e "$BLUE启动并设置 Docker 服务开机自启...${NC}"
	(sudo systemctl start docker && sudo systemctl enable docker && sudo systemctl restart docker) || {
		echo -e "$DARK_RED启动或设置开机自启失败${NC}"
		exit 1
	}
	echo -e "${GREEN}Docker 安装完成。请考虑重新登录或重启以使组设置生效。${NC}"
}

install_fonts() {
	if [[ $AUTO_RUN == "true" ]]; then
		return 0
	fi
	echo -ne "$GREEN是否需要下载字体以支持终端模拟器的渲染？(y/n): ${NC}"
	read download_confirm
	if [[ $download_confirm != 'y' ]]; then
		print_centered_message "$GREEN跳过字体下载。${NC}"
		return 0
	fi
	font_source="/tmp/Fonts/"
	git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Fonts.git $font_source && print_centered_message "${GREEN}✅Fonts 完成下载${NC}" "true" "false"
	if [[ "$(uname)" == "Darwin" ]]; then
		font_dest="$HOME/Library/Fonts"
	else
		font_dest="$HOME/.local/share/fonts/"
	fi
	print_centered_message "正在安装字体......" "true" "false"
	if [[ ! -d "$font_source" ]]; then
		echo "字体目录 '$font_source' 不存在，请确认当前目录下有 $dest_Fonts 文件夹。"
		exit 1
	fi
	sudo mkdir -p "$font_dest"
	print_centered_message "正在复制字体文件到 $font_dest..." "false" "false"
	find "$font_source" -type f \( -iname "*.ttf" -o -iname "*.otf" \) ! -iname "README*" -exec sudo cp -v {} "$font_dest" \;
	if [[ "$(uname)" == "Darwin" ]]; then
		print_centered_message "在 macOS 上，字体缓存将自动更新。" "false" "true"
	else
		print_centered_message "在 Linux 上，刷新字体缓存" "false" "true"
		fc-cache -fv
	fi
	print_centered_message "字体安装完成。✅" "false" "true"
}

countdown() {
	local timeout=${1:-60}
	local message=${2:-"Waiting for input"}
	local str
	local key_pressed=0
	for ((i = timeout; i > 0; i--)); do
		echo -ne "\r$message (timeout in $i seconds): "
		if read -t 1 -r -n1 str; then
			key_pressed=1
			break
		fi
	done
	if [[ $key_pressed -eq 0 ]]; then
		echo -e "\nTime out. No input received.\n"
		exit 1
	else
		echo -e "\nUser input received: '$str'\n"
		return 0
	fi
}
