#!/bin/bash
# Ubuntu Installation Logic

log_msg "Starting Ubuntu installation..." "false"

# 1. Configure Mirrors (China Optimization)
# Get Codename (focal, jammy, etc.)
CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
ARCH=$(dpkg --print-architecture)

if [[ $ARCH =~ ^(arm|arm64|aarch64|powerpc|s390x)$ ]]; then
	REPO_PATH="ubuntu-ports"
else
	REPO_PATH="ubuntu"
fi

MIRROR_DOMAIN="mirrors.tuna.tsinghua.edu.cn"

# Backup sources
if [[ ! -f /etc/apt/sources.list.bak ]]; then
	sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
fi

sudo sed -i -E "s|http://[^/]*/ubuntu(-ports)?|https://${MIRROR_DOMAIN}/${REPO_PATH}|g" /etc/apt/sources.list

apt_update

# 2. Configure Locale & Timezone
export DEBIAN_FRONTEND=noninteractive TZ=Asia/Shanghai
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "$TZ" | sudo tee /etc/timezone >/dev/null
apt_install tzdata
sudo -E dpkg-reconfigure -f noninteractive tzdata

sudo locale-gen zh_CN.UTF-8
echo "LANG=zh_CN.UTF-8" | sudo tee /etc/default/locale
echo "LC_ALL=zh_CN.UTF-8" | sudo tee -a /etc/default/locale

# 3. PPA & Updates
sudo add-apt-repository -y ppa:wireshark-dev/stable
# Pre-seed wireshark config
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
echo "wireshark-common wireshark-common/install-setuid seen true" | sudo debconf-set-selections

apt_update
if command -v apt-fast &>/dev/null; then
	sudo apt-fast upgrade -y
else
	sudo apt upgrade -y
fi

# 4. Install Core Packages
install_packages "packages_ubuntu"

# 5. Run Extra Ubuntu Tools Script
source "$SCRIPTS_DIR/ubuntu_tools.sh"

# 6. Unminimize (Restore man pages etc.)
if sudo apt search unminimize 2>/dev/null | grep -q "^unminimize/"; then
	apt_install unminimize
	yes | sudo unminimize || echo "Unminimize skipped or failed."
else
	echo -e "${RED}unminimize package not available.${NC}"
fi

# 7. Java (OpenJDK)
if curl -fsI "https://ppa.launchpadcontent.net/openjdk-r/ppa/ubuntu/dists/$(lsb_release -sc)/Release" >/dev/null; then
	sudo add-apt-repository -y ppa:openjdk-r/ppa && apt_update
else
	echo -e "${RED}OpenJDK PPA not available for $(lsb_release -sc), skipping.${NC}"
fi
# Install latest jdk
LATEST_JDK=$(apt search ^openjdk-[0-9]+-jdk$ 2>/dev/null | grep -oP 'openjdk-\d+-jdk' | sort -V | tail -n1)
if [[ -n "$LATEST_JDK" ]]; then
	apt_install "$LATEST_JDK"
fi

# 8. Docker
install_and_configure_docker

# 9. Kotlin
setup_kotlin_environment
download_and_extract_kotlin "$KOTLIN_NATIVE_URL" "$INSTALL_DIR"
download_and_extract_kotlin "$KOTLIN_COMPILER_URL" "$COMPILER_INSTALL_DIR"

if command -v apt-fast &>/dev/null; then
	sudo apt-fast clean
else
	sudo apt clean
fi
