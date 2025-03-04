# 一旦错误，就退出
set -e

# macOS
brew_casks=(
    videofusion wpsoffice-cn tencent-meeting google-chrome
    orbstack dingtalk baidunetdisk anaconda iina
    pycharm android-studio qq chatgpt fleet
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
    fastfetch libuv lzip z3 tree  autoconf
    fd libvterm make readline zstd eza less
    fzf libyaml mpdecimal ripgrep go coreutils
    gcc ninja wget mas pkgconf jq hammerspoon
)

#ubuntu
packages_ubuntu=(
    openssh-server
    debconf-utils
    ncurses-bin
    net-tools
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
    openssh-server
    iproute
    net-tools
    fd-find
    git
    unzip
    zip
    ripgrep
    fastfetch
    fzf
    ninja-build
    neovim
    ruby
    kitty
    cmake
    make
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
    eza
    openssl
    hyperfine
    sudo
    autoconf
    systemd
    cargo
    bc
    bat
    chafa
    lua
)
