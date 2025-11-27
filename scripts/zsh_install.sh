#!/bin/bash

# Exit on error
set -e

# Use library if sourced, else try to source it (fallback)
if [[ -z "$LIB_DIR" ]]; then
	# Fallback if run standalone (unlikely but good practice)
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
	LIB_DIR="$DOTFILES_DIR/lib"
	source "$LIB_DIR/constants.sh"
	source "$LIB_DIR/utils.sh"
else
	DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$LIB_DIR")" && pwd)}"
fi

SCRIPTS_DIR="${SCRIPTS_DIR:-$DOTFILES_DIR/scripts}"

# Install Fonts (Interactive)
install_fonts

print_msg "Configuring Dotfiles..." "35"

# Run the dotfiles setup script
source "$SCRIPTS_DIR/setup_dotfiles.sh"
