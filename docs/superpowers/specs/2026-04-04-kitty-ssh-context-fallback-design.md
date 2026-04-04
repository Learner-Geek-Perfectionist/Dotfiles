# Kitty SSH 上下文继承与超时回退设计

> 日期: 2026-04-04
> 状态: 已确认
> 适用仓库: `~/Dotfiles`

## 目标

在保留 `Cmd + E` / `Cmd + N` “继承当前上下文”语义的前提下，修复当前 SSH 场景下新 tab / window 容易卡住的问题，满足以下结果：

1. `Cmd + E` / `Cmd + N` 继续由 `Hammerspoon` 抢先拦截，避免 `Codex`、`Claude Code` 等 TUI 在启动或运行期间吞掉按键。
2. 当前窗口是本地 shell 时，新 tab / window 继续直接继承本地目录。
3. 当前窗口是 `SSH` shell 时，新 tab / window 继续尽量继承同一远端主机和同一远端目录。
4. 自动继承远端上下文时，最坏等待时间必须有明确上限，不能因为远端主机断联或不可达而无限卡住。
5. 一旦远端继承失败或超时，新 tab / window 必须自动回退到可立即使用的本地 `zsh`。

## 已确认事实

当前仓库里的链路如下：

- [`.hammerspoon/modules/kittyHotkeys.lua`](/Users/ouyangzhaoxin/Dotfiles/.hammerspoon/modules/kittyHotkeys.lua) 在 `Kitty` 前台时通过 `hs.eventtap` 抢先拦截 `Cmd + E` / `Cmd + N`。
- [`.config/kitty/kitty.conf`](/Users/ouyangzhaoxin/Dotfiles/.config/kitty/kitty.conf) 中原生的 `map cmd+e` / `map cmd+n` 已注释掉，说明按键入口已经切到 `Hammerspoon`。
- [`.config/kitty/smart_tab.py`](/Users/ouyangzhaoxin/Dotfiles/.config/kitty/smart_tab.py) 与 [`.config/kitty/smart_window.py`](/Users/ouyangzhaoxin/Dotfiles/.config/kitty/smart_window.py) 只是薄封装，核心策略集中在 [`.config/kitty/ssh_utils.py`](/Users/ouyangzhaoxin/Dotfiles/.config/kitty/ssh_utils.py)。
- 当前 `ssh_utils.py` 在识别到交互式 `ssh` 后，会直接执行 `kitten ssh <destination>; exec zsh -i`。这意味着只要新的 SSH 连接本身卡住，新 tab / window 就会一起卡住。

已确认的 Kitty 上游事实：

- Kitty 的 `shell integration` 会持续上报当前工作目录。
- Kitty 在自定义脚本环境中可使用 `window.cwd_of_child` 获取当前窗口对应的工作目录。
- Kitty 原生支持 `launch --cwd=current` / `--cwd=last_reported`，并在 `ssh kitten` 场景下支持“在断开 SSH 后回落本地 shell”的 `--hold-after-ssh` 语义。

与本设计直接相关的官方参考：

- https://sw.kovidgoyal.net/kitty/launch/
- https://sw.kovidgoyal.net/kitty/kittens/ssh/
- https://sw.kovidgoyal.net/kitty/shell-integration/#clone-shell

## 非目标

以下内容不在本次设计范围内：

1. 不移除 `Hammerspoon` 接管链路，也不把 `Cmd + E` / `Cmd + N` 改回 `kitty.conf` 原生直绑。
2. 不新增远端守护进程、远端状态文件或远端目录缓存服务。
3. 不为“自动 SSH 继承”保留无限等待、密码输入、主机指纹确认等交互路径。
4. 不新增单独的“强制本地”或“强制远端”第二套默认快捷键。
5. 不改变 [`.zshrc`](/Users/ouyangzhaoxin/Dotfiles/.zshrc) 中 `alias ssh='kitten ssh'` 的整体策略。

## 方案对比

### 方案 A：默认只开本地 tab / window

优点：

- 行为最稳，绝不会因为 SSH 重连而卡住。
- 实现最简单。

缺点：

- 不满足“`Cmd + E` / `Cmd + N` 继续继承 SSH 上下文”的目标。
- 会丢掉当前工作流里“一键复制远端会话”的核心价值。

结论：不采用。

### 方案 B：保留当前无限等待的 SSH 自动重连

优点：

- 逻辑最接近现状。
- 在远端主机稳定可达时体验自然。

缺点：

- 远端主机断联、网络异常或 SSH 状态陈旧时仍会卡住。
- 不满足“快速开一个可用 tab”的底线要求。

结论：不采用。

### 方案 C：默认继承当前上下文，但自动 SSH 继承必须带硬超时并回退本地

优点：

- 保留 `Cmd + E` / `Cmd + N` 的原始语义。
- SSH 正常时仍能复用远端主机与目录。
- SSH 异常时最多只损失一个很短的等待窗口，然后自动回到本地可用 shell。

缺点：

- 自动 SSH 继承必须改为非交互式，不能再弹密码或指纹确认流程。
- 依赖 Kitty 提供的 `cwd_of_child` 和 shell integration 元数据；当这些元数据不可用时需要明确降级。

结论：采用。

## 选定设计

### 默认语义

`Cmd + E` / `Cmd + N` 的默认语义保持为“继承当前上下文”：

- 当前是本地 shell：继承本地目录。
- 当前是 SSH shell：优先继承同一远端主机和同一远端目录。

但“继承 SSH 上下文”不再意味着“无限等待 SSH 重连完成”，而是意味着“在固定时间预算内尽量继承，失败就立即回落本地”。

### 本地路径

若源窗口未被识别为交互式 SSH：

1. 继续沿用当前 `Kitty` 远程控制调用链。
2. 继续基于源窗口调用 `launch --cwd=last_reported`。
3. 新 tab / window 直接进入本地 shell，不增加任何额外等待。

### SSH 路径

若源窗口被识别为交互式 SSH：

1. 从源窗口的前台进程中提取 SSH 目标地址，继续沿用现有的 `destination` 识别逻辑。
2. 从源窗口读取 `window.cwd_of_child` 作为当前目录。
3. 仅当同时拿到 `destination` 与非空 `cwd_of_child` 时，才尝试自动继承远端上下文。
4. 自动继承命令必须改为“非交互式 + 有硬超时”的 SSH 尝试。
5. 远端 SSH 成功时，进入相同主机与相同目录。
6. 远端 SSH 失败或超时时，立即回退到本地 `zsh -i`。

### 自动 SSH 继承的硬约束

自动 SSH 继承必须满足以下固定约束：

1. 连接超时固定为 `2` 秒。
2. 连接尝试次数固定为 `1` 次。
3. 整个自动继承过程必须是非交互式的，不能等待密码输入、TOTP、主机指纹确认或其他人工确认。
4. 任何失败都视为可恢复失败，直接回退本地，不弹额外确认框。

这一定义的直接含义是：

- 已经有可复用连接、密钥登录或其他免交互认证时，SSH 继承应当很快成功。
- 需要人工交互才能建立的新 SSH 连接，不再适合作为 `Cmd + E` / `Cmd + N` 的默认路径，而会快速失败并回退本地。

### 元数据不可用时的降级规则

自动 SSH 继承依赖两个输入：

- `destination`
- `window.cwd_of_child`

降级规则固定为：

1. `destination` 缺失：视为本地窗口，直接走本地路径。
2. `destination` 存在但 `cwd_of_child` 为空：不尝试“只继承主机不继承目录”，而是直接回退本地。

这样做的原因是保持语义一致：要么完整继承远端上下文，要么直接给用户一个本地可用 shell，不引入“落到错误目录的半克隆状态”。

## 组件边界

### `Hammerspoon`

[`.hammerspoon/modules/kittyHotkeys.lua`](/Users/ouyangzhaoxin/Dotfiles/.hammerspoon/modules/kittyHotkeys.lua) 保持职责不变：

- 仅负责在 `Kitty` 前台时拦截 `Cmd + E` / `Cmd + N`
- 通过 `kitty @ --to <socket> kitten <script>` 触发后续逻辑

本次不把 SSH 判断或超时逻辑上移到 `Lua` 层。

### `Kitty` 入口脚本

[`.config/kitty/smart_tab.py`](/Users/ouyangzhaoxin/Dotfiles/.config/kitty/smart_tab.py) 与 [`.config/kitty/smart_window.py`](/Users/ouyangzhaoxin/Dotfiles/.config/kitty/smart_window.py) 继续只做入口转发：

- `smart_tab.py` 负责 tab
- `smart_window.py` 负责 os-window

复杂逻辑仍集中在共享模块中，避免两边分叉。

### `ssh_utils.py`

[`.config/kitty/ssh_utils.py`](/Users/ouyangzhaoxin/Dotfiles/.config/kitty/ssh_utils.py) 是本次设计唯一的策略中心，负责：

1. 解析源窗口。
2. 判断是否为交互式 SSH。
3. 提取 `destination`。
4. 读取 `window.cwd_of_child`。
5. 在本地路径与 SSH 路径之间选择。
6. 生成“非交互式 + 硬超时 + 失败回退本地”的最终启动命令。

### 状态文件策略

本次设计不新增本地或远端状态文件。

原因：

- `cwd` 信息优先复用 Kitty 已有的 shell integration 与 `window.cwd_of_child`。
- 本问题的核心不是“没有状态”，而是“自动 SSH 继承不能无限阻塞”。
- 先把行为约束收紧为“超时即回退”即可解决主问题，避免把实现扩成额外的状态同步系统。

## 数据流

### 本地窗口

数据流固定为：

1. `Cmd + E` / `Cmd + N`
2. `Hammerspoon` 拦截按键
3. 触发 `smart_tab.py` 或 `smart_window.py`
4. `ssh_utils.py` 判断“非 SSH”
5. `Kitty launch --cwd=last_reported`
6. 新 tab / window 直接进入本地 shell

### SSH 窗口

数据流固定为：

1. `Cmd + E` / `Cmd + N`
2. `Hammerspoon` 拦截按键
3. 触发 `smart_tab.py` 或 `smart_window.py`
4. `ssh_utils.py` 判断“交互式 SSH”
5. 提取 `destination` 与 `window.cwd_of_child`
6. 构造“SSH 尝试 + 本地回退”的启动命令
7. 新 tab / window 先执行该启动命令
8. 若 SSH 在 `2` 秒内成功，则进入同一远端目录
9. 若 SSH 超时或失败，则自动执行本地 `zsh -i`

## 错误处理

以下情况都必须视为可恢复失败，并直接回退本地：

1. 源窗口读取失败。
2. SSH 目标地址无法提取。
3. `window.cwd_of_child` 为空。
4. SSH 命令在 `2` 秒内未成功建立会话。
5. SSH 因网络错误、主机不可达、连接被拒绝或认证失败而退出。

报错策略：

- 不弹系统级阻断提示。
- 不让新 tab / window 直接停留在卡死中的 SSH 连接上。
- 可以在回退后的本地 shell 中输出一条简短诊断，例如“SSH clone timed out, fell back to local shell”，但不能污染正常成功路径。

## 测试策略

需要覆盖以下场景：

1. 本地 shell 中按 `Cmd + E`，新 tab 继承本地目录。
2. 本地 shell 中按 `Cmd + N`，新 window 继承本地目录。
3. 活跃 SSH 会话中按 `Cmd + E`，新 tab 进入相同远端目录。
4. 活跃 SSH 会话中按 `Cmd + N`，新 window 进入相同远端目录。
5. 远端主机不可达时，`Cmd + E` 在 `2` 秒内回退到本地 shell。
6. 远端主机不可达时，`Cmd + N` 在 `2` 秒内回退到本地 shell。
7. SSH 需要交互认证时，自动继承快速失败并回退本地。
8. `Codex` 或 `Claude Code` 前台运行时，按键仍然先被 `Hammerspoon` 截获，不被当前 TUI 吞掉。

静态验证至少包括：

1. `python3 -m py_compile .config/kitty/*.py`
2. `find .hammerspoon -name '*.lua' -print0 | xargs -0 -n1 luac -p`

## 风险与取舍

本设计刻意做了以下取舍：

1. 自动 SSH 继承优先保证“可恢复”和“有上限”，而不是优先保证“无条件成功”。
2. 需要交互认证的 SSH 目标，会被默认视为不适合放在 `Cmd + E` / `Cmd + N` 的自动路径里。
3. 当 `window.cwd_of_child` 无法提供可信远端目录时，设计选择回退本地，而不是冒险进入错误远端目录。

这个取舍的核心是：`Cmd + E` / `Cmd + N` 首先必须是“快速打开一个能用 tab / window”的快捷键，然后才是“尽量复制 SSH 上下文”的快捷键。
