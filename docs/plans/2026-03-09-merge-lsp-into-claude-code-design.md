# 合并 install_lsp.sh 到 install_claude_code.sh

## 背景

`install_lsp.sh` 和 `install_claude_code.sh` 都服务于 Claude Code 的开发体验：
- `install_lsp.sh`：安装 LSP 二进制（rust-analyzer, gopls, jdtls 等）
- `install_claude_code.sh`：安装 Claude Code CLI + marketplace + LSP/Skill 插件

两者有明确的依赖关系（LSP 二进制必须先于 Claude Code LSP 插件安装），合并可减少文件数量并使依赖关系显式化。

## 方案

**方案 A：简单拼接**（已选定）

将 `install_lsp.sh` 的全部内容并入 `install_claude_code.sh`，保持所有现有函数不变。

## 合并后结构

```
scripts/install_claude_code.sh  (~350 行)
├── 配置区
│   ├── LSP_DIR, LSP_BIN（来自 install_lsp.sh）
│   ├── CLAUDE_PLUGINS_DIR, MARKETPLACES[], LSP_PLUGINS[], SKILL_PLUGINS[]
├── LSP 辅助函数（来自 install_lsp.sh）
│   ├── ensure_lsp_dirs(), get_latest_release()
│   ├── get_local_version(), save_local_version()
├── LSP 安装函数（来自 install_lsp.sh，7 个，原样保留）
├── Claude Code 函数（原有，不变）
│   ├── is_marketplace_installed(), is_plugin_installed()
│   ├── install_cli(), add_marketplaces(), install_plugins()
└── main()
    ├── 1) 安装 LSP 二进制
    ├── 2) 安装 Claude Code CLI
    ├── 3) 添加 Marketplace
    ├── 4) 安装 LSP 插件
    └── 5) 安装 Skill 插件
```

## install.sh 改动

- 删除 `bash "$dotfiles_dir/scripts/install_lsp.sh"` 调用
- `install_claude_code.sh` 调用保持不变

## 删除文件

- `scripts/install_lsp.sh`

## 不动的文件

- `scripts/install_kotlin_native.sh`：独立平台检测逻辑，非 Claude Code 直接相关
