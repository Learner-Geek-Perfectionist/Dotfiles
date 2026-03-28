# Dotfiles 代码质量审查报告

> 审查日期: 2026-03-28
> 审查范围: 全量（~60 文件，~9200 行）
> 审查维度: 安全性 / 代码质量 / 架构健康度 / 代码精简度

## 摘要

（审查完成后填写）

## 问题列表

### Critical

#### [I-008] install.sh 与 lib/utils.sh 存在 ~85 行重复代码
- **文件:** `install.sh:34-126` vs `lib/utils.sh:8-177`
- **维度:** 代码精简度
- **描述:** `install.sh` 为支持 `curl | bash` 场景内联了颜色定义、`has_sudo`、`_log`、`print_info/success/warn/error/header`、`_display_width`、`print_banner` 等约 85 行代码，与 `lib/utils.sh` 几乎完全重复。clone 后 source `lib/utils.sh` 会覆盖同名函数，导致 clone 前后日志格式不一致（有无 2 空格缩进）。未来维护两份代码极易产生不一致。
- **修复建议:** 将 clone 前的 bootstrap 日志函数简化为最小实现（~15 行 echo 包装），clone 后 source `lib/utils.sh` 获取完整版本。

---

### Warning

#### [L-001] 缺少 set -euo pipefail 防护，与 packages.sh 不一致
- **文件:** `lib/utils.sh:1-3`
- **维度:** 代码质量
- **描述:** `utils.sh` 没有设置 `set -euo pipefail`，与 `packages.sh`（设置了 `set -eo pipefail`）不一致。作为库文件不设 `set -e` 避免影响调用方是合理的，但缺少注释说明。
- **修复建议:** 在文件头部增加注释说明这是有意为之：`# 注意: 本文件作为库被 source，不设置 set -e 以避免影响调用方控制流`

---

#### [L-004] `_run_and_log` Linux 分支拼接命令字符串存在边缘风险
- **文件:** `lib/utils.sh:81`
- **维度:** 安全性
- **描述:** `script -c "$(printf '%q ' "$@")"` 将数组参数序列化为字符串再由 shell 重新解析，虽然 `printf %q` 能正确转义大多数特殊字符，但在 locale 相关的边缘情况下可能有风险。
- **修复建议:** 当前实现是 Linux `script` 命令限制下的合理方案，建议增加注释说明设计决策。

---

#### [L-005] `check_github_update` 通过全局变量 `_GITHUB_LATEST` 传递返回值
- **文件:** `lib/utils.sh:218-237`
- **维度:** 架构健康度
- **描述:** 函数通过设置全局变量 `_GITHUB_LATEST` 向调用方传递最新版本号，是隐式耦合。调用方必须知道要读取这个全局变量，在并发或嵌套调用场景下可能被意外覆盖。
- **修复建议:** 考虑使用 stdout 输出 + 命令替换，或保持现状并确保注释清晰。

---

#### [L-006] `print_banner` 中 `width` 变量可能为空导致算术错误
- **文件:** `lib/utils.sh:139-153`
- **维度:** 代码质量
- **描述:** 如果三种宽度获取方式全部失败，`width` 为空字符串，后续算术运算可能产生负数。第 152 行 `$((width - padding - display_width))` 可能产生负数传给 `printf`。
- **修复建议:** 第 147 行后添加：`[[ -z "$width" || "$width" -le 0 ]] 2>/dev/null && width=80`

---

#### [L-007] `print_banner` 中 `${#right_pad} -lt 0` 永假，是死代码
- **文件:** `lib/utils.sh:153`
- **维度:** 代码质量
- **描述:** `[[ ${#right_pad} -lt 0 ]]` 检查字符串长度是否小于 0，但字符串长度永远 >= 0，此条件永远为假。真正需要保护的是计算值而非结果长度。
- **修复建议:** 改为在 `printf` 之前保护计算值：`local right_width=$((width - padding - display_width))` → `[[ $right_width -lt 0 ]] && right_width=0`

---

#### [L-012] `set -eo pipefail` 在被 source 的纯数据文件中会影响调用方
- **文件:** `lib/packages.sh:5`
- **维度:** 架构健康度
- **描述:** `packages.sh` 仅定义两个数组，通过 `source` 加载。`set -eo pipefail` 会影响调用方后续所有命令的行为。虽然当前唯一调用方 `macos_install.sh` 也设置了 `set -eo pipefail`，但对于纯数据文件这是不必要的。
- **修复建议:** 移除 `set -eo pipefail`，或替换为注释说明由调用方负责设置。

---

#### [L-013] `rustup` 和 `rust` 同时列出，可能冲突
- **文件:** `lib/packages.sh:119-120`
- **维度:** 代码质量
- **描述:** `brew_formulas` 同时包含 `rustup` 和 `rust`。`rustup` 管理的 `rustc` 和 Homebrew 的 `rustc` 指向不同版本，会产生 PATH 冲突。
- **修复建议:** 如果使用 `rustup` 管理 Rust 工具链（推荐），移除 `rust`。

---

#### [I-001] `sudo` 命令展开未加引号，依赖 word splitting
- **文件:** `install.sh:208`
- **维度:** 安全性
- **描述:** `sudo ${pm#*:} "${missing[@]}"` 中 `${pm#*:}` 未加引号，依赖 word splitting 拆分成命令+参数。如果包管理器路径含空格会出问题。
- **修复建议:** 使用 `read -ra install_cmd <<< "${pm#*:}"` 转为数组后 `sudo "${install_cmd[@]}" "${missing[@]}"`。

---

#### [I-004] `rm_path` 对危险路径的保护不足
- **文件:** `uninstall.sh:57-58`
- **维度:** 安全性
- **描述:** `rm_path` 仅检查 `"$p" == "/"`，但 `//`、`/*`、`/tmp/../` 等变体同样危险。当前调用点全部使用硬编码路径，实际风险低，但作为通用函数防御不够。
- **修复建议:** 增加 `realpath` 规范化并限制只删除 `$HOME` 下的路径。

---

#### [I-005] `uninstall.sh` 中 `sudo pmset` 未检查 `has_sudo`
- **文件:** `uninstall.sh:247-248`
- **维度:** 安全性
- **描述:** 直接调用 `sudo pmset` 但未先检查是否有 sudo 权限，可能导致脚本挂起等待密码。`install.sh` 中正确使用了 `has_sudo` 检查。
- **修复建议:** 添加 `if has_sudo && pmset -g | ...` 前置检查。

---

#### [I-006] `jq` 操作 `settings.json` 使用四次非原子写入
- **文件:** `uninstall.sh:123-148`
- **维度:** 安全性 / 代码精简度
- **描述:** 四次独立的 `jq ... > file.tmp && mv file.tmp file` 操作，中间任何一次失败会导致 JSON 不一致。且多次 I/O 冗余。
- **修复建议:** 合并为一次 `jq` 调用处理所有字段删除。

---

#### [I-009] source `lib/utils.sh` 后 bootstrap 函数被覆盖，日志格式不一致
- **文件:** `install.sh:599-605`
- **维度:** 代码质量
- **描述:** clone 前使用 `install.sh` 内联的无缩进日志函数，clone 后 source `lib/utils.sh` 覆盖为有 2 空格缩进版本，导致用户看到的日志格式前后不一致。
- **修复建议:** 在注释中明确说明此行为，或将 bootstrap 版本改用不同函数名。

---

#### [I-012] install: Homebrew 包安装 / uninstall: 缺少卸载
- **文件:** `install.sh:254-267` vs `uninstall.sh`（缺失）
- **维度:** 架构健康度
- **描述:** 安装了 70+ Homebrew formulas/casks，但卸载脚本中无对应逻辑。仅停止了 `brew autoupdate`。
- **修复建议:** 增加 `--homebrew` 选项，至少列出由 Dotfiles 安装的包供用户手动卸载。

---

#### [I-013] install: Kotlin/Native 安装 / uninstall: 缺少卸载
- **文件:** `install.sh:397-399` vs `uninstall.sh`（缺失）
- **维度:** 架构健康度
- **描述:** `install_kotlin_native.sh` 安装到 `~/.local/share/kotlin-native` 和 `~/.local/bin/{konanc,cinterop,klib}`，卸载脚本中无对应清理。
- **修复建议:** 在卸载中添加 `rm_path ~/.local/share/kotlin-native` 和相关 bin 文件。

---

#### [I-014] install: npm LSP servers / uninstall: 缺少卸载
- **文件:** `scripts/install_claude_code.sh:159-190` vs `uninstall.sh`（缺失）
- **维度:** 架构健康度
- **描述:** 全局安装了 `typescript-language-server`、`typescript`、`intelephense` 三个 npm 包，卸载时未清理。
- **修复建议:** 添加 `npm uninstall -g` 对应包。

---

#### [I-016] install: Claude Marketplace + Plugins / uninstall: 仅清字段未实际卸载
- **文件:** `scripts/install_claude_code.sh:492-547` vs `uninstall.sh:112-176`
- **维度:** 架构健康度
- **描述:** 安装了 4 个 Marketplace、17 个插件，卸载仅清理了 `settings.json` 字段，未调用 `claude plugin uninstall` 实际卸载。
- **修复建议:** 遍历已安装插件列表调用 `claude plugin uninstall`。

---

#### [I-021] install: pmset 设置两个参数 / uninstall: 仅恢复一个
- **文件:** `scripts/macos_install.sh:122-131` vs `uninstall.sh:247-249`
- **维度:** 架构健康度
- **描述:** 安装时设置了 `sleep 0` 和 `tcpkeepalive 1`，卸载时只恢复了 `sleep 1`，未恢复 `tcpkeepalive`。
- **修复建议:** 添加 `sudo pmset -a tcpkeepalive 0`。

---

#### [I-029] `install_linux` 和 `install_macos` 存在重复的模式分发逻辑
- **文件:** `install.sh:458-501` 和 `install.sh:506-538`
- **维度:** 代码精简度
- **描述:** 两个函数各自有相同的 `VSCODE_ONLY`/`DOTFILES_ONLY`/`LSP_ONLY` 三段 early return 检查（共 ~18 行重复），可提取到 `main` 中统一处理。
- **修复建议:** 在 `main` 中统一处理 `*_ONLY` 模式后再分平台调用。

---

### Info

#### [L-002] 日志目录使用可预测的固定路径
- **文件:** `lib/utils.sh:30`
- **维度:** 安全性
- **描述:** `DOTFILES_LOG_DIR` 默认值为 `/tmp/dotfiles-logs-$(whoami)`，在多用户系统中路径可预测。个人开发环境风险较低。
- **修复建议:** 在 `mkdir -p` 后加 `chmod 700 "$DOTFILES_LOG_DIR"`。

---

#### [L-003] `echo -e` 会解释转义序列，`printf` 更安全
- **文件:** `lib/utils.sh:67-68`
- **维度:** 安全性
- **描述:** `echo -e "$output"` 会解释 `\n`、`\t` 等转义序列。如果 `$msg` 中包含反斜杠，会被错误解释。
- **修复建议:** 替换为 `printf '%b\n' "$output"`（行为一致但更符合 POSIX），或保持现状（`$msg` 来源是内部调用）。

---

#### [L-008] `_display_width` 每次调用 fork 子 shell，性能开销大
- **文件:** `lib/utils.sh:121-133`
- **维度:** 代码精简度
- **描述:** 每次调用都 fork `bash` 进程 + `tr` + `wc` 管道。单次调用无问题，高频调用有性能影响。
- **修复建议:** 可用 bash 内置 `${#str}` 替代 fork。但注释提到 Pixi 环境可能污染 `wc`，当前方案有其合理性。

---

#### [L-009] `print_divider` 中 `width` 无默认值保护
- **文件:** `lib/utils.sh:172`
- **维度:** 代码质量
- **描述:** 与 `print_banner` 类似，`width` 可能为空导致分隔线不可见。
- **修复建议:** 添加 `[[ -z "$width" || "$width" -le 0 ]] 2>/dev/null && width=80`。

---

#### [L-010] `get_local_version` 可用 bash 内置命令避免 fork
- **文件:** `lib/utils.sh:243-249`
- **维度:** 代码精简度
- **描述:** `cat "$version_file"` 会 fork 进程，可用 `read` 内置命令替代。
- **修复建议:** `<"$version_file" read -r version && echo "$version"`。微优化，保持现状也可。

---

#### [L-011] `_log` 函数 `level` 参数在有 `prefix` 时被忽略
- **文件:** `lib/utils.sh:58-69`
- **维度:** 代码精简度
- **描述:** 当 `prefix` 非空时 `level` 完全不被使用，增加了参数列表的认知负担。
- **修复建议:** 保持现状可接受，`level` 保留了日志级别的语义信息。

---

#### [L-014] 数组元素 `Eudic` 大小写不一致
- **文件:** `lib/packages.sh:65`
- **维度:** 代码质量
- **描述:** 所有 cask 名称都用小写，唯独 `Eudic` 大写开头。Homebrew cask token 通常全小写。
- **修复建议:** 确认 Homebrew 中准确 token，统一为 `eudic`。

---

#### [L-015] `anaconda` cask 会修改 `.zshrc`，与 dotfiles 管理冲突
- **文件:** `lib/packages.sh:64`
- **维度:** 代码质量
- **描述:** `anaconda` 安装后会注入 `conda init` 代码块到 `.zshrc`，与仓库管理 `.zshrc` 的理念冲突。
- **修复建议:** 在注释中说明 conda 与 dotfiles 的共存策略。

---

#### [L-016] `cmake` 同时以 formula 和 cask 两种形式存在
- **文件:** `lib/packages.sh:67, 104-105`
- **维度:** 代码精简度
- **描述:** `brew_casks` 有 `cmake-app`，`brew_formulas` 有 `cmake` + `cmake-docs`，两者并存会导致两份二进制。
- **修复建议:** 只保留其一：CLI only 留 formula，需要 GUI 留 cask。

---

#### [L-017] packages.sh 作为纯数据文件，shebang 行冗余
- **文件:** `lib/packages.sh:1`
- **维度:** 代码精简度
- **描述:** 该文件仅定义数组，从不被直接执行。`#!/bin/bash` 对于纯数据文件是多余的，但有助于编辑器识别。
- **修复建议:** 保留 shebang 用于编辑器识别，但可移除 `set -eo pipefail`（见 L-012）。

---

#### [I-002] `print_banner` 中 `width` 可能为空（install.sh 副本）
- **文件:** `install.sh:118`
- **维度:** 代码质量
- **描述:** 与 L-006 相同问题在 install.sh 副本中重现。三种宽度检测全部失败时 `width` 为空。
- **修复建议:** 同 L-006，添加默认值 `width=80`。

---

#### [I-003] `${#right_pad} -lt 0` 永假死代码（install.sh 副本）
- **文件:** `install.sh:122`
- **维度:** 代码质量
- **描述:** 与 L-007 相同问题在 install.sh 副本中重现。
- **修复建议:** 同 L-007。

---

#### [I-007] `install.sh` 缺少 `set -u`
- **文件:** `install.sh:9`
- **维度:** 代码质量
- **描述:** 使用 `set -eo pipefail` 但未开启 `-u`，引用未定义变量不报错。
- **修复建议:** 考虑改为 `set -euo pipefail`，对允许为空的变量使用 `${VAR:-}`。

---

#### [I-015] install: csharp-ls (dotnet tool) / uninstall: 缺少卸载
- **文件:** `scripts/install_claude_code.sh:193-209` vs `uninstall.sh`（缺失）
- **维度:** 架构健康度
- **描述:** 安装了 `csharp-ls` dotnet tool，卸载未清理。
- **修复建议:** `dotnet tool uninstall -g csharp-ls`。

---

#### [I-017] install: gopls / uninstall: 缺少卸载
- **文件:** `scripts/install_claude_code.sh:141-156` vs `uninstall.sh`（缺失）
- **维度:** 架构健康度
- **描述:** 通过 `go install` 安装了 `gopls`，卸载未清理 `$GOPATH/bin/gopls`。
- **修复建议:** `rm_path "$(go env GOPATH 2>/dev/null)/bin/gopls"`。

---

#### [I-018] install: ripgrep config / uninstall: 缺少卸载
- **文件:** `scripts/install_dotfiles.sh:67` vs `uninstall.sh`（缺失）
- **维度:** 架构健康度
- **描述:** 部署了 `~/.config/ripgrep` 目录，卸载未清理。
- **修复建议:** 在 `remove_dotfiles` 的 `.config/` 循环中添加 `ripgrep`。

---

#### [I-022] install: access_bpf 组 / uninstall: 缺少卸载
- **文件:** `scripts/macos_install.sh:134-146` vs `uninstall.sh`（缺失）
- **维度:** 架构健康度
- **描述:** macOS 安装时将用户添加到 `access_bpf` 组，卸载未从组中移除。
- **修复建议:** `sudo dseditgroup -o edit -d "$(whoami)" -t user access_bpf`。

---

#### [I-023] install: Linux keychain / uninstall: 缺少卸载
- **文件:** `scripts/install_dotfiles.sh:139-147` vs `uninstall.sh`（缺失）
- **维度:** 架构健康度
- **描述:** Linux 上安装了 `~/.local/bin/keychain`，卸载未清理。
- **修复建议:** `rm_path ~/.local/bin/keychain`。

---

#### [I-027] `clone_dotfiles` 使用固定临时路径
- **文件:** `install.sh:229`
- **维度:** 架构健康度
- **描述:** 使用 `/tmp/Dotfiles-$(whoami)` 而非 `mktemp -d`，同一用户并发运行会冲突。
- **修复建议:** 设计选择，当前可接受。如需并发支持可改用 `mktemp -d`。

---

#### [I-031] `remove_dotfiles` 中 VSCode/Cursor 路径平台分支可统一
- **文件:** `uninstall.sh:236-259`
- **维度:** 代码精简度
- **描述:** macOS 和 Linux 的路径不同但删除逻辑完全相同，可抽出路径数组减少重复。
- **修复建议:** 将路径数组抽出，删除逻辑只写一次。

---

#### [I-034] `uninstall.sh` 菜单无效输入静默退出
- **文件:** `uninstall.sh:291-303`
- **维度:** 代码精简度
- **描述:** 输入非 1-5 的值（如 `abc`）会静默 `exit 0`，无错误提示。
- **修复建议:** `*) print_error "无效选项: $c"; exit 1 ;;`。

---

#### [I-035] `setup_logging` 中多层 if/elif 可简化
- **文件:** `install.sh:148-173`
- **维度:** 代码精简度
- **描述:** 8 个 `if/elif` 分支仅为设置 `mode_suffix`，可用条件赋值链简化。
- **修复建议:** 可读性尚可，如需简化可用 `[[ ]] && mode_suffix=...` 链式写法。

## 按模块统计

| 模块 | Critical | Warning | Info |
|------|----------|---------|------|

## 按维度统计

| 维度 | Critical | Warning | Info |
|------|----------|---------|------|
