# Dotfiles 项目执行流程图

## 整体安装流程

```mermaid
flowchart TB
    subgraph Entry["🚀 入口 (install.sh)"]
        A[开始安装] --> B[解析参数]
        B --> C{检测操作系统}
    end

    subgraph macOS["🍎 macOS 流程"]
        C -->|Darwin| M1[安装 Homebrew 包]
        M1 --> M2[部署 Dotfiles 配置]
        M2 --> M3[配置 SSH]
        M3 --> M4[安装 VSCode 插件]
    end

    subgraph Linux["🐧 Linux 流程 (完全 Rootless)"]
        C -->|Linux| L1[安装 Pixi]
        L1 --> L2{仅 Pixi?}
        L2 -->|是| L3[完成]
        L2 -->|否| L4[同步 Pixi 工具包]
        L4 --> L5[部署 Dotfiles 配置]
        L5 --> L6[设置默认 Shell]
        L6 --> L7[安装 VSCode 插件]
    end

    subgraph Dotfiles["📁 Dotfiles 配置"]
        M2 --> D1
        L5 --> D1[创建 XDG 目录]
        D1 --> D2[复制配置文件]
        D2 --> D3[.zshenv / .zprofile / .zshrc]
        D2 --> D4[.config/zsh]
        D2 --> D5[.config/kitty]
        D3 & D4 & D5 --> D6[安装 Zinit 插件]
    end

    subgraph VSCode["💻 VSCode/Cursor 插件"]
        M4 --> V1
        L7 --> V1{检测编辑器类型}
        V1 -->|VSCode| V2[安装 VSCode 插件]
        V1 -->|Cursor| V3[安装 Cursor 插件]
        V2 & V3 --> V4[显示安装结果]
    end

    L3 --> END
    V4 --> END[🎉 安装完成!]

    style Entry fill:#1a1a2e,stroke:#16213e,color:#e94560
    style macOS fill:#2d4059,stroke:#16213e,color:#f07b3f
    style Linux fill:#ea5455,stroke:#16213e,color:#fff
    style Dotfiles fill:#00adb5,stroke:#16213e,color:#222831
    style VSCode fill:#393e46,stroke:#16213e,color:#00adb5
    style END fill:#28a745,stroke:#16213e,color:#fff
```

## Linux 安装详细流程

```mermaid
flowchart TB
    subgraph Step1["步骤 1/5: 安装 Pixi"]
        A1[下载 Pixi 二进制] --> A2[安装到 ~/.pixi/bin]
        A2 --> A3[配置 Shell 集成]
    end

    subgraph Step2["步骤 2/5: 同步工具包"]
        B1[复制 pixi-global.toml] --> B2[pixi global sync]
        B2 --> B3[安装所有预定义工具]
    end

    subgraph Step3["步骤 3/5: 部署配置"]
        C1[复制 .zshrc 等文件] --> C2[复制 .config/ 目录]
        C2 --> C3[安装 Zinit 插件]
    end

    subgraph Step4["步骤 4/5: 设置 Shell"]
        D1{zsh 可用?} -->|是| D2{当前是 zsh?}
        D2 -->|否| D3[sudo chsh -s zsh]
        D2 -->|是| D4[跳过]
        D1 -->|否| D5[提示安装 zsh]
    end

    subgraph Step5["步骤 5/5: VSCode 插件"]
        E1[检测 code/cursor 命令] --> E2[检测真实编辑器类型]
        E2 --> E3[获取已安装插件]
        E3 --> E4[跳过已安装 / 安装新插件]
        E4 --> E5[显示结果: 已安装/新安装/失败]
    end

    Step1 --> Step2 --> Step3 --> Step4 --> Step5

    style Step1 fill:#1a1a2e,stroke:#16213e,color:#e94560
    style Step2 fill:#2d4059,stroke:#16213e,color:#f07b3f
    style Step3 fill:#ea5455,stroke:#16213e,color:#fff
    style Step4 fill:#00adb5,stroke:#16213e,color:#222831
    style Step5 fill:#393e46,stroke:#16213e,color:#00adb5
```

## 文件调用关系

```mermaid
graph LR
    subgraph 入口
        A[install.sh]
    end

    subgraph 脚本
        B1[scripts/install_pixi.sh]
        B2[scripts/install_dotfiles.sh]
        B3[scripts/install_vscode_ext.sh]
        B4[scripts/macos_install.sh]
    end

    subgraph 库文件
        C1[lib/packages.sh]
        C2[lib/utils.sh]
    end

    subgraph 配置文件
        D1[.zshrc / .zprofile / .zshenv]
        D2[.config/zsh/]
        D3[.pixi/manifests/pixi-global.toml]
    end

    A -->|Linux| B1
    A -->|macOS| B4
    B1 --> B2
    B4 --> C1 & C2
    B4 --> B2
    B2 --> B3
    B2 --> D1 & D2
    B1 --> D3

    style A fill:#e94560,stroke:#16213e,color:#fff
    style B1 fill:#f07b3f,stroke:#16213e,color:#fff
    style B2 fill:#f07b3f,stroke:#16213e,color:#fff
    style B3 fill:#f07b3f,stroke:#16213e,color:#fff
    style B4 fill:#00adb5,stroke:#16213e,color:#222831
    style D3 fill:#6bcb77,stroke:#16213e,color:#222831
```

## VSCode/Cursor 插件安装流程

```mermaid
flowchart TB
    subgraph Detect["检测编辑器"]
        A[检测 code/cursor 命令] --> B{code --help}
        B -->|包含 Cursor| C[类型: cursor]
        B -->|不包含| D[类型: vscode]
    end

    subgraph Install["安装插件"]
        C & D --> E[获取已安装插件列表]
        E --> F[对比待安装列表]
        F --> G{已安装?}
        G -->|是| H[跳过]
        G -->|否| I[安装]
        I --> J{验证安装}
        J -->|成功| K[记录成功]
        J -->|失败| L[记录失败]
    end

    subgraph Result["显示结果"]
        H & K & L --> M[汇总显示]
        M --> N["⊘ 已安装 (黄色)"]
        M --> O["✓ 新安装 (绿色)"]
        M --> P["✗ 失败 (红色 + 原因)"]
    end

    style Detect fill:#1a1a2e,stroke:#16213e,color:#e94560
    style Install fill:#2d4059,stroke:#16213e,color:#f07b3f
    style Result fill:#00adb5,stroke:#16213e,color:#222831
```

## Pixi 工具包结构

```mermaid
graph TB
    subgraph Pixi["~/.pixi/"]
        A[bin/] --> A1[python]
        A --> A2[node]
        A --> A3[go]
        A --> A4[cargo]
        A --> A5[gcc]
        A --> A6[fzf]
        A --> A7[...]
        
        B[manifests/] --> B1[pixi-global.toml]
        
        C[envs/] --> C1[python/]
        C --> C2[node/]
        C --> C3[build-tools/]
        C --> C4[...]
    end

    B1 -->|pixi global sync| A
    B1 -->|定义| C

    style Pixi fill:#2d4059,stroke:#16213e,color:#f07b3f
```

## 架构优势

| 特性 | 说明 |
|------|------|
| **完全 Rootless** | Linux 上所有工具安装在 `~/.pixi/`，无需 root |
| **预编译二进制** | 从 conda-forge 下载预编译包，秒装即用 |
| **智能检测** | 自动检测 VSCode/Cursor，安装对应插件 |
| **跳过已安装** | 检测已安装的插件，只安装缺失的 |
| **验证安装** | 安装后验证是否真正成功，避免假阳性 |
| **彩色输出** | 清晰的颜色区分：成功/跳过/失败 |
