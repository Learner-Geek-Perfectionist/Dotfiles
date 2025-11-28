#!/bin/bash

# Exit on error
set -e

# Use library - ensure we can run standalone
if [[ -z "$LIB_DIR" ]]; then
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
	LIB_DIR="$DOTFILES_DIR/lib"
fi

if [[ -z "$DOTFILES_DIR" ]]; then
	DOTFILES_DIR="$(cd "$(dirname "$LIB_DIR")" && pwd)"
fi

SCRIPTS_DIR="${SCRIPTS_DIR:-$DOTFILES_DIR/scripts}"

# Source required libraries (utils.sh will auto-source constants.sh)
source "$LIB_DIR/utils.sh"

echo -e "${GREEN}🚀 Setting up dotfiles (v${DOTFILES_VERSION}) from $DOTFILES_DIR...${NC}"
log_msg "Setting up dotfiles from $DOTFILES_DIR" "false"

# Ensure XDG base directories exist
mkdir -p "$HOME/.config/zsh/plugins" "${HOME}/.config/kitty" "$HOME/.cache/zsh" "${HOME}/.local/share/zinit" "$HOME/.local/state"

# Configuration files to copy
configs=(".zshenv" ".zprofile" ".zshrc" ".config/kitty" ".config/zsh")

echo -e "${YELLOW}🔍 Updating configuration files...${NC}"
for config in "${configs[@]}"; do
	TARGET="${HOME}/${config}"
	SOURCE="${DOTFILES_DIR}/${config}"

	if [[ -e "$SOURCE" ]]; then
		echo -e "${PURPLE}📋 Copying ${config} to $TARGET ${NC}"
		log_msg "Copying $config to $TARGET" "false"
		mkdir -p "$(dirname "$TARGET")"
		# Remove existing file/directory and copy new one (direct overwrite)
		[[ -e "$TARGET" || -L "$TARGET" ]] && rm -rf "$TARGET"
		cp -a "$SOURCE" "$TARGET"
	else
		echo -e "${ORANGE}⚠️ Source file $SOURCE not found, skipping.${NC}"
		log_msg "WARNING: Source $SOURCE not found, skipping" "false"
	fi
done

# macOS specific files
if [[ "$(uname)" == "Darwin" ]]; then
	# sh-script
	cp -r "$DOTFILES_DIR/sh-script/" "$HOME/sh-script/"

	# Hammerspoon
	if [[ -d "${HOME}/.hammerspoon" ]]; then
		rm -rf "${HOME}/.hammerspoon"
	fi
	cp -r "${DOTFILES_DIR}/.hammerspoon" "${HOME}/.hammerspoon"

	# Karabiner
	if [[ -f "${HOME}/.config/karabiner/karabiner.json" ]]; then
		rm -rf "${HOME}/.config/karabiner/karabiner.json"
	fi
	mkdir -p "${HOME}/.config/karabiner"
	cp -r "${DOTFILES_DIR}/.config/karabiner/karabiner.json" "${HOME}/.config/karabiner/karabiner.json"
fi

echo -e "${GREEN}✅ Dotfiles installed successfully.${NC}"

rm -rf "$HOME/.zcompdump"

echo -e "${GREEN}🎉 Setup Complete! Run 'zsh' to start zsh and auto-install plugins.${NC}"
