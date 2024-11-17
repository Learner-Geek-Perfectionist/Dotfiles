#!/bin/bash

# 一旦错误，就退出
set -e

# macOS
brew_casks=(
    alfred videofusion wpsoffice tencent-meeting google-chrome
    orbstack dingtalk baidunetdisk anaconda iina KeepingYouAwake
    pycharm android-studio input-source-pro qq chatgpt fleet
    intellij-idea qqmusic jetbrains-gateway telegram
    clion jordanbaird-ice visual-studio-code discord keycastr wechat
    douyin kitty feishu microsoft-edge Eudic
)

brew_formulas=(
    gettext msgpack ruby graphviz kotlin python
    brotli git lpeg ncurses sqlite openjdk grep
    c-ares htop lua neovim tree-sitter bash tcpdump
    ca-certificates icu4c luajit node unibilium
    cmake libnghttp2 luv openssl@3 vim perl
    cmake-docs libsodium lz4 pcre2 xz llvm
    fastfetch libuv lzip z3 tree rust autoconf
    fd libvterm make readline zstd eza less
    fzf libyaml mpdecimal ripgrep go
    gcc ninja wget mas pkg-config jq
)

#ubuntu
packages_ubuntu=(
    openssh-server
    debconf-utils
    net-tools
    git
    unzip
    zip
    ninja-build
    neovim
    ruby-full
    fd-find
    ripgrep
    cmake
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
    kitty
    wget
    pkg-config
    graphviz
    sudo
    tcpdump
    kotlin
    golang
    rustc
    software-properties-common
    valgrind
    curl
    tar
    locales
    man-db
    jq
    tshark
    eza
    hyperfine
    autoconf
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
    rust
    glibc-locale-source
    glibc-langpack-zh
    jq
    eza
    openssl
    hyperfine
    autoconf
)
