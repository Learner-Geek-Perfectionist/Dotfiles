#!/bin/bash
# Fedora Installation Logic

log_msg "Starting Fedora installation..." "false"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPTS_DIR:-$SCRIPT_DIR}"

# 1. Configure Mirrors (USTC)
sudo sed -e 's|^metalink=|#metalink=|g' \
	-e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' \
	-i.bak \
	/etc/yum.repos.d/fedora.repo \
	/etc/yum.repos.d/fedora-updates.repo

sudo dnf -y upgrade --refresh

# 2. Timezone & Locale
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone >/dev/null

sudo localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8
echo "LANG=zh_CN.UTF-8" | sudo tee /etc/locale.conf
echo "LC_ALL=zh_CN.UTF-8" | sudo tee -a /etc/locale.conf

# 3. Enable Man Pages (Remove nodocs)
sudo sed -i '/tsflags=nodocs/s/^/#/' /etc/dnf/dnf.conf

# 4. Install Dev Group
sudo dnf group install -y --setopt=strict=0 "c-development"

# 5. Install Packages
install_packages "packages_fedora"

# 6. Extra Tools
source "$SCRIPTS_DIR/fedora_tools.sh"

# 7. Reinstall packages to get man pages
packages_to_reinstall=$(rpm -qads --qf "PACKAGE: %{NAME}\n" | sed -n -E '/PACKAGE: /{s/PACKAGE: // ; h ; b }; /^not installed/ { g; p }' | uniq)
if [[ -z "$packages_to_reinstall" ]]; then
	echo -e "${GREEN}No packages need man-page reinstallation.${NC}"
else
	# Might fail if list is too long, but usually ok
	sudo dnf -y reinstall $packages_to_reinstall && sudo mandb -q 2>/dev/null || true
fi

# 8. Docker
install_and_configure_docker

# 9. Kotlin
setup_kotlin_environment
download_and_extract_kotlin "$KOTLIN_NATIVE_URL" "$INSTALL_DIR"
download_and_extract_kotlin "$KOTLIN_COMPILER_URL" "$COMPILER_INSTALL_DIR"

sudo dnf clean all && sudo dnf makecache
