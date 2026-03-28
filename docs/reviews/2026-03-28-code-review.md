# Dotfiles 代码质量审查报告

> 审查日期: 2026-03-28
> 审查范围: 全量（~60 文件，~9200 行）
> 审查维度: 安全性 / 代码质量 / 架构健康度 / 代码精简度

## 摘要

（审查完成后填写）

## 问题列表

### Critical

（暂无）

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

## 按模块统计

| 模块 | Critical | Warning | Info |
|------|----------|---------|------|

## 按维度统计

| 维度 | Critical | Warning | Info |
|------|----------|---------|------|
