# -----------------------------------
# -------- XDG Base Directory
# -----------------------------------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Ensure XDG base directories exist
 mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

# -----------------------------------
# -------- Zsh Directory
# -----------------------------------
export ZDOTDIR="$HOME"
export ZPLUGINDIR="$ZDOTDIR/.config/zsh/plugins"
export ZSCRIPTDIR="$ZDOTDIR/.config/zsh/scripts"
export HISTFILE="$XDG_CACHE_HOME/zsh/.zsh_history" # HISTFILE 也是 zsh 内置的环境变量

# Ensure Zsh directories exist
 mkdir -p "$ZPLUGINDIR" "$ZSCRIPTDIR"


# Set the location for the zcompdump file to be in the cache directory
 export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump"

# Ensure the directory for zcompdump exists
 mkdir -p "$(dirname "$ZSH_COMPDUMP")"


# 使用 curl 获取 GitHub releases 最新的重定向地址，并且 grep 最新的版本号
LATEST_VERSION=$(curl -s -L -I https://github.com/JetBrains/kotlin/releases/latest | grep -i location | sed -E 's/.*tag\/(v[0-9\.]+).*/\1/')

# 检查系统类型并设置 Kotlin/Native 的安装目录
set_kotlin_native_install_dir() {
    SYSTEM_TYPE=$(uname)
    
    # 获取系统架构
    ARCH=$(uname -m)

    # 根据系统类型和架构设置安装目录
    if [[ "$SYSTEM_TYPE" == "Darwin" ]]; then
        # macOS 系统
        if [[ "$ARCH" == "arm64" ]]; then
            INSTALL_DIR="/opt/kotlin-native-macos-arm64-$LATEST_VERSION"
        else
            INSTALL_DIR="/opt/kotlin-native-macos-x86_64-$LATEST_VERSION"
        fi
    elif [[ "$SYSTEM_TYPE" == "Linux" ]]; then
        # Linux 系统
        if [[ "$ARCH" == "x86_64" ]]; then
            INSTALL_DIR="/opt/kotlin-native-linux-x86_64-$LATEST_VERSION"
        elif [[ "$ARCH" == "aarch64" ]]; then
            INSTALL_DIR="/opt/kotlin-native-linux-aarch64-$LATEST_VERSION"
        else
            echo "不支持的 Linux 架构: $ARCH"
            return 1
        fi
    else
        echo "未知系统类型: $SYSTEM_TYPE"
        return 1
    fi

    # 检查安装目录是否存在
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "Kotlin/Native 安装目录: $INSTALL_DIR"
    else
        echo "安装目录未找到: $INSTALL_DIR"
    fi
}

# 调用设置函数
set_kotlin_native_install_dir

# 可选：将安装目录的 bin 目录加入 PATH 环境变量
if [[ -n "$INSTALL_DIR" && -d "$INSTALL_DIR/bin" ]]; then
    export PATH="$INSTALL_DIR/bin:$PATH"
fi


# 判断操作系统
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS specific settings，设置 git 、clang++、ruby、make bash、VSCode、grep 等工具的环境变量
  export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export PATH="/opt/homebrew/opt/git/bin:$PATH"
  export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
  export PATH="/opt/homebrew/opt/bash/bin:$PATH"
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
  export HOMEBREW_NO_ENV_HINTS=1


elif [[ -f /etc/os-release ]]; then 
  
  # Fedora specific settings: 初始化 SDKMAN 环境
  if [[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
  else
    echo "SDKMAN is not installed in $HOME/.sdkman"
  fi
  
  # 其他 Linux 特有的设置可以放在这里
else
  # 其他操作系统的设置
  echo "Unsupported OS"
fi


## 代理配置
function proxy() {
    export https_proxy="http://127.0.0.1:7897"
    export http_proxy="http://127.0.0.1:7897"
    export all_proxy="socks5://127.0.0.1:7897"
    echo "Proxy enabled"
}

function unproxy() {
    unset https_proxy
    unset http_proxy
    unset all_proxy
    echo "Proxy disabled"
}

# Plugins
source "$ZPLUGINDIR/colorful_print.zsh"
source "$ZPLUGINDIR/homebrew.zsh"
source "$ZPLUGINDIR/zinit.zsh"

# 加载 p10k 主题的配置文件
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh


# p10k 的 prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi



# 清除整个屏幕
alias clear='clear && printf '\''\e[3J'\'''

# 感叹号「!」是 zsh 中特殊的前缀，用于历史扩展，禁止它。
setopt NO_BANG_HIST

# 检查 fzf 是否已安装
if command -v fzf >/dev/null 2>&1; then
    # 如果 fzf 存在，则加载 fzf 的 zsh 配置
    source <(fzf --zsh)
else
    echo "fzf is not installed. Please install fzf to enable its features."
fi
