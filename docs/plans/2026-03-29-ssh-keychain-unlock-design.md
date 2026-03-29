# SSH 会话自动解锁 macOS Keychain

## 问题

从另一台 macOS 通过 SSH 连入本机使用 Claude Code CLI 时，每次都需要手动执行 `security unlock-keychain ~/Library/Keychains/login.keychain-db` 并输入密码。

**根因：** Claude Code（非 API 模式）将 OAuth 凭证存储在 macOS `login.keychain-db` 中（条目：`Claude Code-credentials`）。SSH 创建的安全会话与 GUI 会话隔离，无法继承 Keychain 的解锁状态。

## 方案

集成到现有 age-tokens 加密体系，新增 zsh 插件在 SSH 会话启动时自动解锁。

## 变更清单

### 1. 新建插件 `.config/zsh/plugins/ssh-keychain-unlock.zsh`

```zsh
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
```

设计要点：
- 三重守卫：`SSH_CONNECTION` + `darwin*` + 变量存在
- 解锁后立即 `unset`，密码不残留在环境变量中
- 成功/失败均有终端提示

### 2. 修改 `.zshrc`

在 `age-tokens.zsh` source 之后（第 107 行后）插入：

```zsh
[[ -f "${HOME}/.config/zsh/plugins/ssh-keychain-unlock.zsh" ]] && source "${HOME}/.config/zsh/plugins/ssh-keychain-unlock.zsh"
```

加载顺序：`age-tokens.zsh`（export 变量）→ `ssh-keychain-unlock.zsh`（消费变量并 unset）

### 3. 用户手动操作（一次性）

运行 `edit-tokens`，在加密文件中添加：

```bash
export MACOS_KEYCHAIN_PASS="macOS登录密码"
```

## 安全分析

- **存储态：** 密码由 age 使用 SSH 公钥加密，存储在 `~/.tokens.sh.age`
- **运行态：** 密码在 shell 启动的几毫秒内解密 → export → 读取 → 解锁 → unset 销毁
- **`-p` 参数：** 密码短暂出现在进程参数中（`ps` 可见），但命令瞬间完成且仅限本机用户进程可见
- **不涉及：** install.sh / uninstall.sh（插件文件由 install_dotfiles.sh symlink 部署覆盖）

## 密码生命周期

```
~/.tokens.sh.age (age 加密存储)
  → age -d (SSH 私钥解密)
    → eval "export MACOS_KEYCHAIN_PASS=..." (进入环境变量)
      → security unlock-keychain -p (使用)
        → unset MACOS_KEYCHAIN_PASS (销毁)
```
