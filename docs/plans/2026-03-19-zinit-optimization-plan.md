# Zinit 插件加载优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 优化 zinit.zsh 的插件加载策略——显式排序 turbo 插件、移除无用 OMZ 组件、修正 widget 包装顺序。

**Architecture:** 单文件重构 `.config/zsh/plugins/zinit.zsh`。修改 `_ice` 辅助函数支持自定义 `wait` 值，移除 3 个 OMZ snippet 并内联必要功能，用 `wait'0a'`-`wait'0d'` 显式排序所有 turbo 插件，将 fzf-tab 的 zstyle 配置移入 `atload`。

**Tech Stack:** Zsh, Zinit plugin manager

**Design doc:** `docs/plans/2026-03-19-zinit-optimization-design.md`

---

### Task 1: 修改 `_ice` 辅助函数

**Files:**
- Modify: `.config/zsh/plugins/zinit.zsh:8-16`

**Step 1: 修改 `_ice` 函数**

将硬编码的 `wait` 移除，改为由调用方传入。同步模式下过滤掉 `wait*` 参数：

```zsh
# 异步加载控制函数
# ZINIT_SYNC=1 时同步加载（安装脚本用），否则使用 turbo 模式
_ice() {
	if [[ -n "$ZINIT_SYNC" ]]; then
		zinit ice depth=1 "${@:#wait*}"  # 同步模式：移除 wait 参数，其余保留
	else
		zinit ice lucid depth=1 "$@"  # turbo 模式：wait 值由调用方指定
	fi
}
```

关键变化：
- turbo 分支不再硬编码 `wait`，调用方必须显式传入 `wait'0a'` 等
- 同步分支用 `${@:#wait*}` 过滤掉 wait 参数（glob 匹配移除以 `wait` 开头的元素）
- `lucid` 和 `depth=1` 保留

**Step 2: 验证语法**

Run: `zsh -n ~/.config/zsh/plugins/zinit.zsh`
Expected: 无输出（无语法错误）

**Step 3: Commit**

```bash
git add .config/zsh/plugins/zinit.zsh
git commit -m "refactor(zinit): _ice 函数不再硬编码 wait，由调用方显式传入"
```

---

### Task 2: 移除 OMZ snippets，内联上下箭头绑定

**Files:**
- Modify: `.config/zsh/plugins/zinit.zsh:47-66`

**Step 1: 删除 OMZ snippets 和相关注释**

删除以下行（当前第 47-66 行）：

```zsh
# 删除这些 >>>
# General options for all plugins
HYPHEN_INSENSITIVE='true'
COMPLETION_WAITING_DOTS='true'

# OMZ 精简插件配置（移除 clipboard/grep/completion/history/theme/colored-man-pages）
# 保留：key-bindings, directories, git

# key-bindings: 键盘快捷键
_ice
zinit snippet OMZL::key-bindings.zsh

# directories: 目录导航（d / cd 增强）
_ice atload'setopt no_auto_cd'
zinit snippet OMZL::directories.zsh

# git: git 别名和函数
_ice
zinit snippet OMZL::git.zsh
_ice
zinit snippet OMZP::git/git.plugin.zsh
# <<< 删除到这里
```

**Step 2: 在原位置替换为内联的上下箭头绑定 + git plugin**

```zsh
# 上下箭头：按已输入前缀搜索历史（替代 OMZL::key-bindings.zsh）
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
```

注意：`OMZP::git/git.plugin.zsh` 不删除，移到 Task 4 的 turbo 区。

**Step 3: 验证语法**

Run: `zsh -n ~/.config/zsh/plugins/zinit.zsh`
Expected: 无输出

**Step 4: Commit**

```bash
git add .config/zsh/plugins/zinit.zsh
git commit -m "refactor(zinit): 移除 3 个 OMZ snippet，内联上下箭头前缀历史搜索"
```

---

### Task 3: fzf-tab 的 zstyle 配置移入 atload

**Files:**
- Modify: `.config/zsh/plugins/zinit.zsh`（fzf-tab 加载区域和 zstyle 区域）

**Step 1: 将 zstyle 配置移入 fzf-tab 的 atload**

当前 fzf-tab 只有 `atinit`（compinit 逻辑），zstyle 在外部同步执行。将 zstyle 移入 `atload`，使其在 fzf-tab 加载后才执行：

```zsh
_ice wait'0b' atinit'
    autoload -Uz compinit
    local zcd="${ZSH_COMPDUMP:-$HOME/.cache/zsh/.zcompdump}"
    local need_update=0
    if [[ -f "$zcd" ]]; then
        for dir in ${(s.:.)FPATH}; do
            [[ -d "$dir" && "$dir" -nt "$zcd" ]] && { need_update=1; break }
        done
    fi
    if [[ ! -f "$zcd" || $need_update -eq 1 ]]; then
        compinit -d "$zcd"
    else
        compinit -C -d "$zcd"
    fi
    zicdreplay
' atload'
    # fzf-tab 补全样式配置
    zstyle ":fzf-tab:complete:_zlua:*" query-string input
    zstyle ":fzf-tab:complete:kill:argument-rest" fzf-preview "ps -p \$word -o comm= 2>/dev/null"
    zstyle ":fzf-tab:complete:kill:argument-rest" fzf-flags "--preview-window=down:15:wrap"
    zstyle ":fzf-tab:complete:kill:*" popup-pad 0 3
    zstyle ":fzf-tab:complete:cd:*" fzf-preview "eza -1 --color=always \$realpath"
    zstyle ":fzf-tab:complete:cd:*" popup-pad 30 0
    zstyle ":fzf-tab:complete:code:*" fzf-preview "eza -1 --color=always \$realpath"
    zstyle ":fzf-tab:complete:code:*" popup-pad 30 0
    zstyle ":fzf-tab:*" fzf-flags --color=bg+:23
    zstyle ":fzf-tab:*" switch-group "<" ">"
'
zinit light Aloxaf/fzf-tab
```

注意：atload 中的 `$word` 和 `$realpath` 需要转义为 `\$word`、`\$realpath`（它们是 fzf-tab 运行时变量，不应在 atload 解析时展开）。单引号内的 `'` 不需要转义，但整个 atload 用单引号包裹时内部的单引号需要用双引号替代。

**Step 2: 删除原来的独立 zstyle 块**

删除原第 105-115 行的 `# 配置 fzf-tab` 区块和第 117-135 行的 Fedora 补全兼容性修复区块。

Fedora 补全兼容性的 `zstyle ':completion:*' matcher-list ...` 也移入 fzf-tab 的 `atinit`（compinit 之前）：

```zsh
_ice wait'0b' atinit'
    # 补全 matcher：移除 -_ 等价性，只保留大小写不敏感（修复 Fedora 兼容性）
    zstyle ":completion:*" matcher-list "m:{[:lower:][:upper:]}={[:upper:][:lower:]}" "r:|=*" "l:|=* r:|=*"
    autoload -Uz compinit
    ...
```

**Step 3: 验证语法**

Run: `zsh -n ~/.config/zsh/plugins/zinit.zsh`
Expected: 无输出

**Step 4: Commit**

```bash
git add .config/zsh/plugins/zinit.zsh
git commit -m "refactor(zinit): fzf-tab zstyle 和 matcher-list 移入 atinit/atload，不再阻塞启动"
```

---

### Task 4: 显式排序所有 turbo 插件

**Files:**
- Modify: `.config/zsh/plugins/zinit.zsh`（turbo 区域整体重排）

**Step 1: 重写 turbo 加载区**

将文件中 p10k 配置和内联设置之后的所有插件加载语句替换为以下结构：

```zsh
# ============================================
# Turbo 异步加载（prompt 显示后按优先级加载）
# ============================================
# 排序约束：
#   0a: 补全定义 → 0b: compinit + fzf-tab → 0c: 功能插件 → 0d: autosuggestions
#   F-Sy-H(0c) 必须在 autosuggestions(0d) 之前：
#     F-Sy-H source 时绑定 widget 一次；autosuggestions 后加载直接包在外层，
#     产生干净的 autosuggest → fsh → 原始 调用链，无冗余包装层。

# ── wait'0a'：补全定义层（为 compinit 准备 FPATH）──

_ice wait'0a' as"completion"
zinit snippet "$HOME/.config/zsh/fzf/_fzf"

_ice wait'0a' blockf  # blockf: 阻止插件修改 FPATH（由 zinit 统一管理）
zinit light zsh-users/zsh-completions

# ── wait'0b'：补全系统激活 ──

_ice wait'0b' atinit'
    # 补全 matcher：移除 -_ 等价性，只保留大小写不敏感（修复 Fedora 兼容性）
    zstyle ":completion:*" matcher-list "m:{[:lower:][:upper:]}={[:upper:][:lower:]}" "r:|=*" "l:|=* r:|=*"
    autoload -Uz compinit
    local zcd="${ZSH_COMPDUMP:-$HOME/.cache/zsh/.zcompdump}"
    local need_update=0
    if [[ -f "$zcd" ]]; then
        for dir in ${(s.:.)FPATH}; do
            [[ -d "$dir" && "$dir" -nt "$zcd" ]] && { need_update=1; break }
        done
    fi
    if [[ ! -f "$zcd" || $need_update -eq 1 ]]; then
        compinit -d "$zcd"
    else
        compinit -C -d "$zcd"
    fi
    zicdreplay
' atload'
    zstyle ":fzf-tab:complete:_zlua:*" query-string input
    zstyle ":fzf-tab:complete:kill:argument-rest" fzf-preview "ps -p \$word -o comm= 2>/dev/null"
    zstyle ":fzf-tab:complete:kill:argument-rest" fzf-flags "--preview-window=down:15:wrap"
    zstyle ":fzf-tab:complete:kill:*" popup-pad 0 3
    zstyle ":fzf-tab:complete:cd:*" fzf-preview "eza -1 --color=always \$realpath"
    zstyle ":fzf-tab:complete:cd:*" popup-pad 30 0
    zstyle ":fzf-tab:complete:code:*" fzf-preview "eza -1 --color=always \$realpath"
    zstyle ":fzf-tab:complete:code:*" popup-pad 30 0
    zstyle ":fzf-tab:*" fzf-flags --color=bg+:23
    zstyle ":fzf-tab:*" switch-group "<" ">"
'
zinit light Aloxaf/fzf-tab

# ── wait'0c'：功能插件层 ──

_ice wait'0c'
zinit snippet OMZP::git/git.plugin.zsh

_ice wait'0c' atload'FAST_HIGHLIGHT[chroma-which]="→chroma/-precommand.ch"'
zinit light zdharma-continuum/fast-syntax-highlighting

# ── wait'0d'：自动建议（最外层 widget 包装）──

_ice wait'0d' atload'!_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions
```

**Step 2: 验证语法**

Run: `zsh -n ~/.config/zsh/plugins/zinit.zsh`
Expected: 无输出

**Step 3: Commit**

```bash
git add .config/zsh/plugins/zinit.zsh
git commit -m "refactor(zinit): 用 wait'0a'-'0d' 显式排序 turbo 插件，修正 widget 包装顺序"
```

---

### Task 5: 端到端验证

**Step 1: 语法检查**

Run: `zsh -n ~/.config/zsh/plugins/zinit.zsh`
Expected: 无输出

**Step 2: 同步模式测试（模拟 install.sh）**

Run: `ZINIT_SYNC=1 zsh -c 'source ~/.config/zsh/plugins/zinit.zsh; echo "sync ok"'`
Expected: 输出 `sync ok`（安装模式下所有插件同步加载，不报错）

**Step 3: 启动时间基准测试**

Run: `for i in 1 2 3 4 5; do /usr/bin/time zsh -i -c exit 2>&1; done`
Expected: 启动时间不高于优化前（基准约 50-60ms）

**Step 4: 交互式功能验证**

打开新终端，手动验证：
1. 上下箭头前缀搜索：输入 `git` 按 ↑，应只显示 git 开头的历史
2. Tab 补全：输入 `cd ~/` 按 Tab，应弹出 fzf-tab 预览
3. 语法高亮：输入 `echo hello`，`echo` 应有颜色
4. 自动建议：输入 `git`，应出现灰色建议
5. Git 别名：输入 `gst`，应等价于 `git status`

**Step 5: 最终 commit（如有修复）**

```bash
git add .config/zsh/plugins/zinit.zsh
git commit -m "fix(zinit): 修复验证中发现的问题"
```
