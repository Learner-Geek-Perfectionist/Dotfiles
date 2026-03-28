# Dotfiles 全量代码质量审查 — 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 对 Dotfiles 项目全部 ~60 文件逐行审查，输出一份按严重程度排序的综合报告到 `docs/reviews/2026-03-28-code-review.md`。

**Architecture:** 单 Agent 串行审查，按模块依赖顺序（基础库 → 安装核心 → Shell 配置 → 应用配置 → 杂项）逐批次扫描。每批次完成后将发现的问题追加到报告草稿中，最后汇总排序生成终稿。

**Tech Stack:** Shell (bash/zsh), Python, Lua, JSON — 人工逐行审查，不依赖外部 lint 工具。

**设计文档:** `docs/plans/2026-03-28-code-review-design.md`

---

## 审查维度速查（每个文件都对照此表）

| 维度 | 核心检查项 |
|------|-----------|
| **安全性** | 未引号变量、命令注入（eval/$()拼接）、敏感信息硬编码、临时文件竞态、chmod 过宽、age 密钥管理 |
| **代码质量** | set -e/pipefail、死代码、重复代码、命名一致性、ShellCheck 规则、Lua local/全局污染、Python 异常处理、JSON 合法性 |
| **架构健康度** | install/uninstall 对称、幂等性、跨文件依赖完整性、Code/Cursor 同步、平台兼容分支、模块边界 |
| **代码精简度** | 冗余代码、过度复杂、逻辑重复、管道简化、条件简化、无用中间变量、过度防御 |

## 严重程度

- **Critical** — 安全漏洞、数据丢失、会报错的 bug、大块重复（>15行×2+）
- **Warning** — 违反最佳实践、边缘情况风险、可明显简化
- **Info** — 风格建议、可读性、微小优化

## 约束

- **只出报告，不修改任何代码文件**
- 每个问题必须带 `文件路径:行号`
- 修复建议必须具体可操作（给出应改成什么，不说"建议改进"）

---

### Task 1: 初始化报告骨架

**Files:**
- Create: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 创建报告文件，写入骨架结构**

```markdown
# Dotfiles 代码质量审查报告

> 审查日期: 2026-03-28
> 审查范围: 全量（~60 文件，~9200 行）
> 审查维度: 安全性 / 代码质量 / 架构健康度 / 代码精简度

## 摘要

（审查完成后填写）

## 问题列表

### Critical

（审查中逐步填入）

### Warning

（审查中逐步填入）

### Info

（审查中逐步填入）

## 按模块统计

| 模块 | Critical | Warning | Info |
|------|----------|---------|------|

## 按维度统计

| 维度 | Critical | Warning | Info |
|------|----------|---------|------|
```

**Step 2: Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs: 初始化代码审查报告骨架"
```

---

### Task 2: 审查批次① — 基础库 lib/

**Files:**
- Read: `lib/utils.sh` (~256 行)
- Read: `lib/packages.sh` (~180 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 逐行审查 `lib/utils.sh`**

逐行读取全部内容，对照 4 个维度检查：
- 安全性：所有变量展开是否加引号，函数参数传递是否安全
- 代码质量：是否有 `set -e`，函数命名是否一致（snake_case），是否有死代码
- 架构健康度：工具函数是否被其他脚本正确引用，是否有循环依赖
- 代码精简度：是否有冗余函数、过度复杂的实现、可简化的逻辑

**Step 2: 逐行审查 `lib/packages.sh`**

同上维度检查，额外关注：
- 包列表中是否有不再使用的包
- 包分组是否合理
- 是否有重复定义

**Step 3: 将发现的问题追加到报告对应章节**

按 Critical/Warning/Info 分级，每个问题格式：
```markdown
#### [X-NNN] 问题标题
- **文件:** `lib/utils.sh:42`
- **维度:** 安全性
- **描述:** 具体说明
- **修复建议:** 具体改法
```

**Step 4: Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次① lib/ 基础库审查"
```

---

### Task 3: 审查批次② — 安装核心（第一部分：install.sh + uninstall.sh）

**Files:**
- Read: `install.sh` (~665 行)
- Read: `uninstall.sh` (~313 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 逐行审查 `install.sh`**

重点检查：
- 安全性：`sudo` 使用、用户输入处理、路径拼接
- 代码质量：错误处理、`set -euo pipefail`、函数结构
- 架构健康度：对 `lib/utils.sh` 的 source 是否正确，各模块安装调用是否完整
- 代码精简度：是否有重复的安装模式可提取为函数

**Step 2: 逐行审查 `uninstall.sh`**

同上维度，额外重点：
- **install/uninstall 对称性交叉检查：** 逐项对照 `install.sh` 中的每个安装操作，确认 `uninstall.sh` 中有对应的卸载逻辑
- 卸载顺序是否与安装顺序相反（依赖关系）
- 是否有 install 新增但 uninstall 遗漏的模块

**Step 3: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次② install.sh + uninstall.sh 审查"
```

---

### Task 4: 审查批次② — 安装核心（第二部分：scripts/）

**Files:**
- Read: `scripts/install_dotfiles.sh` (~169 行)
- Read: `scripts/install_vscode_ext.sh` (~264 行)
- Read: `scripts/install_claude_code.sh` (~917 行)
- Read: `scripts/install_pixi.sh` (~248 行)
- Read: `scripts/install_kotlin_native.sh` (~131 行)
- Read: `scripts/macos_install.sh` (~154 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 逐个审查 6 个安装脚本**

每个脚本对照 4 维度，额外重点：
- `install_claude_code.sh`（917 行，最大文件）：重点检查复杂度和重复逻辑
- 所有脚本：对 `lib/utils.sh` 工具函数的调用是否正确
- 幂等性：重复运行是否安全（不会重复追加配置、不会覆盖用户修改）
- 跨脚本重复模式：6 个脚本间是否有相似的安装逻辑可提取到 lib/

**Step 2: 交叉检查 install.sh 对这些脚本的调用方式**

确认 `install.sh` 中调用参数与脚本实际接受的参数一致。

**Step 3: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次② scripts/ 安装脚本审查"
```

---

### Task 5: 审查批次③ — Shell 配置

**Files:**
- Read: `.zshenv` (~21 行)
- Read: `.zprofile` (~28 行)
- Read: `.zshrc` (~239 行)
- Read: `.config/zsh/plugins/platform.zsh` (~21 行)
- Read: `.config/zsh/plugins/zinit.zsh` (~138 行)
- Read: `.config/zsh/plugins/age-tokens.zsh` (~66 行)
- Read: `.config/zsh/plugins/double-esc-clear.zsh` (~32 行)
- Read: `.config/zsh/fzf/fzf-preview.sh` (~82 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 按加载顺序审查 Shell 配置链**

按 `.zshenv` → `.zprofile` → `.zshrc` → plugins 顺序审查，重点：
- 变量定义链：`.zshenv` 中定义的变量在下游是否被正确引用
- source 路径：`.zshrc` 中 source 的所有路径是否存在
- 加载时序：依赖 PATH 的插件是否在 PATH 设置之后加载
- `age-tokens.zsh`：加密令牌处理的安全性

**Step 2: 检查 fzf-preview.sh 与 ripgrep config 的关联**

确认 `FZF_DEFAULT_OPTS` 中引用的预览脚本路径正确，ripgrep config 文件存在。

**Step 3: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次③ Shell 配置审查"
```

---

### Task 6: 审查批次④ — Kitty 终端配置

**Files:**
- Read: `.config/kitty/kitty.conf`
- Read: `.config/kitty/Catppuccin-Frappe.conf`
- Read: `.config/kitty/smart_tab.py` (~82 行)
- Read: `.config/kitty/smart_window.py` (~73 行)
- Read: `.config/kitty/smart_close.py` (~29 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 审查 kitty.conf**

- 配置项是否有冲突或重复
- include 的主题文件是否存在
- 快捷键映射是否有冲突

**Step 2: 审查 3 个 Python 自定义脚本**

- Kitty API 使用是否正确（`kitty.boss` 调用）
- 异常处理：SSH 断开等边缘情况
- 代码精简度：3 个脚本间是否有可复用逻辑

**Step 3: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次④ Kitty 配置审查"
```

---

### Task 7: 审查批次⑤ — Hammerspoon

**Files:**
- Read: `.hammerspoon/init.lua` (~22 行)
- Read: `.hammerspoon/config/KeyBinds.lua` (~36 行)
- Read: `.hammerspoon/config/keyConfig.lua` (~51 行)
- Read: `.hammerspoon/modules/systemInfo.lua` (~327 行)
- Read: `.hammerspoon/modules/base.lua` (~165 行)
- Read: `.hammerspoon/modules/windowManagement.lua` (~67 行)
- Read: `.hammerspoon/modules/caffeinate.lua`
- Read: `.hammerspoon/modules/inputMethod.lua`
- Read: `.hammerspoon/modules/AppToggler.lua` (~18 行)
- Read: `.hammerspoon/modules/reload.lua` (~19 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 审查 init.lua 入口和 config/**

- 模块加载顺序是否正确
- require 路径是否与文件路径匹配

**Step 2: 逐个审查 7 个 modules/**

重点：
- Lua 代码风格：是否使用 `local`，避免全局污染
- `systemInfo.lua`（327 行最大）：复杂度、可简化的逻辑
- 模块返回模式是否一致
- 快捷键是否有冲突

**Step 3: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次⑤ Hammerspoon 审查"
```

---

### Task 8: 审查批次⑥ — 编辑器配置

**Files:**
- Read: `.config/Code/User/settings.json`
- Read: `.config/Code/User/keybindings.json`
- Read: `.config/Cursor/User/settings.json`
- Read: `.config/Cursor/User/keybindings.json`
- Read: `Library/Application Support/Code/User/settings.json`
- Read: `Library/Application Support/Code/User/keybindings.json`
- Read: `Library/Application Support/Cursor/User/settings.json`
- Read: `Library/Application Support/Cursor/User/keybindings.json`
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 检查 Code/Cursor 配置一致性**

用 diff 对比：
- `.config/Code/User/settings.json` vs `.config/Cursor/User/settings.json`
- `.config/Code/User/keybindings.json` vs `.config/Cursor/User/keybindings.json`
- 上述 `.config/` 版本 vs `Library/Application Support/` 版本

记录任何差异。

**Step 2: 审查配置内容**

- JSON 格式合法性
- 是否有已废弃的设置项
- 是否有冲突的快捷键绑定
- 是否引用了未安装的扩展

**Step 3: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次⑥ 编辑器配置审查"
```

---

### Task 9: 审查批次⑦ — 其他配置文件

**Files:**
- Read: `.gitconfig`
- Read: `.ssh/config`
- Read: `.config/karabiner/karabiner.json`
- Read: `.config/direnv/direnv.toml`
- Read: `pixi.toml`
- Read: `.config/ripgrep/config`
- Read: `.config/ripgrep/ignore`
- Read: `.envrc`
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 逐个审查配置文件**

- `.gitconfig`：安全性（是否暴露邮箱/token）、配置合理性
- `.ssh/config`：权限、Include 合并逻辑、Host 配置完整性
- `karabiner.json`：规则冲突、JSON 合法性
- `pixi.toml`：依赖是否与 shell 配置中引用的工具一致
- ripgrep config：与 `.zshrc` 中 `$RIPGREP_CONFIG_PATH` 引用是否匹配

**Step 2: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次⑦ 其他配置文件审查"
```

---

### Task 10: 审查批次⑧ — 独立脚本 sh-script/

**Files:**
- Read: `sh-script/get-my-ip.sh` (~107 行)
- Read: `sh-script/envrc-project-template.sh` (~61 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 逐行审查 2 个独立脚本**

4 维度全扫，特别关注：
- `get-my-ip.sh`：外部 API 调用的错误处理、超时设置
- `envrc-project-template.sh`：模板生成的安全性

**Step 2: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次⑧ 独立脚本审查"
```

---

### Task 11: 审查批次⑨ — Claude Code 配置

**Files:**
- Read: `.claude/settings.json` (~27 行)
- Read: `.claude/file-deps.json` (~97 行)
- Read: `.claude/hooks/check-file-deps.sh` (~49 行)
- Read: `.claude/hooks/sync-dotfile.sh` (~39 行)
- Read: `.claude/plugins/claude-hud/config.json` (~10 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 审查 settings.json 和 file-deps.json**

- JSON 合法性
- hooks 注册是否与实际 hook 文件匹配
- file-deps 中的路径是否都存在

**Step 2: 审查 2 个 hook 脚本**

- Shell 脚本质量（4 维度）
- hook 触发条件是否正确
- 与 `install_claude_code.sh` 中的安装逻辑是否一致

**Step 3: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次⑨ Claude Code 配置审查"
```

---

### Task 12: 审查批次⑩ — .p10k.zsh 轻审

**Files:**
- Read: `.config/zsh/.p10k.zsh` (~1705 行)
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 识别手动修改部分**

通过 `git log --follow -p .config/zsh/.p10k.zsh` 查看提交历史，找出用户手动修改的区域（非 p10k 向导生成的部分）。

**Step 2: 仅对手动修改区域做 4 维度轻审**

**Step 3: 追加问题到报告，Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成批次⑩ p10k 轻审"
```

---

### Task 13: 汇总报告终稿

**Files:**
- Modify: `docs/reviews/2026-03-28-code-review.md`

**Step 1: 填写摘要**

统计各级别问题总数，填入报告顶部摘要区。

**Step 2: 按严重程度重排问题列表**

确保 Critical 在前，Warning 次之，Info 最后。同级别内按模块顺序排列。

**Step 3: 填写统计表**

- 按模块统计表：10 个批次各自的 Critical/Warning/Info 数量
- 按维度统计表：安全性/代码质量/架构健康度/代码精简度各自的 Critical/Warning/Info 数量

**Step 4: 最终 Commit**

```bash
git add -f docs/reviews/2026-03-28-code-review.md
git commit -m "docs(review): 完成 Dotfiles 全量代码质量审查报告"
```

---

### Task 14: 审查完成确认

**Step 1: 通读报告终稿，确认**

- 所有问题都有行号
- 所有修复建议都具体可操作
- 统计数字与问题列表一致
- 没有遗漏文件

**Step 2: 向用户展示摘要和关键发现**
