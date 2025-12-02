# Dotfiles 项目执行流程图

## 整体安装流程

```mermaid
flowchart TB
    subgraph Entry["🚀 入口 (install.sh)"]
        A[开始安装] --> B[解析参数]
        B --> C{检测操作系统}
    end

    subgraph macOS["🍎 macOS 流程"]
        C -->|Darwin| M1[检查 Xcode CLI]
        M1 --> M2[安装/检查 Homebrew]
        M2 --> M3[安装 CLI 工具<br/>brew formulas]
        M3 --> M4[安装 GUI 应用<br/>brew casks]
        M4 --> M5[配置网络工具权限]
        M5 --> M6[setup_dotfiles.sh]
    end

    subgraph Linux["🐧 Linux 流程 (默认无 sudo)"]
        C -->|Linux| L1{检查参数}
        L1 -->|--use-sudo| L2[系统级 Nix 安装]
        L1 -->|默认| L3[检测用户命名空间]
        L3 --> L4[下载 nix-user-chroot]
        L4 --> L5[用户级 Nix 安装<br/>~/.nix]
        L2 --> L6[安装 Devbox]
        L5 --> L6
        L6 --> L7[创建 devbox 包装脚本]
        L7 --> L8[setup_dotfiles.sh]
    end

    subgraph Dotfiles["📁 Dotfiles 配置"]
        M6 --> D1
        L8 --> D1[创建 XDG 目录]
        D1 --> D2[复制配置文件]
        D2 --> D3[".zshenv / .zprofile / .zshrc"]
        D2 --> D4[".config/kitty"]
        D2 --> D5[".config/zsh"]
        D3 & D4 & D5 --> D6{macOS?}
        D6 -->|是| D7[配置 Hammerspoon]
        D7 --> D8[配置 Karabiner]
        D8 --> D9
        D6 -->|否| D9[安装 Zinit 插件]
    end

    subgraph VSCode["💻 VSCode 插件"]
        D9 --> V1{跳过 VSCode?}
        V1 -->|否| V2[install_vscode_ext.sh]
        V1 -->|是| END
        V2 --> END
    end

    END[🎉 安装完成!]

    style Entry fill:#1a1a2e,stroke:#16213e,color:#e94560
    style macOS fill:#2d4059,stroke:#16213e,color:#f07b3f
    style Linux fill:#ea5455,stroke:#16213e,color:#fff
    style Dotfiles fill:#00adb5,stroke:#16213e,color:#222831
    style VSCode fill:#393e46,stroke:#16213e,color:#00adb5
    style END fill:#28a745,stroke:#16213e,color:#fff
```

## 文件调用关系

```mermaid
graph LR
    subgraph 入口
        A[install.sh]
    end

    subgraph Linux 安装
        B1[install_nix.sh]
        B2[install_devbox.sh]
    end

    subgraph macOS 安装
        C1[macos_install.sh]
    end

    subgraph 库文件
        D1[lib/packages.sh]
        D2[lib/utils.sh]
    end

    subgraph 配置脚本
        E1[setup_dotfiles.sh]
        E2[install_vscode_ext.sh]
    end

    subgraph 配置文件
        F1[devbox.json]
    end

    A -->|Linux| B1
    B1 --> B2
    B2 --> E1
    A -->|macOS| C1
    C1 --> D1 & D2
    C1 --> E1
    E1 --> E2
    B2 -.-> F1

    style A fill:#e94560,stroke:#16213e,color:#fff
    style B1 fill:#f07b3f,stroke:#16213e,color:#fff
    style B2 fill:#f07b3f,stroke:#16213e,color:#fff
    style C1 fill:#00adb5,stroke:#16213e,color:#222831
    style F1 fill:#6bcb77,stroke:#16213e,color:#222831
```

## Nix-User-Chroot 安装流程

```mermaid
flowchart TB
    subgraph Check["检测环境"]
        A[开始] --> B{支持用户命名空间?}
        B -->|否| C[❌ 无法安装]
        B -->|是| D[创建 ~/.nix 目录]
    end

    subgraph Download["下载工具"]
        D --> E{检测架构}
        E -->|x86_64| F1[下载 x86_64 版本]
        E -->|aarch64| F2[下载 aarch64 版本]
        F1 & F2 --> G[nix-user-chroot]
    end

    subgraph Install["安装 Nix"]
        G --> H[nix-user-chroot ~/.nix bash]
        H --> I[curl nixos.org/install | sh]
        I --> J[Nix 安装到 ~/.nix]
    end

    subgraph Wrapper["创建包装脚本"]
        J --> K[~/.local/bin/nix-enter]
        K --> L[~/.local/bin/nix-shell-wrapper]
    end

    L --> M[✅ 完成]

    style Check fill:#1a1a2e,stroke:#16213e,color:#e94560
    style Download fill:#2d4059,stroke:#16213e,color:#f07b3f
    style Install fill:#ea5455,stroke:#16213e,color:#fff
    style Wrapper fill:#00adb5,stroke:#16213e,color:#222831
```

## Devbox 包装脚本工作流程

```mermaid
flowchart TB
    subgraph User["用户操作"]
        A["用户输入: devbox shell"]
    end

    subgraph Wrapper["~/.local/bin/devbox (包装脚本)"]
        B{已在 Nix 环境?}
        B -->|是| C["exec ~/.nix-profile/bin/devbox"]
        B -->|否| D["nix-user-chroot ~/.nix bash -c '...'"]
        D --> E["source nix.sh"]
        E --> F["exec devbox shell"]
    end

    subgraph Result["结果"]
        C --> G["开发环境就绪 ✅"]
        F --> G
    end

    A --> B

    style User fill:#00adb5,stroke:#16213e,color:#222831
    style Wrapper fill:#ea5455,stroke:#16213e,color:#fff
    style Result fill:#28a745,stroke:#16213e,color:#fff
```

> 💡 用户无需先运行 `nix-enter`，包装脚本会自动检测环境并透明处理 nix-user-chroot。

## Devbox 内部工作流程

```mermaid
flowchart LR
    subgraph User["用户操作"]
        A[cd ~/.dotfiles]
        B[devbox shell]
        C[开发环境就绪]
    end

    subgraph Devbox["Devbox 内部"]
        D[读取 devbox.json]
        E[从 Nixpkgs 获取包]
        F[创建隔离环境]
        G[执行 init_hook]
    end

    A --> B
    B --> D
    D --> E
    E --> F
    F --> G
    G --> C

    style User fill:#00adb5,stroke:#16213e,color:#222831
    style Devbox fill:#ea5455,stroke:#16213e,color:#fff
```

## 架构优势

| 特性 | 说明 |
|------|------|
| **统一包管理** | 使用 devbox.json 定义包，无需为不同发行版维护脚本 |
| **无需 sudo** | 默认使用 nix-user-chroot 实现用户级安装 |
| **透明包装** | devbox 包装脚本自动处理 nix 环境，用户无感知 |
| **包版本锁定** | Nix 保证包版本一致，可复现 |
| **维护成本低** | 一份配置适用于所有 Linux 发行版 |
