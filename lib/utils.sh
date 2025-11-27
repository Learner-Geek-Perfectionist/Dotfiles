#!/bin/bash

# Source constants if not already sourced
if [[ -z "$RED" ]]; then
	source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
fi

# Function: Initialize logging
# Creates log file and redirects all output to both terminal and log file
# Usage: Call this function ONCE at the start of your main script
init_logging() {
	local log_file="${DOTFILES_LOG:-/tmp/dotfiles-install.log}"

	# Write header to log file
	{
		echo "======================================"
		echo "Dotfiles Installation Log"
		echo "Version: ${DOTFILES_VERSION:-unknown}"
		echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
		echo "OS: $(uname -s) $(uname -r)"
		echo "User: $(whoami)"
		echo "======================================"
		echo ""
	} >"$log_file"

	# Redirect all stdout and stderr to both terminal and log file
	# This captures EVERYTHING from this point forward
	exec > >(tee -a "$log_file") 2>&1
}

# Function: Log message to file and optionally to stdout
# Usage: log_msg "message" [show_stdout]
log_msg() {
	local msg="$1"
	local show_stdout="${2:-true}"
	local log_file="${DOTFILES_LOG:-/tmp/dotfiles-install.log}"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo "[$timestamp] $msg" >>"$log_file"
	if [[ "$show_stdout" == "true" ]]; then
		echo -e "$msg"
	fi
}

# Function: Log error message
log_error() {
	local msg="$1"
	log_msg "${RED}ERROR: $msg${NC}"
}

# Function: Log success message
log_success() {
	local msg="$1"
	log_msg "${GREEN}$msg${NC}"
}

# Function: Ensure git is installed (auto-install if missing)
ensure_git() {
	if command -v git &>/dev/null; then
		return 0
	fi

	log_msg "${YELLOW}Git not found, installing...${NC}"

	local os_type=$(uname -s)
	if [[ "$os_type" == "Darwin" ]]; then
		# macOS: Install Xcode Command Line Tools
		xcode-select --install 2>/dev/null || true
		# Wait for installation
		until command -v git &>/dev/null; do
			sleep 5
		done
	elif [[ "$os_type" == "Linux" ]]; then
		if [[ -f /etc/os-release ]]; then
			local distro=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
			case "$distro" in
			ubuntu | debian)
				export DEBIAN_FRONTEND=noninteractive
				if command -v apt-fast &>/dev/null; then
					sudo apt-fast update && sudo apt-fast install -y git
				else
					sudo apt-get update && sudo apt-get install -y git
				fi
				;;
			fedora)
				sudo dnf install -y git
				;;
			*)
				log_error "Unsupported distribution: $distro"
				return 1
				;;
			esac
		fi
	fi

	if command -v git &>/dev/null; then
		log_success "Git installed successfully"
		return 0
	else
		log_error "Failed to install git"
		return 1
	fi
}

# Function: Strip ANSI color codes from text
# Usage: strip_colors "text with \033[0;31mcolors\033[0m"
strip_colors() {
	echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# Function: Print message (Gum style or Fallback)
# Usage: print_msg "Message" "ColorCode(optional)"
# Note: Pass plain text messages without color codes for best gum compatibility
print_msg() {
	local msg="$1"
	local color="${2:-99}" # Default color (Purple-ish)
	# Strip any ANSI color codes before passing to gum
	local plain_msg
	plain_msg=$(strip_colors "$msg")
	if command -v gum &>/dev/null; then
		gum style \
			--border double \
			--align center \
			--width "$(($(tput cols) - 2))" \
			--margin "0 0" \
			--padding "0 2" \
			--border-foreground "$color" \
			--foreground "$color" \
			"$plain_msg"
	else
		# Fallback - use original message with colors
		echo -e "${BLUE}==================================================${NC}"
		echo -e "  $msg"
		echo -e "${BLUE}==================================================${NC}"
	fi
}

# Function: Countdown timer
countdown() {
	local timeout=${1:-60}
	local message=${2:-"Waiting for input"}
	local str
	local key_pressed=0

	# Skip countdown if not interactive
	if [[ ! -t 0 ]]; then
		echo "Non-interactive mode detected. Skipping countdown."
		return 0
	fi

	for ((i = timeout; i > 0; i--)); do
		echo -ne "\r$message (timeout in $i seconds): "
		if read -t 1 -r -n1 str; then
			key_pressed=1
			break
		fi
	done
	if [[ $key_pressed -eq 0 ]]; then
		echo -e "\nTime out. No input received.\n"
		return 1
	else
		echo -e "\nUser input received: '$str'\n"
		return 0
	fi
}

# Function: Detect Package Manager
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

# Function: Install apt-fast for faster package downloads
# Should be called early in the installation process
install_apt_fast() {
	if command -v apt-fast &>/dev/null; then
		echo -e "${GREEN}apt-fast is already installed.${NC}"
		return 0
	fi

	echo -e "${BLUE}Installing apt-fast for faster downloads...${NC}"
	sudo add-apt-repository -y ppa:apt-fast/stable
	sudo apt-get update
	# Use DEBIAN_FRONTEND to avoid interactive prompts
	echo debconf apt-fast/maxdownloads string 16 | sudo debconf-set-selections
	echo debconf apt-fast/dlflag boolean true | sudo debconf-set-selections
	echo debconf apt-fast/aptmanager string apt-get | sudo debconf-set-selections
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-fast
	echo -e "${GREEN}apt-fast installed successfully.${NC}"
}

# Function: Smart apt install - uses apt-fast if available, otherwise apt
# Usage: apt_install package1 package2 ...
apt_install() {
	export DEBIAN_FRONTEND=noninteractive
	if command -v apt-fast &>/dev/null; then
		sudo -E apt-fast install -y "$@"
	else
		sudo -E apt install -y "$@"
	fi
}

# Function: Smart apt update - uses apt-fast if available
apt_update() {
	if command -v apt-fast &>/dev/null; then
		sudo apt-fast update
	else
		sudo apt update
	fi
}

# Function: Configure DNF for faster downloads (Fedora)
# Enables parallel downloads, fastest mirror selection, and delta RPMs
configure_dnf_fast() {
	if [[ ! -f /etc/dnf/dnf.conf ]]; then
		return 1
	fi

	echo -e "${BLUE}Configuring DNF for faster downloads...${NC}"

	# Add max_parallel_downloads if not present
	if ! grep -q "^max_parallel_downloads=" /etc/dnf/dnf.conf; then
		echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf
	fi

	# Add fastestmirror if not present
	if ! grep -q "^fastestmirror=" /etc/dnf/dnf.conf; then
		echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf
	fi

	# Add deltarpm if not present
	if ! grep -q "^deltarpm=" /etc/dnf/dnf.conf; then
		echo "deltarpm=True" | sudo tee -a /etc/dnf/dnf.conf
	fi

	echo -e "${GREEN}DNF configured for parallel downloads.${NC}"
}

# Function: Smart dnf install
# Usage: dnf_install package1 package2 ...
dnf_install() {
	sudo dnf install -y "$@"
}

# Function: Smart dnf update
dnf_update() {
	sudo dnf -y upgrade --refresh
}

# Function: Install Packages
install_packages() {
	local package_group_name="$1"
	local brew_package_type="${2:-formula}"

	if [[ -z "$package_group_name" ]]; then
		echo -e "${RED}No package group specified.${NC}"
		return 1
	fi

	local pkg_manager
	pkg_manager=$(detect_package_manager)
	if [[ "$pkg_manager" == "unsupported" ]]; then
		echo -e "${RED}Unsupported package manager${NC}"
		return 1
	fi

	local packages=()
	eval "packages=(\"\${${package_group_name}[@]}\")"

	if [[ ${#packages[@]} -eq 0 ]]; then
		print_msg "Package group ${package_group_name} is empty. Skipping." "35"
		return 0
	fi

	local installed_packages=""
	case "$pkg_manager" in
	"brew")
		if [[ "$brew_package_type" == "cask" ]]; then
			installed_packages="$(brew list --cask 2>/dev/null || true)"
		else
			installed_packages="$(brew list --formula 2>/dev/null || true)"
		fi
		;;
	"apt")
		installed_packages="$(dpkg -l | awk '/^ii/ {print $2}')"
		;;
	"dnf")
		installed_packages="$(dnf list installed | awk 'NR>1 {print $1}' | cut -d. -f1)"
		;;
	esac

	local uninstalled_packages=()
	for package in "${packages[@]}"; do
		[[ -z "$package" ]] && continue
		if ! grep -Fqx "$package" <<<"$installed_packages"; then
			uninstalled_packages+=("$package")
		fi
	done

	if [[ ${#uninstalled_packages[@]} -eq 0 ]]; then
		print_msg "🎉 All packages from $package_group_name were already installed." "35"
		return 0
	fi

	echo -e "${RED}The following packages need to be installed:${NC}"
	for package in "${uninstalled_packages[@]}"; do
		echo "- $package"
	done

	print_msg "Installing ${#uninstalled_packages[@]} packages..." "212"
	case "$pkg_manager" in
	"brew")
		if [[ "$brew_package_type" == "cask" ]]; then
			brew install --cask "${uninstalled_packages[@]}"
		else
			brew install "${uninstalled_packages[@]}"
		fi
		;;
	"apt")
		apt_install "${uninstalled_packages[@]}"
		;;
	"dnf")
		dnf_install "${uninstalled_packages[@]}"
		;;
	esac
}

# Function: Install Docker
install_docker() {
	echo -e "$BLUE获取 Docker 安装脚本...${NC}"
	curl -fsSL https://get.docker.com -o get-docker.sh || {
		echo -e "$DARK_RED下载安装脚本失败${NC}"
		return 1
	}
	echo -e "$BLUE运行安装脚本...${NC}"
	sudo sh get-docker.sh || {
		echo -e "$DARK_RED安装 Docker 失败${NC}"
		rm -rf get-docker.sh
		return 1
	}
	rm -rf get-docker.sh
	echo -e "$BLUE将当前用户添加到 docker 组...${NC}"
	sudo usermod -aG docker "$USER" || {
		echo -e "$DARK_RED添加用户到 docker 组失败${NC}"
		return 1
	}
	echo -e "$BLUE启动并设置 Docker 服务开机自启...${NC}"
	(sudo systemctl start docker && sudo systemctl enable docker && sudo systemctl restart docker) || {
		echo -e "$DARK_RED启动或设置开机自启失败${NC}"
		return 1
	}
	echo -e "${GREEN}Docker 安装完成。请考虑重新登录或重启以使组设置生效。${NC}"
}

# Function: Check and Install Docker
install_and_configure_docker() {
	print_msg "开始检查 Docker 环境..." "212"

	# Check if running inside a container (simple check)
	if [[ -f /.dockerenv ]]; then
		echo -e "${GREEN}Running inside Docker container. Skipping Docker installation.${NC}"
		return 0
	fi

	if grep -qi microsoft /proc/version || [[ "$AUTO_RUN" == "true" ]]; then
		echo -e "${GREEN}在 WSL2 中或者不需要安装 Docker${NC}"
	else
		if command -v docker >/dev/null; then
			echo -e "${GREEN}Docker 已安装✅，跳过安装步骤。${NC}"
		else
			echo -e "${YELLOW}Docker 未安装，开始安装过程...${NC}"
			install_docker
		fi
	fi
}

# Function: Get Latest Kotlin Version
get_latest_version() {
	LATEST_VERSION=$(curl -s -L -I https://github.com/JetBrains/kotlin/releases/latest | grep -i location | sed -E 's/.*tag\/(v[0-9\.]+).*/\1/')
}

# Function: Setup Kotlin Vars
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

# Function: Download and Extract Kotlin
download_and_extract_kotlin() {
	URL=$1
	TARGET_DIR=$2
	FILE_NAME=$(basename "${URL}")
	if [[ -d "$TARGET_DIR" ]]; then
		print_msg "${FILE_NAME} is already installed in ${TARGET_DIR}." "35"
		return 0
	fi
	print_msg "正在下载 $FILE_NAME......" "212"
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
	print_msg "${FILE_NAME} has been installed successfully to ${TARGET_DIR}" "35"
}

# Function: Install Fonts
install_fonts() {
	if [[ $AUTO_RUN == "true" ]] || [[ ! -t 0 ]]; then
		echo -e "${YELLOW}Skipping font installation (non-interactive or auto-run).${NC}"
		return 0
	fi
	echo -ne "$GREEN是否需要下载字体以支持终端模拟器的渲染？(y/n): ${NC}"
	read download_confirm
	if [[ $download_confirm != 'y' ]]; then
		echo -e "$GREEN跳过字体下载。${NC}"
		return 0
	fi
	font_source="/tmp/Fonts/"
	git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Fonts.git $font_source && print_msg "✅Fonts 完成下载" "35"
	if [[ "$(uname)" == "Darwin" ]]; then
		font_dest="$HOME/Library/Fonts"
	else
		font_dest="$HOME/.local/share/fonts/"
	fi
	print_msg "正在安装字体......" "212"
	if [[ ! -d "$font_source" ]]; then
		echo "字体目录 '$font_source' 不存在，请确认当前目录下有 $dest_Fonts 文件夹。"
		exit 1
	fi
	sudo mkdir -p "$font_dest"
	print_msg "正在复制字体文件到 $font_dest..." "212"
	find "$font_source" -type f \( -iname "*.ttf" -o -iname "*.otf" \) ! -iname "README*" -exec sudo cp -v {} "$font_dest" \;
	if [[ "$(uname)" == "Darwin" ]]; then
		print_msg "在 macOS 上，字体缓存将自动更新。" "35"
	else
		print_msg "在 Linux 上，刷新字体缓存" "35"
		fc-cache -fv
	fi
	print_msg "字体安装完成。✅" "35"
}
