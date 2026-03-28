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

#### [S-023] 跨脚本重复："下载-解压-替换-清理" 模式出现 5 次（100+ 行）
- **文件:** `scripts/install_claude_code.sh:120-137, 220-246, 275-303, 349-367` 和 `scripts/install_kotlin_native.sh:76-106`
- **维度:** 代码精简度
- **描述:** `install_rust_analyzer`、`install_kotlin_ls`、`install_lua_ls`、`install_jdtls`、`install_kotlin_native` 都遵循相同模式：`mktemp -d` → `curl -fsSL` 下载 → 解压 → `rm -rf` 旧安装 → `mv` → 清理，每次 20-30 行，总计 100+ 行重复。
- **修复建议:** 在 `lib/utils.sh` 中提取 `download_and_extract()` 通用函数，接受 URL、目标目录、解压格式三个参数。

---

#### [S-024] 跨脚本重复："计数器汇总报告" 模式出现 4+ 次
- **文件:** `scripts/install_claude_code.sh:494-514, 526-547, 779-847` 和 `scripts/install_vscode_ext.sh:187-209, 247-260`
- **维度:** 代码精简度
- **描述:** `add_marketplaces`、`install_plugins`、`install_mcp_servers` 和 vscode_ext 安装循环都使用 `installed/skipped/failed` 计数器 + 相同的汇总打印逻辑，至少 4 次重复。
- **修复建议:** 在 `lib/utils.sh` 中提取 `print_install_summary()` 函数。

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

#### [S-001] curl 管道直接执行远程脚本，无完整性验证
- **文件:** `scripts/install_pixi.sh:52`, `scripts/macos_install.sh:49`, `scripts/install_claude_code.sh:452`
- **维度:** 安全性
- **描述:** `curl -fsSL ... | bash` 将远程脚本直接管道执行，无校验和验证。DNS 劫持或上游入侵时会执行恶意代码。
- **修复建议:** 可接受风险（官方推荐方式），建议添加注释说明。

---

#### [S-002] 从 GitHub raw 下载 keychain 脚本，未固定 commit hash
- **文件:** `scripts/install_dotfiles.sh:141`
- **维度:** 安全性
- **描述:** 从 `master` 分支直接下载并赋予执行权限，上游恶意提交会在下次安装时被执行。
- **修复建议:** 固定到特定 commit hash 或 tag，下载后验证 sha256sum。

---

#### [S-005] `sudo xcode-select --reset` 无条件执行，可能覆盖用户设置
- **文件:** `scripts/macos_install.sh:38`
- **维度:** 安全性
- **描述:** 确认 Xcode CLT 已安装后无条件重置开发者工具路径，可能覆盖用户自定义的 `xcode-select -s` 设置。
- **修复建议:** 改为仅在路径无效时执行：`xcode-select -p &>/dev/null || sudo xcode-select --reset`。

---

#### [S-007] VSCode 插件安装循环未捕获每个插件的退出码
- **文件:** `scripts/install_vscode_ext.sh:222-231`
- **维度:** 代码质量
- **描述:** 安装是否成功完全依赖事后批量验证，`install_vsix_from_github` 和 `install_vsix_from_marketplace` 的返回值被忽略。
- **修复建议:** 捕获退出码，安装失败时立即记录到 `failed` 数组。

---

#### [S-009] pixi shell 集成会修改已由 Dotfiles 管理的 .zshrc
- **文件:** `scripts/install_pixi.sh:64-110`
- **维度:** 代码质量
- **描述:** `setup_shell_integration()` 往 `~/.zshrc` 追加 pixi PATH，但 `.zshrc` 由 `install_dotfiles.sh` 部署。被 `install.sh` 调用时不应再修改。
- **修复建议:** 当 `DOTFILES_DIR` 非空时跳过 `setup_shell_integration()`。

---

#### [S-011] Claude 插件检测依赖脆弱的 CLI 输出格式
- **文件:** `scripts/install_claude_code.sh:430`
- **维度:** 代码质量
- **描述:** `grep -q "^  ❯ ${plugin}$"` 精确匹配 Unicode 字符和固定缩进，CLI 版本更新后格式变化会导致每次都重装全部插件。
- **修复建议:** 改为 `grep -qF "$plugin"` 宽松匹配。

---

#### [S-013] jq 失败时空文件覆盖 settings.json，导致配置丢失
- **文件:** `scripts/install_claude_code.sh:575-576`
- **维度:** 代码质量
- **描述:** 如果 jq 命令失败（如 JSON 格式损坏），`> .tmp` 创建空文件，`mv` 会用空文件覆盖原配置。
- **修复建议:** `mv` 前检查 `.tmp` 非空：`[[ -s "$settings_file.tmp" ]] && mv ...`。

---

#### [S-017] pixi `--manifest-path` 传递了目录而非文件
- **文件:** `scripts/install_pixi.sh:138`
- **维度:** 架构健康度
- **描述:** `pixi install --manifest-path "$HOME"` 传入目录，文档要求传文件路径。
- **修复建议:** 改为 `pixi install --manifest-path "$HOME/pixi.toml"`。

---

#### [S-025] jdtls wrapper 脚本 37 行 heredoc 内嵌函数中
- **文件:** `scripts/install_claude_code.sh:370-407`
- **维度:** 代码精简度
- **描述:** wrapper 含 JVM 参数、jar 查找、哈希计算等复杂逻辑，作为 heredoc 嵌入使得函数难读且无法被 ShellCheck 检查。
- **修复建议:** 将 wrapper 作为独立文件存储（如 `scripts/wrappers/jdtls`），安装时复制。

---

#### [S-029] `setup_claude_hud` 函数 76 行，职责过多
- **文件:** `scripts/install_claude_code.sh:683-758`
- **维度:** 代码精简度
- **描述:** 承担配置部署、runtime 检测、旧文件清理、命令生成、测试、写入等 6 项职责。
- **修复建议:** 拆分为 `_deploy_hud_config()`、`_detect_hud_runtime()`、`_write_hud_statusline()` 三个子函数。

---

#### [S-031] Claude settings.json 合并逻辑 3 层回退过于复杂
- **文件:** `scripts/install_dotfiles.sh:104-127`
- **维度:** 代码精简度
- **描述:** jq 合并 → jq 去 hooks → python3 去 hooks → 原样拷贝，嵌套 if-else 共 24 行。
- **修复建议:** 提取为 `_deploy_claude_settings()` 独立函数。

---

#### [S-035] VSCode 编辑器检测逻辑存在 code/cursor 重叠边界情况
- **文件:** `scripts/install_vscode_ext.sh:126-136`
- **维度:** 代码质量
- **描述:** 如果系统同时有 `code`（实为 cursor 别名）和真正的 `cursor` 命令，第二个会被跳过。
- **修复建议:** 基于二进制路径去重而非类型名。

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

---

#### [S-003] MCP Server 配置硬编码本地代理地址
- **文件:** `scripts/install_claude_code.sh:825`
- **维度:** 安全性
- **描述:** `PROXY_URL` 硬编码为 `http://127.0.0.1:7890`，未运行代理的机器上 open-websearch MCP 会失败。
- **修复建议:** 从环境变量读取：`${PROXY_URL:-http://127.0.0.1:7890}`。

---

#### [S-004] VSIX 临时文件使用可预测的 /tmp 路径
- **文件:** `scripts/install_vscode_ext.sh:83,98`
- **维度:** 安全性
- **描述:** 使用固定 `/tmp/$vsix_name` 而非 `mktemp`，多用户系统存在 symlink race 风险。
- **修复建议:** 使用 `mktemp -d` 创建临时目录。

---

#### [S-006] settings.json jq 操作的 .tmp 文件无中断清理
- **文件:** `scripts/install_claude_code.sh:575-576`
- **维度:** 安全性
- **描述:** Ctrl+C 中断时 `.tmp` 文件会残留。
- **修复建议:** 使用 `trap` 在 EXIT 时清理，或用 `mktemp` 生成唯一文件名。

---

#### [S-008] VSCode 扩展安装进度直接用 ANSI 码，绕过日志系统
- **文件:** `scripts/install_vscode_ext.sh:221`
- **维度:** 代码质量
- **描述:** `printf "\r${CYAN}[%d/%d]${NC}..."` 不经过 `print_*` 函数，进度信息不写入日志。
- **修复建议:** 如有意不记录日志可接受，建议添加注释。

---

#### [S-010] `install_kotlin_native.sh` 打印两次成功消息
- **文件:** `scripts/install_kotlin_native.sh:118,127`
- **维度:** 代码质量
- **描述:** 函数内和 `main()` 各打印一次成功消息，且平台不支持时 `main()` 仍打印成功。
- **修复建议:** 删除 `main()` 中第 127 行的重复消息。

---

#### [S-012] `install_claude_code.sh` 全局变量 `$OS`/`$ARCH` 未声明
- **文件:** `scripts/install_claude_code.sh:855-856`
- **维度:** 代码质量
- **描述:** 大写全局变量被多个函数隐式引用，重构时容易遗漏。
- **修复建议:** 在文件顶部显式声明，或各函数独立调用 `detect_os`/`detect_arch`。

---

#### [S-014] 所有 6 个脚本都缺少 `set -u`
- **文件:** `scripts/*.sh`
- **维度:** 代码质量
- **描述:** 统一使用 `set -eo pipefail` 而非 `set -euo pipefail`，未定义变量引用不报错。
- **修复建议:** 统一改为 `set -euo pipefail`，需检查 `${var:-default}` 用法。

---

#### [S-015] `has_vscode`/`has_cursor` 检测策略与 `detect_real_type` 不一致
- **文件:** `scripts/install_dotfiles.sh:13-20` vs `scripts/install_vscode_ext.sh:116-123`
- **维度:** 代码质量
- **描述:** 两个脚本使用不同的 VSCode/Cursor 检测策略，可能导致配置部署到错误路径。
- **修复建议:** 将 `detect_real_type()` 提取到 `lib/utils.sh` 统一使用。

---

#### [S-016] `install_csharp_ls` 的 stderr 未重定向
- **文件:** `scripts/install_claude_code.sh:199`
- **维度:** 代码质量
- **描述:** `dotnet tool install -g csharp-ls >/dev/null` 只重定向 stdout，stderr 错误直接打印到终端。
- **修复建议:** 改为 `&>/dev/null`。

---

#### [S-019] `install_pixi.sh` 使用防御性 source，其他脚本不使用，风格不一致
- **文件:** `scripts/install_pixi.sh:14-16`
- **维度:** 架构健康度
- **描述:** `if [[ -f ... ]]; then source ...` 防御性加载，而其他 5 个脚本直接 `source`。如果文件不存在会静默继续但后续全部 `print_*` 调用报错。
- **修复建议:** 统一为直接 `source`，让 `set -e` 在文件缺失时立即退出。

---

#### [S-020] `INSTALLED_PLUGINS_JSON` 变量定义但从未使用
- **文件:** `scripts/install_claude_code.sh:29`
- **维度:** 架构健康度
- **描述:** 可能是设计初期打算用 JSON 检查已安装插件，后改用 CLI。死代码。
- **修复建议:** 删除未使用的变量。

---

#### [S-022] `setup_claude_hud` 使用 `eval` 执行动态命令
- **文件:** `scripts/install_claude_code.sh:745`
- **维度:** 安全性
- **描述:** `eval "$hud_cmd"` 中 `$hud_cmd` 由脚本控制非用户输入，但 `eval` 是安全审查高风险标记。
- **修复建议:** 添加注释说明内容完全由脚本控制，无注入风险。

---

#### [S-026] 多个 LSP 安装函数的平台检测重复
- **文件:** `scripts/install_claude_code.sh:107-118, 263-268`
- **维度:** 代码精简度
- **描述:** `install_rust_analyzer` 和 `install_lua_ls` 手动 if-else 构建平台字符串。
- **修复建议:** 在 `lib/utils.sh` 中添加 `get_platform_triple()` 函数。

---

#### [S-028] brew tap 检查模式重复
- **文件:** `scripts/macos_install.sh:89,109`
- **维度:** 代码精简度
- **描述:** 两次相同的 `brew tap | grep -q ... || brew tap ...` 模式。
- **修复建议:** 提取 `ensure_brew_tap()` 函数。

---

#### [S-030] `ensure_study_master_hooks` 的 jq 表达式嵌套复杂
- **文件:** `scripts/install_claude_code.sh:606-614`
- **维度:** 代码精简度
- **描述:** 嵌套 jq（条件判断+数组追加+默认值）在 shell 中难调试。
- **修复建议:** 可接受，建议添加行内注释或移到 `.jq` 文件。

---

#### [S-032] npm LSP 安装代码重复，可用循环替代
- **文件:** `scripts/install_claude_code.sh:168-190`
- **维度:** 代码精简度
- **描述:** `typescript-language-server` 和 `intelephense` 安装逻辑完全相同只是包名不同。
- **修复建议:** 用数组+循环替代。

---

#### [S-033] `copy_path` 每个文件都打印成功消息，噪音较多
- **文件:** `scripts/install_dotfiles.sh:36`
- **维度:** 代码精简度
- **描述:** 部署 20+ 文件时产生大量输出，淹没重要信息。
- **修复建议:** 改用 `print_dim`，全部完成后用 `print_success` 汇总。

---

#### [S-034] 多个 LSP 安装函数各自判断 "Linux only"
- **文件:** `scripts/install_claude_code.sh:142-143`
- **维度:** 代码精简度
- **描述:** `install_gopls`、`install_lua_ls`、`install_jdtls` 各自在函数内判断平台，分散且重复。
- **修复建议:** 在 `main()` 中按平台有条件地调用。

---

#### [S-036] `macos_install.sh` 不包装到 main() 函数
- **文件:** `scripts/macos_install.sh`
- **维度:** 代码质量
- **描述:** 所有代码在顶层执行，不检查参数，与其他脚本风格不一致。
- **修复建议:** 包装到 `main()` 中。

## 按模块统计

| 模块 | Critical | Warning | Info |
|------|----------|---------|------|

## 按维度统计

| 维度 | Critical | Warning | Info |
|------|----------|---------|------|
