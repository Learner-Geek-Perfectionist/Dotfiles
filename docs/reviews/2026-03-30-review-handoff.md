# 2026-03-30 Review Handoff

## Context

本轮工作分两段：

1. 第一轮只读代码质量审查，先找高风险问题
2. 在用户授权下，直接修复“明确的实现错误和跨平台兼容性问题”，但**不改**以下两类策略
   - `.gitconfig` 安装策略
   - `uninstall.sh` 的删除边界

当前工作树有未提交修改，见本文件末尾“已修改文件”。

## 已修复项

### 1. `install_vscode_ext.sh` 运行时错误和 Bash 3.2 兼容性

文件：

- `scripts/install_vscode_ext.sh`

修复内容：

- 去掉了顶层作用域里的 `local`
- 去掉了对 `declare -A` 的依赖，兼容 macOS 自带 `/bin/bash` 3.2
- 修复了 `set -u` 下空数组展开导致的正常路径崩溃
- 保留了原有行为：按编辑器去重、插件分类安装、GitHub VSIX 版本检查、远程环境分支

验证：

- `bash -n scripts/install_vscode_ext.sh`
- `/bin/bash -n scripts/install_vscode_ext.sh`
- 使用伪造 `code/curl` 命令，在 `/bin/bash` 3.2 下跑通了一次 smoke test

### 2. `uninstall.sh` 的 macOS `grep -P` 兼容性

文件：

- `uninstall.sh`

修复内容：

- 将 Claude 插件/Marketplace 解析逻辑从 `grep -oP` 改为 `sed -n 's/^.*❯ //p'`
- 避免 macOS BSD `grep` 因不支持 `-P` 导致 `--claude` 卸载中途退出

验证：

- `bash -n uninstall.sh`
- `printf 'abc ❯ plugin-one\n' | /usr/bin/sed -n 's/^.*❯ //p'`

### 3. `.zshrc` 中 `uninstall` 别名指向错误脚本

文件：

- `.zshrc`

修复内容：

- 将远端地址从不存在的 `uninstall_dotfiles.sh` 改为仓库真实入口 `uninstall.sh`

### 4. Kitty 文本打开动作跨平台兼容

文件：

- `.config/kitty/open-actions.conf`

修复内容：

- 从仅支持 macOS 的 `open -a "Visual Studio Code"` 改为分平台回退链：
  - macOS: `open -a "Visual Studio Code"`
  - Linux/PATH 可见时: `code --reuse-window`
  - 最后回退: `xdg-open`

### 5. Hammerspoon 根卷磁盘使用率计算

文件：

- `.hammerspoon/modules/systemInfo.lua`

修复内容：

- 之前遍历卷列表后直接返回第一个卷的容量占用率，结果不稳定
- 现在优先识别根卷 `/` 或 `NSURLVolumeIsRootFileSystemKey`
- 如果拿不到根卷，再回退到第一个可用卷

验证：

- `luac -p .hammerspoon/modules/systemInfo.lua`

## 明确未改的事项

以下问题已经确认，但本轮按用户要求**暂不修改**：

- `.gitconfig` 中写死的 Git 身份安装策略
- `uninstall.sh` 当前“强力清理”的删除边界

## 第二轮 Install/Uninstall 专项 Findings

下面是第二轮聚焦 `install.sh` / `uninstall.sh` / 相关安装脚本后，留下的重点问题。

### [I-001] 本地执行 `install.sh` 实际安装的是远端仓库，不是当前工作树

文件：

- `install.sh:199`
- `install.sh:211`
- `install.sh:484`

描述：

- 无论用户是在本地仓库里运行 `bash install.sh`，还是通过 `curl | bash` 运行，脚本都会重新 clone 远端 `DEFAULT_BRANCH`
- 这使得“先在本地改脚本，再本地执行验证”的路径失真
- 当前行为更接近“bootstrap installer”，而不是“安装当前 checkout”

影响：

- 本地调试和实际安装目标不一致
- 用户可能误以为安装的是当前仓库状态

建议：

- 区分两种模式：
  - 本地仓库执行：直接使用当前仓库
  - 远程 bootstrap：继续 clone 临时目录

### [I-002] Linux rootless 安装被 `zsh` 预检查提前阻断

文件：

- `install.sh:145`
- `install.sh:149`
- `install.sh:173`
- `install.sh:481`

描述：

- `check_dependencies()` 在安装开始前强制要求 `git curl zsh`
- 但 Linux 完整流程里，真正安装 `zsh` 的责任本应落在 Pixi/Home 环境之后，或者至少不应在无 sudo 场景提前失败
- 这与 README 的“Linux 全程 rootless”叙述冲突

影响：

- 新 Linux 机器若尚未安装 `zsh`，且没有 sudo，安装会在 bootstrap 阶段直接失败

建议：

- 将依赖分层：
  - bootstrap 仅要求 `git`、`curl`
  - `zsh` 只在“设置默认 shell”之前检查

### [I-003] `~/pixi.toml` 的所有权模型不清晰：安装覆盖，卸载删除

文件：

- `install.sh:252`
- `install.sh:256`
- `scripts/install_pixi.sh:124`
- `uninstall.sh:115`

描述：

- 安装时直接 `cp "$manifest_src" "$HOME/pixi.toml"`
- 卸载时直接 `rm_path ~/pixi.toml`
- 对用户来说，这意味着 home manifest 既像仓库托管文件，又像用户自己的工作文件，但脚本没有声明 ownership

影响：

- 用户在 `~/pixi.toml` 的本地增删改会被下一次安装覆盖
- 卸载会直接删掉用户可能已接管维护的 manifest

建议：

- 后续需要做策略决策：
  - 仓库全托管
  - 首次生成后交给用户维护
  - merge/update 模式

### [I-004] macOS 电源管理没有做状态保持式回滚

文件：

- `scripts/macos_install.sh:130`
- `scripts/macos_install.sh:134`
- `uninstall.sh:313`
- `uninstall.sh:314`

描述：

- 安装时硬编码写入 `sleep 0`、`tcpkeepalive 1`
- 卸载时硬编码写回 `sleep 1`、`tcpkeepalive 0`
- 这不是恢复用户原始状态，而是替换成作者假定的“默认值”

影响：

- 有自定义 pmset 配置的用户，卸载后拿不回原值

建议：

- 如果未来要修，应在安装前记录原值，卸载时恢复原值

### [I-005] 编辑器配置/插件安装依赖当前 shell PATH，而不是应用真实存在

文件：

- `scripts/install_dotfiles.sh:13`
- `scripts/install_dotfiles.sh:18`
- `scripts/install_dotfiles.sh:107`
- `scripts/install_dotfiles.sh:119`
- `scripts/install_vscode_ext.sh:127`
- `.zshrc:46`
- `.zshrc:55`

描述：

- VSCode/Cursor 的“是否存在”判断依赖 `command -v code` / `command -v cursor`
- 但 macOS 安装刚完成时，PATH 不一定已经拥有 app 自带 CLI
- 这会造成“应用其实已安装，但配置/插件步骤被误跳过”

影响：

- 安装流程的幂等性和可预测性下降

建议：

- 后续可考虑：
  - macOS 下额外检查 `/Applications/.../bin`
  - 或在安装流程里显式补 PATH 后再判断

### [I-006] `copy_path()` 是叠加覆盖，不是收敛同步

文件：

- `scripts/install_dotfiles.sh:22`
- `scripts/install_dotfiles.sh:28`
- `scripts/install_dotfiles.sh:30`

描述：

- 目录复制使用 `cp -rf "$src/." "$dest/"`
- 仓库里已经删除的旧文件，不会从 `$HOME` 里同步删除

影响：

- 多次安装后，部署目录可能持续保留陈旧文件
- 用户以为 home 配置与仓库一致，实际上会逐步漂移

建议：

- 如果未来要修，应先明确策略：
  - 强同步
  - 保守覆盖
  - 只管理明确白名单文件

## 验证记录

本轮实际跑过的检查：

- `bash -n install.sh uninstall.sh lib/utils.sh ...`
- `zsh -n .zshenv .zprofile .zshrc ...`
- `python3 -m py_compile .config/kitty/*.py`
- `luac -p .hammerspoon/...`
- `shfmt -d ...` 仅做格式观察，不作为本轮修复目标
- `/bin/bash` 3.2 下对 `scripts/install_vscode_ext.sh` 做了定制 smoke test

本轮**没有**执行真实 `install.sh` / `uninstall.sh` 全流程，因为这些脚本会修改：

- `HOME` 下配置
- 编辑器配置
- `pmset`
- Homebrew / Pixi / Claude 相关状态

## 已修改文件

当前工作树中已修改但未提交的文件：

- `.config/kitty/open-actions.conf`
- `.hammerspoon/modules/systemInfo.lua`
- `.zshrc`
- `scripts/install_vscode_ext.sh`
- `uninstall.sh`

## 建议的下一步

如果在新会话里继续，建议优先处理这两项：

1. `install.sh` 区分“本地仓库执行”和“远程 bootstrap 执行”
2. 将 Linux bootstrap 依赖从 `git curl zsh` 缩到 `git curl`，把 `zsh` 检查后移

之后再决定以下策略类问题：

1. `~/pixi.toml` 的所有权模型
2. macOS `pmset` 是否要做状态保存/恢复
3. `copy_path()` 是否要从覆盖改为收敛同步

## 新会话建议提示词

可直接在新会话里这样说：

```text
请先阅读 docs/reviews/2026-03-30-review-handoff.md，然后继续处理其中 install/uninstall 第二轮专项 findings。
这次先实现：
1. install.sh 本地执行时使用当前仓库，而不是重新 clone 远端
2. Linux bootstrap 不再强制预装 zsh
不要改 .gitconfig 安装策略，也不要扩大/收紧 uninstall 删除边界。
```
