#!/bin/bash

set -e

# Shared metadata
DOTFILES_VERSION="${DOTFILES_VERSION:-1.0.0}"
LOG_FILE="${LOG_FILE:-/tmp/dotfiles-install.log}"

# Minimal colors so logs remain readable before repo files exist
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export LIGHT_BLUE='\033[1;34m'
export NC='\033[0m'

# Initialize log header once
if [[ -z "$__DOTFILES_LOG_HEADER" ]]; then
	{
		echo "======================================"
		echo "Dotfiles Installation Log"
		echo "Version: $DOTFILES_VERSION"
		echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
		echo "OS: $(uname -s) $(uname -r)"
		echo "User: $(whoami)"
		echo "======================================"
		echo ""
	} >"$LOG_FILE"
	export __DOTFILES_LOG_HEADER=1
fi

TMP_DIR="/tmp/Dotfiles"

# Clean previous runs
[[ -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"

# Configure sudo to be passwordless for the current user
# Default is enabled (true) for convenience in dev/container environments
# Set ENABLE_NOPASSWD_SUDO=false to disable
ENABLE_NOPASSWD_SUDO="${ENABLE_NOPASSWD_SUDO:-true}"
if [[ "$ENABLE_NOPASSWD_SUDO" == "true" ]] && command -v sudo >/dev/null; then
	SUDOERS_FILE="/etc/sudoers.d/$(whoami)-nopasswd"
	# 使用 sudoers.d 目录更安全，避免直接修改主 sudoers 文件
	if [[ ! -f "$SUDOERS_FILE" ]]; then
		echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" >/dev/null
		sudo chmod 440 "$SUDOERS_FILE"
		echo -e "${LIGHT_BLUE}User $(whoami) configured for passwordless sudo.${NC}"
	fi
fi

# Pre-requisites for Linux
if [[ $(uname -s) == "Linux" ]]; then
	echo -e "${BLUE}Installing Linux prerequisites...${NC}"
	if grep -q 'ID=ubuntu' /etc/os-release; then
		# Clean up potentially broken third-party repositories before apt update
		sudo rm -f /etc/apt/sources.list.d/charm.list 2>/dev/null || true
		sudo rm -f /etc/apt/keyrings/charm.gpg 2>/dev/null || true

		sudo DEBIAN_FRONTEND=noninteractive apt update &&
			sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends git software-properties-common bc unzip locales lsb-release wget tzdata gnupg curl
		sudo DEBIAN_FRONTEND=noninteractive TZ=Asia/Shanghai dpkg-reconfigure -f noninteractive tzdata
	elif grep -q 'ID=fedora' /etc/os-release; then
		sudo dnf update -y && sudo dnf install -y git bc unzip glibc glibc-common glibc-langpack-zh langpacks-zh_CN glibc-locale-source curl
	fi
fi

# Ensure git is available on macOS
if [[ $(uname -s) == "Darwin" ]] && ! command -v git &>/dev/null; then
	echo -e "${YELLOW}Installing Xcode Command Line Tools (includes git)...${NC}"
	xcode-select --install 2>/dev/null || true
	# Wait for installation
	echo -e "${YELLOW}Please complete the installation dialog, then press Enter to continue...${NC}"
	read -r
fi

echo -e "${BLUE}Cloning Dotfiles repository (v$DOTFILES_VERSION)...${NC}"
git clone --depth=1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git "$TMP_DIR"

# Ensure XDG base directories exist
mkdir -p "$HOME/.config/zsh/plugins" "${HOME}/.config/kitty" "$HOME/.cache/zsh" "${HOME}/.local/share/zinit" "$HOME/.local/state"

# Execute main script from the scripts directory
echo -e "${BLUE}Starting main installation...${NC}"
source "$TMP_DIR/scripts/main.sh"

echo -e "${GREEN}✅ Installation completed!${NC}"
echo -e "${GREEN}📝 Installation log saved to: $LOG_FILE${NC}"

