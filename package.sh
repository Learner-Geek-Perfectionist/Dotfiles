# 一旦错误，就退出
set -e

# macOS
brew_casks=(
    videofusion wpsoffice-cn tencent-meeting google-chrome
    orbstack dingtalk baidunetdisk anaconda iina
    pycharm android-studio qq chatgpt fleet hammerspoon
    intellij-idea qqmusic jetbrains-gateway telegram
    clion jordanbaird-ice visual-studio-code discord keycastr wechat
    douyin kitty feishu microsoft-edge Eudic karabiner-elements
)

brew_formulas=(
    gettext msgpack ruby graphviz kotlin python
    brotli git lpeg ncurses sqlite openjdk grep
    c-ares htop lua neovim tree-sitter bash tcpdump
    ca-certificates icu4c luajit node unibilium
    cmake libnghttp2 luv openssl@3 vim perl
    cmake-docs libsodium lz4 pcre2 xz llvm
    fastfetch libuv lzip z3 tree autoconf chafa
    fd libvterm make readline zstd eza less
    fzf libyaml mpdecimal ripgrep go coreutils
    gcc ninja wget mas pkgconf jq
)

#ubuntu
packages_ubuntu=(
    openssh-server
    lsof
    debconf-utils
    apt-utils
    pkg-config
    ncurses-bin
    net-tools
    lsb-release
    git
    zip
    ninja-build
    neovim
    ruby-full
    nodejs
    iputils-ping
    procps
    htop
    traceroute
    tree
    coreutils
    zsh
    fontconfig
    python3
    iproute2
    wget
    pkg-config
    graphviz
    sudo
    tcpdump
    golang
    valgrind
    curl
    tar
    make
    locales
    man-db
    jq
    tshark
    autoconf
    systemd
    language-pack-zh-hans
    wireshark
)

#fedora
packages_fedora=(
    glibc
    glibc-common
    coreutils
    coreutils-common
    lsof
    dnf-utils
    man-pages
    man-db
    rustup
    openssh-server
    iproute
    net-tools
    git
    unzip
    zip
    ripgrep
    ninja-build
    neovim
    ruby
    kitty
    cmake
    nodejs
    iputils
    procps-ng
    htop
    traceroute
    tree
    coreutils
    zsh
    fontconfig
    python3
    wget
    pkgconf-pkg-config
    graphviz
    wireshark
    tcpdump
    java-latest-openjdk
    golang
    glibc-locale-source
    glibc-langpack-zh
    langpacks-zh_CN
    jq
    openssl
    hyperfine
    sudo
    autoconf
    systemd
    bc
    chafa
    lua
)
