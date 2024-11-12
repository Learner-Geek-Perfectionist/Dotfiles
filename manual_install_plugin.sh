#!/bin/bash
# 设置脚本在遇到错误时退出
set -e

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting script...${NC}"

rm -rf /tmp/dotfiles
# 定义临时目录路径
TMP_DIR="/tmp/dotfiles"

# 浅克隆仓库到临时目录
echo -e "${YELLOW}📥 Cloning repository into $TMP_DIR...${NC}"
git clone --depth 1 https://github.com/Learner-Geek-Perfectionist/Dotfiles "$TMP_DIR"
echo -e "${GREEN}✔️ Repository cloned.${NC}"

# 删除当前用户家目录中的旧文件和目录（如果存在）
echo -e "${YELLOW}🔍 Checking and removing old configuration files if they exist...${NC}"
[ -f "$HOMEE/.zprofile" ] && echo -e "${RED}🗑️ Removing old .zprofile...${NC}" && rm "$HOMEE/.zprofile"
[ -f "$HOMEE/.zshrc" ] && echo -e "${RED}🗑️ Removing old .zshrc...${NC}" && rm "$HOMEE/.zshrc"
[ -d "$HOMEE/.config" ] && echo -e "${RED}🗑️ Removing old .config directory...${NC}" && rm -rf "$HOMEE/.config"
[ -d "$HOMEE/powerlevel10k" ] && echo -e "${RED}🗑️ Removing old powerlevel10k directory...${NC}" && rm -rf "$HOMEE/powerlevel10k"
[ -d "$HOMEE/fast-syntax-highlighting" ] && echo -e "${RED}🗑️ Removing old fast-syntax-highlighting directory...${NC}" && rm -rf "$HOMEE/fast-syntax-highlighting/"
[ -d "$HOMEE/zsh-autosuggestions" ] && echo -e "${RED}🗑️ Removing old zsh-autosuggestions directory...${NC}" && rm -rf "$HOMEE/zsh-autosuggestions/"
[ -d "$HOMEE/zsh-completions" ] && echo -e "${RED}🗑️ Removing old zsh-completions directory...${NC}" && rm -rf "$HOMEE/zsh-completions/"
echo -e "${GREEN}🧹 Old configuration files removed.${NC}"

# 复制新的文件到当前用户的家目录
echo -e "${YELLOW}📋 Copying new configuration files to $HOMEE...${NC}"
# cp "$TMP_DIR/.zprofile" "$HOMEE/.zprofile"
# cp "$TMP_DIR/.zshrc" "$HOMEE/.zshrc"
cp -r "$TMP_DIR/.config" "$HOMEE/.config"
cp -r "$TMP_DIR/plugin.zip" "$HOMEE"
# 在文件中添加以下代码
if [[ "$OSTYPE" == "darwin"* ]]; then
    # 仅在 macOS 上拷贝
    cp -r "$TMP_DIR/sh-script/" "$HOMEE/sh-script/"
fi
echo -e "${GREEN}✔️ New configuration files copied.${NC}"


# 清理临时目录
echo -e "${YELLOW}🧼 Cleaning up temporary files...${NC}"
rm -rf "$TMP_DIR"
echo -e "${GREEN}✔️ Temporary files removed.${NC}"

echo -e "${GREEN}✅ Script completed successfully. Files have been successfully copied to the user's home directory.${NC}"

cd $HOME
unzip plugin.zip

{
echo '# Load Powerlevel10k theme'
echo 'source $HOME/powerlevel10k/powerlevel10k.zsh-theme'
echo ''
echo '# Load fast-syntax-highlighting'
echo 'source $HOME/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh'
echo ''
echo '# Load zsh-autosuggestions'
echo 'source $HOME/zsh-autosuggestions/zsh-autosuggestions.zsh'
echo ''
echo '# Add zsh-completions to fpath'
echo 'fpath=($HOME/zsh-completions/src $fpath)'
echo ''
echo '# Remove old zcompdump and regenerate it'
echo 'rm -f $HOME/.zcompdump; compinit'
echo "# 1.Powerlevel10k 的 instant prompt 的缓存文件，用于加速启动"
echo "if [[ -r \"\${XDG_CACHE_HOME:-\$HOMEE/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh\" ]]; then"
echo "  source \"\${XDG_CACHE_HOME:-\$HOMEE/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh\""
echo "fi"
echo ""
echo "# 2.加载 p10k 主题"
echo "zinit light romkatv/powerlevel10k"
echo ""
echo "# 3.加载 p10k 主题的配置文件"
echo "[[ ! -f $HOME/.config/zsh/.p10k.zsh ]] || source $HOME/.config/zsh/.p10k.zsh"
} >> $HOME/.zshrc
