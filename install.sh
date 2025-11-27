#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Dotfiles Version (duplicated here for pre-clone display)
DOTFILES_VERSION="1.0.0"

# Define minimal colors for bootstrap (before repo is cloned)
# Note: Full color definitions are in lib/constants.sh, but we need these
# basic colors for output before the repository is available.
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export LIGHT_BLUE='\033[1;34m'
export NC='\033[0m'

# Log file
LOG_FILE="/tmp/dotfiles-install.log"

# Initialize log
echo "======================================" >"$LOG_FILE"
echo "Dotfiles Installation Log" >>"$LOG_FILE"
echo "Version: $DOTFILES_VERSION" >>"$LOG_FILE"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG_FILE"
echo "OS: $(uname -s) $(uname -r)" >>"$LOG_FILE"
echo "User: $(whoami)" >>"$LOG_FILE"
echo "======================================" >>"$LOG_FILE"

TMP_DIR="/tmp/Dotfiles"

# Clean previous runs
[[ -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"

# Configure sudo to be passwordless for the current user
# Default is enabled (true) for convenience in dev/container environments
# Set ENABLE_NOPASSWD_SUDO=false to disable
ENABLE_NOPASSWD_SUDO="${ENABLE_NOPASSWD_SUDO:-true}"
if [[ "$ENABLE_NOPASSWD_SUDO" == "true" ]] && command -v sudo >/dev/null; then
	# Check if already configured to avoid duplicate entries
	if ! sudo grep -q "^$(whoami) ALL=(ALL) NOPASSWD: ALL" /etc/sudoers 2>/dev/null; then
		echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers >/dev/null
		echo -e "${LIGHT_BLUE}User $(whoami) configured for passwordless sudo.${NC}"
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configured passwordless sudo for $(whoami)" >>"$LOG_FILE"
	fi
fi

# Pre-requisites for Linux
if [[ $(uname -s) == "Linux" ]]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Linux prerequisites..." >>"$LOG_FILE"
	if grep -q 'ID=ubuntu' /etc/os-release; then
		export DEBIAN_FRONTEND=noninteractive TZ=Asia/Shanghai
		sudo -E apt update &&
			sudo -E apt install -y --no-install-recommends git software-properties-common bc unzip locales lsb-release wget tzdata gnupg curl
		sudo -E dpkg-reconfigure -f noninteractive tzdata
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
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cloning Dotfiles repository..." >>"$LOG_FILE"
git clone --depth=1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git "$TMP_DIR"

# Ensure XDG base directories exist
mkdir -p "$HOME/.config/zsh/plugins" "${HOME}/.config/kitty" "$HOME/.cache/zsh" "${HOME}/.local/share/zinit" "$HOME/.local/state"

# Execute main script from the scripts directory
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting main installation..." >>"$LOG_FILE"
source "$TMP_DIR/scripts/main.sh"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installation completed!" >>"$LOG_FILE"
echo -e "${GREEN}📝 Installation log saved to: $LOG_FILE${NC}"
