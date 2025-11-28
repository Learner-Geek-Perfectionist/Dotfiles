#!/bin/bash

# Exit on error
set -e

# Minimal colors for bootstrap
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log file
LOG_FILE="/tmp/dotfiles-install.log"

# Initialize log with header
{
	echo "======================================"
	echo "Dotfiles Zsh Config Log"
	echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
	echo "OS: $(uname -s) $(uname -r)"
	echo "User: $(whoami)"
	echo "======================================"
	echo ""
} >"$LOG_FILE"

# Redirect all output to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Auto-install git if missing
if ! command -v git &>/dev/null; then
	echo -e "${YELLOW}Git not found, installing automatically...${NC}"
	OS_TYPE=$(uname -s)
	if [[ "$OS_TYPE" == "Darwin" ]]; then
		xcode-select --install 2>/dev/null || true
		echo -e "${YELLOW}Please complete the Xcode Tools installation, then press Enter...${NC}"
		read -r
	elif [[ "$OS_TYPE" == "Linux" ]]; then
		if [[ -f /etc/os-release ]]; then
			DISTRO=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
			case "$DISTRO" in
			ubuntu | debian)
				export DEBIAN_FRONTEND=noninteractive
				sudo apt update && sudo apt install -y git curl
				;;
			fedora)
				sudo dnf install -y git curl
				;;
			esac
		fi
	fi
fi

# Define paths (allow override for local testing)
WORK_DIR="${DOTFILES_DIR:-/tmp/Dotfiles}"
LIB_DIR="${LIB_DIR:-$WORK_DIR/lib}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$WORK_DIR/scripts}"

# Prepare workspace (reuse if already cloned)
if [[ -d "$WORK_DIR/.git" ]]; then
	echo -e "${BLUE}Updating existing Dotfiles clone in $WORK_DIR...${NC}"
	git -C "$WORK_DIR" pull --ff-only
else
	if [[ -d "$WORK_DIR" ]]; then
		if [[ "$WORK_DIR" == /tmp/* ]]; then
			rm -rf "$WORK_DIR"
		else
			echo -e "${RED}Directory $WORK_DIR already exists and is not a Git repository. Please remove it or set DOTFILES_DIR to an empty path.${NC}"
			exit 1
		fi
	fi
	echo -e "${BLUE}Cloning Dotfiles repository into $WORK_DIR...${NC}"
	git clone --depth=1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git "$WORK_DIR"
fi

export DOTFILES_DIR="$WORK_DIR"
export LIB_DIR SCRIPTS_DIR

# Source Libraries
source "$LIB_DIR/constants.sh"
source "$LIB_DIR/packages.sh"
source "$LIB_DIR/utils.sh"

# Initialize logging
init_logging

echo -e "${GREEN}🚀 Starting Zsh Configuration Script...${NC}"

OS_TYPE=$(uname -s)

if [[ "$OS_TYPE" == "Darwin" ]]; then
	# Check Homebrew
	if ! command -v brew >/dev/null 2>&1; then
		print_msg "Homebrew not found. Installing..." "212"
		/bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
		source "${HOME}/.zprofile"
	fi

	print_msg "Installing Zsh tools for macOS..." "35"
	install_packages "zsh_tools_macos"

elif [[ "$OS_TYPE" == "Linux" ]]; then
	DISTRO_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

	if [[ "$DISTRO_ID" == "ubuntu" ]]; then
		sudo apt update
		print_msg "Installing Zsh tools for Ubuntu..." "35"
		install_packages "zsh_tools_ubuntu"
		# Source the extra tools script (cmake, llvm, etc)
		source "$SCRIPTS_DIR/ubuntu_tools.sh"

	elif [[ "$DISTRO_ID" == "fedora" ]]; then
		sudo dnf -y upgrade --refresh
		print_msg "Installing Zsh tools for Fedora..." "35"
		install_packages "zsh_tools_fedora"
		# Source the extra tools script
		source "$SCRIPTS_DIR/fedora_tools.sh"
	fi

	# Change Shell
	CURRENT_SHELL=$(getent passwd "$(whoami)" | cut -d: -f7)
	ZSH_PATH=$(command -v zsh)
	if [[ -n "$ZSH_PATH" && "$ZSH_PATH" != "$CURRENT_SHELL" ]]; then
		print_msg "Changing default shell to zsh..." "212"
		sudo chsh -s "$ZSH_PATH" "$(whoami)"
	fi
fi

# Setup Dotfiles
source "$SCRIPTS_DIR/setup_dotfiles.sh"
