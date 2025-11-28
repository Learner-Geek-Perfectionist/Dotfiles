#!/bin/bash
# Wrapper script to maintain compatibility with user's workflow
# Usage 3: "仅仅安装 zsh 的 dotfiles"

set -e

# Minimal colors
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

# Log file
LOG_FILE="/tmp/dotfiles-install.log"

# Initialize log with header
{
	echo "======================================"
	echo "Dotfiles Update Log"
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
				sudo apt update && sudo apt install -y git
				;;
			fedora)
				sudo dnf install -y git
				;;
			esac
		fi
	fi
fi

# Clone if needed (if run standalone without repo)
DOTFILES_DIR="${DOTFILES_DIR:-/tmp/Dotfiles}"
if [[ -d "$DOTFILES_DIR/.git" ]]; then
	echo -e "${BLUE}Updating existing Dotfiles...${NC}"
	git -C "$DOTFILES_DIR" pull --ff-only
elif [[ -d "$DOTFILES_DIR" ]]; then
	rm -rf "$DOTFILES_DIR"
	git clone --depth=1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git "$DOTFILES_DIR"
else
	git clone --depth=1 https://github.com/Learner-Geek-Perfectionist/Dotfiles.git "$DOTFILES_DIR"
fi

export DOTFILES_DIR
export LIB_DIR="$DOTFILES_DIR/lib"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"
source "$SCRIPTS_DIR/setup_dotfiles.sh"
