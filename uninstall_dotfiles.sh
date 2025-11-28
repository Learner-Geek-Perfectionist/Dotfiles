#!/bin/bash
# Dotfiles Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/Learner-Geek-Perfectionist/Dotfiles/master/uninstall_dotfiles.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║              Dotfiles Uninstaller                          ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Confirm uninstall
echo -e "${YELLOW}⚠️  This will remove the following:${NC}"
echo -e "   • ${BLUE}~/.zshenv${NC}"
echo -e "   • ${BLUE}~/.zprofile${NC}"
echo -e "   • ${BLUE}~/.zshrc${NC}"
echo -e "   • ${BLUE}~/.config/zsh${NC}"
echo -e "   • ${BLUE}~/.config/kitty${NC}"
echo -e "   • ${BLUE}~/.cache/zsh${NC}"
echo -e "   • ${BLUE}~/.local/share/zinit${NC}"
if [[ "$(uname)" == "Darwin" ]]; then
	echo -e "   • ${BLUE}~/sh-script${NC}"
	echo -e "   • ${BLUE}~/.hammerspoon${NC}"
	echo -e "   • ${BLUE}~/.config/karabiner/karabiner.json${NC}"
fi

echo -e "${BLUE}🗑️  Removing dotfiles...${NC}"

# Remove zsh config files
configs=(".zshenv" ".zprofile" ".zshrc")
for config in "${configs[@]}"; do
	if [[ -e "$HOME/$config" ]]; then
		echo -e "   Removing ${YELLOW}$HOME/$config${NC}"
		rm -f "$HOME/$config"
	fi
done

# Remove zsh config directories
dirs=(".config/zsh" ".config/kitty" ".cache/zsh" ".local/share/zinit")
for dir in "${dirs[@]}"; do
	if [[ -d "$HOME/$dir" ]]; then
		echo -e "   Removing ${YELLOW}$HOME/$dir${NC}"
		rm -rf "$HOME/$dir"
	fi
done

# Remove zsh cache files (both old and new locations)
rm -f "$HOME/.zcompdump"* "$HOME/.zsh_history" 2>/dev/null || true

# macOS specific
if [[ "$(uname)" == "Darwin" ]]; then
	echo -e "${BLUE}🍎 Removing macOS specific files...${NC}"

	if [[ -d "$HOME/sh-script" ]]; then
		echo -e "   Removing ${YELLOW}$HOME/sh-script${NC}"
		rm -rf "$HOME/sh-script"
	fi

	if [[ -d "$HOME/.hammerspoon" ]]; then
		echo -e "   Removing ${YELLOW}$HOME/.hammerspoon${NC}"
		rm -rf "$HOME/.hammerspoon"
	fi

	if [[ -f "$HOME/.config/karabiner/karabiner.json" ]]; then
		echo -e "   Removing ${YELLOW}$HOME/.config/karabiner/karabiner.json${NC}"
		rm -f "$HOME/.config/karabiner/karabiner.json"
	fi
fi

echo ""
echo -e "${GREEN}✅ Dotfiles uninstalled successfully!${NC}"
echo -e "${GREEN}🎉 Uninstall complete! Please restart your terminal.${NC}"
