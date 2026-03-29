#!/bin/bash
# PostToolUse hook: 编辑 Dotfiles 仓库配置文件后自动同步到系统部署路径
# 仅处理简单复制场景；direnv(需 sed)、claude settings(需 jq merge) 等特殊部署跳过

set -euo pipefail

# 先缓存 stdin 再提取（与 check-file-deps.sh 风格统一）
input="$(cat)"
FILE_PATH="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || true
[ -z "$FILE_PATH" ] && exit 0

REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO" ] && exit 0

# 必须是仓库内的文件
case "$FILE_PATH" in "$REPO"/*) ;; *) exit 0 ;; esac

REL="${FILE_PATH#"$REPO"/}"

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
    .config/Code/User/*|.config/Cursor/User/*)
        # 编辑器配置：同步到 ~/.config 和 Library（macOS）
        mkdir -p "$(dirname "$HOME/$REL")"
        cp -f "$FILE_PATH" "$HOME/$REL"
        # macOS: 同步到 Library/Application Support
        if [[ "$(uname)" == "Darwin" ]]; then
            lib_rel="${REL/.config/Library/Application Support}"
            mkdir -p "$(dirname "$HOME/$lib_rel")"
            cp -f "$FILE_PATH" "$HOME/$lib_rel"
        fi
        # 镜像同步到对端编辑器（Code <-> Cursor）
        mirror_rel=""
        case "$REL" in
            .config/Code/*) mirror_rel="${REL/Code/Cursor}" ;;
            .config/Cursor/*) mirror_rel="${REL/Cursor/Code}" ;;
        esac
        if [[ -n "$mirror_rel" && -f "$REPO/$mirror_rel" ]]; then
            cp -f "$FILE_PATH" "$REPO/$mirror_rel"
            cp -f "$FILE_PATH" "$HOME/$mirror_rel"
            if [[ "$(uname)" == "Darwin" ]]; then
                mirror_lib="${mirror_rel/.config/Library/Application Support}"
                mkdir -p "$(dirname "$HOME/$mirror_lib")"
                cp -f "$FILE_PATH" "$HOME/$mirror_lib"
            fi
        fi
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[sync-dotfile] auto-synced: %s -> all editor copies"}}\n' "$REL"
        ;;
    Library/Application\ Support/Code/User/*|Library/Application\ Support/Cursor/User/*)
        # Library 版本：同步到 .config 和对端
        config_rel="${REL/Library\/Application Support/.config}"
        mkdir -p "$(dirname "$HOME/$config_rel")"
        cp -f "$FILE_PATH" "$HOME/$config_rel"
        cp -f "$FILE_PATH" "$REPO/$config_rel"
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[sync-dotfile] auto-synced: %s -> %s"}}\n' "$REL" "$config_rel"
        ;;
esac
