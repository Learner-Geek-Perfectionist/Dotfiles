#!/bin/bash
# PostToolUse hook: 编辑 Dotfiles 仓库配置文件后自动同步到系统部署路径
# 仅处理简单复制场景；direnv(需 sed)、claude settings(需 jq merge) 等特殊部署跳过

set -eo pipefail

FILE_PATH=$(jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO" ] && exit 0

# 必须是仓库内的文件
case "$FILE_PATH" in "$REPO"/*) ;; *) exit 0 ;; esac

REL="${FILE_PATH#$REPO/}"

# 只同步已知的复制部署路径（与 install_dotfiles.sh 对应）
case "$REL" in
    .config/kitty/*|\
    .config/karabiner/*|\
    .config/zsh/*|\
    .config/ripgrep/*|\
    .hammerspoon/*|\
    .zshrc|.zprofile|.zshenv|.envrc|\
    .gitconfig|.gitignore|\
    sh-script/*)
        mkdir -p "$(dirname "$HOME/$REL")"
        cp -f "$FILE_PATH" "$HOME/$REL"
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[sync-dotfile] auto-synced: %s -> ~/%s"}}\n' "$REL" "$REL"
        ;;
    .ssh/config)
        # SSH config 使用 Include 浅合并，部署到 config.d/ 而非直接覆盖
        mkdir -p "$HOME/.ssh/config.d"
        cp -f "$FILE_PATH" "$HOME/.ssh/config.d/00-dotfiles"
        chmod 600 "$HOME/.ssh/config.d/00-dotfiles"
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[sync-dotfile] auto-synced: .ssh/config -> ~/.ssh/config.d/00-dotfiles"}}\n'
        ;;
esac
