# SSH Keychain Auto-Unlock Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** SSH 进入本机 macOS 时自动解锁 login keychain，使 Claude Code CLI 无需手动输密码即可读取 OAuth 凭证。

**Architecture:** 新建 zsh 插件检测 SSH 会话并消费 age-tokens 提供的加密密码变量来解锁 Keychain，解锁后立即销毁密码变量。

**Tech Stack:** zsh, macOS security command, age encryption (existing)

---

### Task 1: 创建 ssh-keychain-unlock.zsh 插件

**Files:**
- Create: `.config/zsh/plugins/ssh-keychain-unlock.zsh`

**Step 1: 创建插件文件**

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

**Step 2: 验证语法**

Run: `zsh -n .config/zsh/plugins/ssh-keychain-unlock.zsh`
Expected: 无输出（语法正确）

**Step 3: 验证守卫条件（本地不触发）**

Run: `zsh -c 'source .config/zsh/plugins/ssh-keychain-unlock.zsh && echo "no output = correct"'`
Expected: 输出 `no output = correct`（因为本地没有 `$SSH_CONNECTION`，插件直接跳过）

---

### Task 2: 修改 .zshrc 加载新插件

**Files:**
- Modify: `.zshrc:107` (在 age-tokens.zsh source 之后)

**Step 1: 在第 107 行后插入 source 语句**

在 `.zshrc` 的 `age-tokens.zsh` source 行之后、`# SSH Agent (keychain)` 注释之前插入：

```zsh
# macOS Keychain 自动解锁（SSH 会话，依赖 age-tokens 提供 MACOS_KEYCHAIN_PASS）
[[ -f "${HOME}/.config/zsh/plugins/ssh-keychain-unlock.zsh" ]] && source "${HOME}/.config/zsh/plugins/ssh-keychain-unlock.zsh"
```

**Step 2: 验证 .zshrc 语法**

Run: `zsh -n .zshrc`
Expected: 无输出（语法正确）

---

### Task 3: 同步部署 + 提交

**Step 1: 复制插件到系统部署路径**

Run: `cp .config/zsh/plugins/ssh-keychain-unlock.zsh ~/.config/zsh/plugins/ssh-keychain-unlock.zsh`

注意：根据 CLAUDE.md 规则 11，配置文件采用复制部署时，修改仓库源文件后必须同步到系统部署路径。

**Step 2: 同步 .zshrc 到 HOME**

Run: `cp .zshrc ~/.zshrc`

**Step 3: Commit**

```bash
git add .config/zsh/plugins/ssh-keychain-unlock.zsh .zshrc
git commit -m "feat: SSH 会话自动解锁 macOS Keychain（集成 age-tokens）"
```

---

### Task 4: 用户手动操作提示（不在计划执行范围）

用户需要自行完成一次性操作：

1. 运行 `edit-tokens`
2. 添加 `export MACOS_KEYCHAIN_PASS="macOS登录密码"`
3. 保存退出
4. 从另一台 Mac SSH 进入验证：应看到 `[keychain] login keychain 已自动解锁`
