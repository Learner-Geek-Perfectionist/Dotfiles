# Dotfiles 全量代码质量审查 — 设计文档

> 日期: 2026-03-28
> 状态: 已确认

## 目标

对 Dotfiles 项目进行全面的、逐行的代码质量审查，覆盖安全性、代码质量、架构健康度和代码精简度四个维度，输出一份按严重程度排序的综合报告。

## 方案

单 Agent 串行审查，按模块依赖顺序逐文件逐行扫描。

## 审查范围

~60 文件，~9200 行代码。

**排除：** `.git/`、`.pixi/`、`.claude/plugins/cache/`、`.DS_Store`

### 文件清单与审查顺序

| 批次 | 模块 | 文件 | 行数 |
|------|------|------|------|
| ① 基础库 | lib/ | `utils.sh`, `packages.sh` | ~436 |
| ② 安装核心 | 根目录 + scripts/ | `install.sh`, `uninstall.sh`, `install_dotfiles.sh`, `install_vscode_ext.sh`, `install_claude_code.sh`, `install_pixi.sh`, `install_kotlin_native.sh`, `macos_install.sh` | ~2862 |
| ③ Shell 配置 | 根 + .config/zsh/ | `.zshenv`, `.zprofile`, `.zshrc`, `platform.zsh`, `zinit.zsh`, `age-tokens.zsh`, `double-esc-clear.zsh`, `fzf-preview.sh` | ~628 |
| ④ Kitty | .config/kitty/ | `kitty.conf`, `smart_tab.py`, `smart_window.py`, `smart_close.py` | ~184+ |
| ⑤ Hammerspoon | .hammerspoon/ | `init.lua`, 2 config + 7 modules | ~726 |
| ⑥ 编辑器 | .config/Code & Cursor & Library | `settings.json` x4, `keybindings.json` x4 | JSON |
| ⑦ 其他配置 | 各处 | `.gitconfig`, `.ssh/config`, `karabiner.json`, `direnv.toml`, `pixi.toml`, ripgrep config/ignore | 杂项 |
| ⑧ 独立脚本 | sh-script/ | `get-my-ip.sh`, `envrc-project-template.sh` | ~168 |
| ⑨ Claude Code | .claude/ | `settings.json`, `file-deps.json`, `hooks/check-file-deps.sh`, `hooks/sync-dotfile.sh`, `plugins/claude-hud/config.json` | ~222 |
| ⑩ 轻审 | .config/zsh/ | `.p10k.zsh`（仅手动修改部分） | 1705 中抽检 |

## 审查维度

### 维度一：安全性（Security）

| 检查项 | 适用类型 | 说明 |
|--------|---------|------|
| 未引号的变量展开 | sh, zsh | `$var` → `"$var"`，防止词分割和通配符展开 |
| 命令注入风险 | sh, zsh | `eval`、未校验的 `$()` 拼接、`xargs` 无 `-0` |
| 敏感信息硬编码 | 全部 | token、密码、私钥路径是否暴露在明文中 |
| 临时文件安全 | sh | 是否用 `mktemp` 而非固定路径，是否有竞态条件 |
| 权限设置 | sh | `chmod` 是否过于宽松，SSH 配置权限 |
| age 加密使用 | zsh | 密钥管理是否安全 |

### 维度二：代码质量（Quality）

| 检查项 | 适用类型 | 说明 |
|--------|---------|------|
| 错误处理 | sh, zsh, py | `set -e` / `set -euo pipefail`，异常路径是否处理 |
| 死代码 | 全部 | 注释掉的代码块、未使用的变量/函数 |
| 重复代码 | sh | 跨脚本重复逻辑是否应提取到 lib/ |
| 命名一致性 | 全部 | 函数名风格、变量命名 |
| Shellcheck 合规 | sh, zsh | 对照 ShellCheck 常见规则 |
| Lua 代码风格 | lua | 局部变量 `local`、模块返回模式、全局污染 |
| Python 代码风格 | py | 类型提示、异常处理、Kitty API 使用 |
| JSON 格式 | json | 合法性、多余逗号 |

### 维度三：架构健康度（Architecture）

| 检查项 | 适用类型 | 说明 |
|--------|---------|------|
| install/uninstall 对称性 | sh | 每个安装操作是否有对应的卸载操作 |
| 幂等性 | sh | 重复执行是否安全 |
| 跨文件依赖完整性 | zsh, sh | source 路径是否存在，变量引用链是否完整 |
| Code/Cursor 配置同步 | json | 两套编辑器配置是否一致 |
| 平台兼容性 | sh, zsh | macOS/Linux 分支逻辑是否完整 |
| 模块边界清晰度 | 全部 | 各模块职责是否单一 |

### 维度四：代码精简度（Simplicity）

| 检查项 | 适用类型 | 说明 |
|--------|---------|------|
| 冗余代码 | 全部 | 无用变量、无效赋值、永远为真的分支 |
| 过度复杂实现 | sh, py, lua | 过度嵌套，可大幅简化的逻辑 |
| 逻辑重复 | sh | 多脚本相似模式应提取到 lib/ |
| 管道/命令简化 | sh, zsh | 多余管道、无用子 shell |
| 条件表达式简化 | sh, zsh | 可简化的条件判断 |
| 变量/函数冗余 | 全部 | 只用一次的中间变量、可内联的单行函数 |
| 过度防御 | sh, py | 不可能场景的检查，重复校验同一条件 |

## 严重程度定义

- **Critical** — 安全漏洞、数据丢失风险、执行会报错的 bug、大块重复逻辑（>15 行 x2+）
- **Warning** — 违反最佳实践、边缘情况可能出问题、可明显简化的复杂实现
- **Info** — 风格建议、可读性改进、微小简化机会

## 交付物

一份综合报告 `docs/reviews/2026-03-28-code-review.md`，结构：

1. 摘要（各级别数量统计）
2. 问题列表（按 Critical → Warning → Info 排序，每个问题含文件路径:行号、维度、描述、修复建议）
3. 按模块统计表
4. 按维度统计表

## 约束

- 只出报告，不修改任何代码文件
- 每个问题必须带精确行号
- 修复建议必须具体可操作
- `.p10k.zsh` 仅轻审手动修改部分
