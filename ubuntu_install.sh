# 一旦错误，就退出
set -e

# 设置国内源
sudo sed -i.bak -r 's|^#?(deb\|deb-src) http://archive.ubuntu.com/ubuntu/|\1 https://mirrors.ustc.edu.cn/ubuntu/|' /etc/apt/sources.list

# 设置时区
sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" | sudo tee /etc/timezone >/dev/null
sudo dpkg-reconfigure --frontend noninteractive tzdata

# 1.生成 UTF-8 字符集的 Locale（locale-gen 适用于 Debian 及其衍生系统，localedef 存在于几乎所有的 Linux 发行版中）
sudo locale-gen zh_CN.UTF-8

# 2.设置中文语言输出信息
echo "LANG=zh_CN.UTF-8" | sudo tee /etc/default/locale
echo "LC_ALL=zh_CN.UTF-8" | sudo tee -a /etc/default/locale

# 添加PPA并更新
sudo add-apt-repository -y ppa:wireshark-dev/stable
sudo add-apt-repository -y ppa:openjdk-r/ppa
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
echo "wireshark-common wireshark-common/install-setuid seen true" | sudo debconf-set-selections
sudo apt update && sudo apt upgrade -y

# 安装 ubuntu 包
install_packages "packages_ubuntu"

source /tmp/Dotfiles/ubuntu_install_tools.sh

# 取消最小化安装
sudo apt search unminimize 2>/dev/null | grep -q "^unminimize/" && (sudo apt install unminimize -y && yes | sudo unminimize) || echo -e "${RED}unminimize包不可用。${NC}"

# 搜索可用的 OpenJDK 包并尝试获取最新版本
sudo apt install -y "$(apt search openjdk | grep -oP 'openjdk-\d+-jdk' | sort -V | tail -n1)"

# =================================开始安装 Docker=================================
install_and_configure_docker
# =================================开始安装 Docker=================================

# =================================开始安装 Kotlin/Native =================================
# 设置 Kotlin 的变量
setup_kotlin_environment

# 安装 Kotlin/Native
download_and_extract_kotlin $KOTLIN_NATIVE_URL $INSTALL_DIR
download_and_extract_kotlin $KOTLIN_COMPILER_URL $COMPILER_INSTALL_DIR
# =================================结束安装 Kotlin/Native =================================

sudo apt clean
