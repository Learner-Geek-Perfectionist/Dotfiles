# Zinit 插件加载优化设计

## 目标

优化 `.config/zsh/plugins/zinit.zsh` 的插件加载策略，确保：

1. 显式控制 turbo 模式下的加载顺序（消除隐式 `wait"0"` 的不确定性）
2. 移除无用的 OMZ 组件，减少加载开销
3. 产生最干净的 ZLE widget 调用链

## 当前问题

### 1. 所有 turbo 插件共享隐式 `wait"0"`

`_ice()` 函数硬编码 `wait`（等价于 `wait'0'`），所有插件拿到相同优先级，加载顺序依赖源码位置，不可靠。

### 2. 三个无用的 OMZ snippet

| Snippet | 问题 |
|---------|------|
| `OMZL::key-bindings.zsh` | 只需要上下箭头前缀历史搜索（5 行），其余 60+ 行不需要 |
| `OMZL::directories.zsh` | `auto_cd` 被立即覆盖为 `no_auto_cd`，ls 别名与 eza 冲突 |
| `OMZL::git.zsh` | 提供 OMZ 主题用的 git prompt 函数，p10k 不使用 |

### 3. autosuggestions 与 F-Sy-H 加载顺序错误

当前顺序：autosuggestions 先 → F-Sy-H 后。

源码分析结论：

- F-Sy-H 在 source 时绑定 widget 一次（`_zsh_highlight_bind_widgets`，不再重绑定）
- autosuggestions 在每次 precmd 通过 `_zsh_autosuggest_start` 重新绑定

当前顺序产生的调用链：

```
autosuggest_bound_2 → fsh_widget → autosuggest_bound_1(死代码) → 原始 widget
```

`autosuggest_bound_1` 是冗余层，每次按键多走一遍 modify 逻辑。

### 4. fzf-tab 的 zstyle 配置在 turbo 外同步执行

fzf-tab 通过 turbo 延迟加载，但其 zstyle 配置在同步区执行，浪费启动时间。

### 5. fzf 补全 snippet 未使用 turbo

`zinit ice as"completion"` 没有通过 `_ice` 调用，同步加载。

## 设计

### 同步加载区（启动关键路径）

按执行顺序：

```
1. zinit 本身                    ← source zinit.zsh（不可延迟）
2. p10k instant prompt           ← 从缓存文件加载
3. p10k 主题 + 配置              ← zinit light（同步）
4. 上下箭头前缀历史搜索           ← 内联 5 行（替代 OMZL::key-bindings.zsh）
5. history setopt                ← 内联（已有）
6. eza alias                     ← 内联（已有）
```

内联的上下箭头绑定：

```zsh
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
```

### Turbo 异步加载区

使用字母后缀显式排序（zinit 在同一 wait 值内按字母序调度）：

```
wait'0a' ─ 补全定义层（为 compinit 准备数据）
  ├── fzf 补全 snippet (as"completion")
  └── zsh-completions (blockf)

wait'0b' ─ 补全系统激活
  └── fzf-tab
      atinit: compinit + zicdreplay
      atload: 全部 zstyle 配置（从同步区移入）

wait'0c' ─ 功能插件层
  ├── OMZP::git/git.plugin.zsh
  └── fast-syntax-highlighting

wait'0d' ─ 自动建议（最外层 widget 包装）
  └── zsh-autosuggestions (atload: _zsh_autosuggest_start)
```

#### 排序约束依据

| 约束 | 依据 |
|------|------|
| 0a < 0b | compinit 需要扫描 FPATH，补全定义必须先就位 |
| 0b < 0c, 0d | fzf-tab 必须在 autosuggestions/F-Sy-H 之前，因为后者会 wrap widget |
| 0c < 0d (F-Sy-H < autosuggestions) | F-Sy-H source 时绑定一次不再重绑定；autosuggestions 后加载直接包在外层，产生干净的 `autosuggest → fsh → 原始` 调用链，无冗余层 |

### 移除项

| 移除 | 替代 |
|------|------|
| `OMZL::key-bindings.zsh` snippet | 内联 5 行上下箭头绑定 |
| `OMZL::directories.zsh` snippet | 完全删除（含 `setopt no_auto_cd`） |
| `OMZL::git.zsh` snippet | 完全删除（p10k 不需要） |
| 第 149 行错误注释 | 更新为正确的加载顺序说明 |

### `_ice` 辅助函数调整

当前 `_ice` 硬编码 `wait`（隐式 `wait'0'`）。需要支持传入自定义 wait 值：

```zsh
_ice() {
    if [[ -n "$ZINIT_SYNC" ]]; then
        zinit ice depth=1 "${@:#wait*}"  # 同步模式下移除 wait 参数
    else
        zinit ice lucid depth=1 "$@"
    fi
}

# 使用示例
_ice wait'0a' blockf
zinit light zsh-users/zsh-completions
```
