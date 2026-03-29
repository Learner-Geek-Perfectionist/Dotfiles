# ssh-keychain-unlock: SSH 会话中自动解锁 macOS login keychain
# 依赖: MACOS_KEYCHAIN_PASS 变量（由 age-tokens.zsh 从加密文件加载）

if [[ -n "$SSH_CONNECTION" && "$OSTYPE" == darwin* && -n "$MACOS_KEYCHAIN_PASS" ]]; then
  if security unlock-keychain -p "$MACOS_KEYCHAIN_PASS" \
       ~/Library/Keychains/login.keychain-db 2>/dev/null; then
    print -P "%F{green}[keychain]%f login keychain 已自动解锁"
  else
    print -P "%F{yellow}[keychain]%f 解锁失败，请检查 MACOS_KEYCHAIN_PASS" >&2
  fi
  unset MACOS_KEYCHAIN_PASS
fi
