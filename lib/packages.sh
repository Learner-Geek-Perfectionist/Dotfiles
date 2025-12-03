#!/bin/bash
# Package definitions for macOS (Homebrew)
# Linux 包管理已迁移到 devbox.json

set -e

# ========================================
# macOS Homebrew Casks (GUI 应用)
# ========================================
brew_casks=(
	# 开发工具
	visual-studio-code
	kitty
	orbstack
	github@beta

	# JetBrains IDE
	intellij-idea
	pycharm
	clion
	android-studio
	fleet
	jetbrains-gateway

	# 网络工具
	wireshark
	mihomo-party

	# 浏览器
	google-chrome
	microsoft-edge

	# 通讯工具
	wechat
	qq
	telegram
	discord
	dingtalk
	feishu
	tencent-meeting

	# 媒体
	iina
	qqmusic
	douyin

	# 办公
	wpsoffice-cn
	baidunetdisk

	# 系统工具
	karabiner-elements
	hammerspoon
	jordanbaird-ice
	maczip
	keycastr
	display-pilot

	# AI
	chatgpt

	# 其他
	anaconda
	Eudic
	videofusion
	cmake-app
)

# ========================================
# macOS Homebrew Formulas (CLI 工具)
# ========================================
brew_formulas=(
	# 核心工具
	git
	curl
	wget
	coreutils

	# Shell
	zsh
	bash

	# 编辑器
	neovim
	vim

	# 终端增强
	fzf
	ripgrep
	fd
	eza
	bat
	htop
	tree
	less
	tmux

	# 系统信息
	fastfetch

	# 开发工具
	cmake
	cmake-docs
	ninja
	make
	autoconf
	pkg-config

	# 编译器
	gcc
	llvm

	# 语言
	python
	nodejs
	go
	rustup
	rust
	ruby
	kotlin
	openjdk
	lua
	luajit
	perl

	# Rust 工具
	cargo-update
	cargo-binstall
	dust

	# 网络工具
	tcpdump

	# 文档和分析
	graphviz
	doxygen
	jq
	shfmt
	chafa

	# 库
	openssl@3
	sqlite
	ncurses
	readline
	libyaml
	libvterm
	boost

	# 压缩
	xz
	lz4
	lzip
	zstd
	brotli

	# Dotfiles 管理
	chezmoi

	# 其他
	rsync
	mas
	tree-sitter
	z3
	googletest
	google-benchmark
	tldr
)
