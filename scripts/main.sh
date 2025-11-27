#!/bin/bash

# Exit on error
set -e

# Define paths relative to this script but allow overrides (e.g. local repo, /tmp clone)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LIB_DIR="${LIB_DIR:-$DOTFILES_DIR/lib}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$DOTFILES_DIR/scripts}"

export DOTFILES_DIR LIB_DIR SCRIPTS_DIR

# Source Libraries
source "$LIB_DIR/constants.sh"
source "$LIB_DIR/packages.sh"
source "$LIB_DIR/utils.sh"

echo -e "${GREEN}🚀 Starting main installation script...${NC}"

OS_TYPE=$(uname -s)

if [[ "$OS_TYPE" == "Darwin" ]]; then
	source "$SCRIPTS_DIR/macos_install.sh"

elif [[ "$OS_TYPE" == "Linux" ]]; then

	# Detect Distro
	DISTRO_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

	echo -e "${CYAN}Detected Linux Distro: $DISTRO_ID${NC}"

	if [[ "$DISTRO_ID" == "ubuntu" ]]; then
		source "$SCRIPTS_DIR/ubuntu_install.sh"

	elif [[ "$DISTRO_ID" == "fedora" ]]; then
		source "$SCRIPTS_DIR/fedora_install.sh"

	else
		echo -e "${RED}Unsupported distribution: $DISTRO_ID. Only Fedora and Ubuntu are supported.${NC}"
		exit 1
	fi

	# Helper: Setuid for network tools (Wireshark/Tcpdump)
	for tool in tcpdump dumpcap tshark; do
		if command -v $tool >/dev/null; then
			sudo chmod u+s $(command -v $tool)
		fi
	done

	# Change Shell to Zsh
	CURRENT_SHELL=$(getent passwd "$(whoami)" | cut -d: -f7)
	ZSH_PATH=$(command -v zsh)
	if [[ -n "$ZSH_PATH" && "$ZSH_PATH" != "$CURRENT_SHELL" ]]; then
		print_msg "${YELLOW}Changing default shell to zsh...${NC}" "212"
		sudo chsh -s "$ZSH_PATH" "$(whoami)"
	fi

else
	echo -e "${MAGENTA}Unknown Operating System: $OS_TYPE${NC}"
	exit 1
fi

# Common ZSH Configuration
source "$SCRIPTS_DIR/zsh_install.sh"
