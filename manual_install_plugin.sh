#!/bin/bash
# Exit script if any command fails
set -e

# Define color variables for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting script...${NC}"

# Define temporary directory path and ensure it is cleaned up
TMP_DIR="/tmp/dotfiles"
rm -rf "$TMP_DIR"

# Clone repository into temporary directory
echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR"
echo -e "${GREEN}✔️ Repository cloned.${NC}"

# Remove old configuration files from the user's home directory, if they exist
echo -e "${YELLOW}🔍 Checking and removing old configuration files if they exist...${NC}"
declare -a FILES_TO_REMOVE=(
    "$HOME/.zprofile"
    "$HOME/.zshrc"
    "$HOME/.config/zsh"
    "$HOME/.config/kitty"
    "$HOME/powerlevel10k"
    "$HOME/clipboard.zsh"
    "$HOME/completion.zsh"
    "$HOME/grep.zsh"
    "$HOME/key-bindings.zsh"
    "$HOME/history.zsh"
    "$HOME/theme-and-appearance.zsh"
    "$HOME/git.zsh"
    "$HOME/plugin"
    "$HOME/fast-syntax-highlighting"
    "$HOME/zsh-autosuggestions"
    "$HOME/zsh-completions"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -e "$file" ]]; then
        rm -rf "$file" && echo -e "${RED}🗑️ Removing old $file...${NC}"
    
    fi
done
echo -e "${GREEN}🧹 Old configuration files removed.${NC}"

# 复制新的文件到当前用户的家目录
echo -e "${YELLOW}📋 Copying new configuration files to $HOME...${NC}"
# cp "$TMP_DIR/.zprofile" "$HOME/.zprofile"
cp "$TMP_DIR/.zshrc" "$HOME/.zshrc"
cp -r "$TMP_DIR/.config" "$HOME/.config"
cp -r "$TMP_DIR/plugin.zip" "$HOME"
# 在文件中添加以下代码
if [[ "$OSTYPE" == "darwin"* ]]; then
    # 仅在 macOS 上拷贝
    cp -r "$TMP_DIR/sh-script/" "$HOME/sh-script/"
fi
echo -e "${GREEN}✔️ New configuration files copied.${NC}"

# Navigate to home directory and unzip plugin archive
cd $HOME
unzip -o plugin.zip
rm plugin.zip  # Clean up the original zip file

# Comment out existing lines and add new configuration to .zshrc
sed -i -e 's|^source "\$ZPLUGINDIR/colorful_print.zsh"|# &|' \
           -e 's|^source "\$ZPLUGINDIR/homebrew.zsh"|# &|' \
           -e 's|^source "\$ZPLUGINDIR/zinit.zsh"|# &|' ~/.zshrc

# Append additional configuration to .zshrc
{
echo '# Adding Zsh configurations'
echo 'source $HOME/clipboard.zsh'
echo 'source $HOME/completion.zsh'
echo 'source $HOME/grep.zsh'
echo 'source $HOME/key-bindings.zsh'
echo 'source $HOME/directories.zsh'
echo 'source $HOME/history.zsh'
echo 'source $HOME/theme-and-appearance.zsh'
echo 'source $HOME/git.zsh'
echo '# Load zsh-autosuggestions'
echo 'source $HOME/zsh-autosuggestions/zsh-autosuggestions.zsh'
echo '# Load fast-syntax-highlighting'
echo 'source $HOME/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh'
echo '# Add zsh-completions to fpath'
echo 'fpath=($HOME/zsh-completions/src $fpath)'
echo ''
echo '# Remove old zcompdump and regenerate it'
echo 'rm -f $HOME/.zcompdump; compinit'
echo "# 1.Powerlevel10k's instant prompt cache file, used to speed up startup"
echo "if [[ -r \"\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh\" ]]; then"
echo "  source \"\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh\""
echo "fi"
echo ''
echo '# 2.Load Powerlevel10k theme'
echo 'source $HOME/powerlevel10k/powerlevel10k.zsh-theme'
echo ''
echo "# 3.Load p10k theme configuration file"
echo "[[ ! -f $HOME/.config/zsh/.p10k.zsh ]] || source $HOME/.config/zsh/.p10k.zsh"
} >> $HOME/.zshrc

# Clean up temporary directory
echo -e "${YELLOW}🧼 Cleaning up temporary files...${NC}"
rm -rf "$TMP_DIR"
echo -e "${GREEN}✔️ Temporary files removed.${NC}"

echo -e "${GREEN}✅ Script completed successfully. Files have been successfully copied to the user's home"
