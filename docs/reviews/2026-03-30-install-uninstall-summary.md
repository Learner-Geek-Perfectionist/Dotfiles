# 2026-03-30 Install/Uninstall Summary

## 背景

本轮基于 `docs/reviews/2026-03-30-review-handoff.md` 继续处理 install/uninstall 专项问题。

与上一轮不同的是，这一轮不仅做了继续审查，也按用户确认过的产品语义直接修改了实现。

## 本轮确认的产品决策

### 1. `install.sh` 是 bootstrap installer

- 本地执行 `install.sh` 时继续 clone 远端仓库，不改成“直接安装当前工作树”
- 这符合 Docker / 新机初始化的使用方式

### 2. Linux 路线采用 Bootstrap 安装器语义

- bootstrap 前置依赖只要求 `git` 和 `curl`
- `zsh` 不再作为最前置依赖
- `zsh` 的安装/检查后移到真正需要“设置默认 shell”时再处理

### 3. `~/pixi.toml` 采用“托管但允许脱管”

- 首次安装时由 Dotfiles 托管
- 如果用户手动修改，后续安装自动跳过覆盖，视为用户已接管
- 如果用户后来把内容改回与仓库一致，会自动重新纳入托管
- 卸载时只删除仍处于托管状态的 `~/pixi.toml` / `~/pixi.lock`

## 本轮已修复问题

### 1. Homebrew autoupdate 无法真正落成 `--prune=all`

问题：

- 仅在 shell 配置里设置 `HOMEBREW_CLEANUP_MAX_AGE_DAYS=0`，不会影响 `brew autoupdate` 已生成的后台脚本

修复：

- `scripts/macos_install.sh` 现在会在配置 `brew autoupdate` 后检查其后台脚本
- 若后台脚本仍是 `brew cleanup`，会将其改写为 `brew cleanup --prune=all`
- 如有需要，会删除并重建 autoupdate 任务，再次应用 `--prune=all`

### 2. Claude MCP 卸载匹配失效

问题：

- `uninstall.sh` 原先依赖旧的 `claude mcp list` 输出缩进格式
- 实际输出变更后，`tavily` / `fetch` / `open-websearch` / `exa` 可能无法卸载

修复：

- 改为缓存一次 `claude mcp list` 输出
- 使用更稳健的 `^[[:space:]]*name:` 模式匹配

### 3. `pmset` 没有恢复原值

问题：

- 安装时写死 `sleep 0` / `tcpkeepalive 1`
- 卸载时写死恢复成 `sleep 1` / `tcpkeepalive 0`
- 无法恢复用户安装前的原始配置

修复：

- 在 `lib/utils.sh` 中新增 `pmset` 状态保存/恢复 helper
- 安装时保存 Battery / AC / UPS 的 `sleep` 和 `tcpkeepalive`
- 卸载时从保存的状态文件中恢复原值
- 恢复成功后删除状态文件；恢复失败则保留状态文件供后续重试

### 4. `copy_path()` 只做叠加覆盖，不做收敛同步

问题：

- 仓库中已删除的旧文件不会从 `$HOME` 中清理

修复：

- `scripts/install_dotfiles.sh` 新增目录同步逻辑
- 优先使用 `rsync -a --delete`
- 无 `rsync` 时使用 `find + cp -PRf` 兜底
- 现在受管目录会收敛到仓库当前状态

### 5. 编辑器发现仍依赖当前 shell PATH

问题：

- macOS 上 App 刚装好但 CLI 还未进 PATH 时
- VSCode/Cursor 配置复制和插件安装会被误跳过

修复：

- 在 `lib/utils.sh` 中新增编辑器发现 helper
- 优先使用 PATH 中的 `code` / `cursor`
- macOS 下回退到 App bundle 自带 CLI：
  - `/Applications/Visual Studio Code.app/.../bin/code`
  - `/Applications/Cursor.app/.../bin/cursor`
- `scripts/install_dotfiles.sh` 与 `scripts/install_vscode_ext.sh` 已统一接入新逻辑

### 6. `~/pixi.toml` ownership 不清晰

问题：

- 安装时会覆盖 `~/pixi.toml`
- 卸载时会删除 `~/pixi.toml`
- 但脚本帮助又鼓励用户直接对 `~/pixi.toml` 执行 `pixi add/remove`

修复：

- 在 `lib/utils.sh` 中新增 Pixi manifest 托管状态管理
- install 时通过哈希判断：
  - 不存在：创建并纳入托管
  - 仍为托管版本：允许覆盖更新
  - 用户已修改：自动脱管并跳过覆盖
  - 内容重新与仓库一致：自动重新纳管
- uninstall 时只删除“仍受托管”的 `~/pixi.toml` / `~/pixi.lock`
- `scripts/install_pixi.sh` 的帮助文案已补充“默认托管，手改即脱管”的说明

### 7. Linux bootstrap 阶段被 `zsh` 提前阻断

问题：

- 之前 `install.sh` 最前面强制要求 `git curl zsh`
- 这与“更干净的 Linux / Docker / rootless bootstrap”目标不一致

修复：

- `check_dependencies()` 现在只检查 `git` 和 `curl`
- Linux 下缺少 `zsh` 时，不再提前失败
- 到 `setup_default_shell()` 阶段再处理 `zsh`
- 若有 sudo，会在该阶段尝试安装 `zsh`
- 若无 sudo，则仅提示用户后续手动设置，不阻断前面的安装流程

## 当前 install/uninstall 语义

### install

- `install.sh` 仍然 clone 远端仓库执行
- Linux bootstrap 只要求 `git + curl`
- `zsh` 不是最前置依赖
- `~/pixi.toml` 默认受托管，但用户手改后自动脱管
- Dotfiles 目录同步是“收敛同步”，而非“只叠加覆盖”
- VSCode/Cursor 的检测不再只看 PATH
- Homebrew autoupdate 的 cleanup 目标是 `--prune=all`

### uninstall

- Claude MCP 卸载与当前 CLI 输出格式对齐
- `pmset` 尝试恢复安装前保存的原始状态
- 只删除仍由 Dotfiles 托管的 `~/pixi.toml` / `~/pixi.lock`
- 已脱管或用户自维护的 Pixi manifest 会被保留

## 验证记录

本轮做过的验证包括：

- `bash -n` 检查：
  - `install.sh`
  - `uninstall.sh`
  - `lib/utils.sh`
  - `scripts/install_dotfiles.sh`
  - `scripts/install_pixi.sh`
  - `scripts/install_vscode_ext.sh`
  - `scripts/macos_install.sh`
- Homebrew autoupdate 脚本改写的定向 smoke test
- `claude mcp list` 输出匹配的定向 smoke test
- `pmset` 备份/恢复 helper 的临时 `HOME` 定向 smoke test
- Pixi manifest “首次托管 / 用户修改后脱管 / 改回一致后重新纳管 / uninstall 仅删除托管文件”的定向 smoke test
- 纯净 shell 环境下编辑器 CLI fallback 的定向 smoke test

## 当前剩余事项

当前没有继续留存的明确 install/uninstall 代码问题。

剩余的是集成验证缺口，而不是新的实现结论：

- 尚未在真实干净 Linux / Docker 环境中完整跑一遍 `install.sh`
- 尚未在真实 macOS 环境中完整跑一遍 `install.sh` / `uninstall.sh`
- 尚未对真实本机状态做端到端回归验证（Homebrew / Pixi / Claude / `pmset`）

## 本轮涉及文件

- `install.sh`
- `lib/utils.sh`
- `scripts/install_dotfiles.sh`
- `scripts/install_pixi.sh`
- `scripts/install_vscode_ext.sh`
- `scripts/macos_install.sh`
- `uninstall.sh`

## 结论

以本轮确认过的产品语义为准：

- install/uninstall 专项里此前明确暴露的问题已完成修复
- 当前主要风险不再是代码实现缺陷，而是缺少一次真实环境的端到端 smoke/integration test
