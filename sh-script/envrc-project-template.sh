#!/usr/bin/env bash
# ============================================
# 项目 .envrc 模板（用于 direnv）
# ============================================
# 使用方法：
#   1. 复制此文件到项目根目录并重命名为 .envrc
#   2. 根据项目需求修改下方配置
#   3. 运行 direnv allow 启用
#
# 功能：
#   - 继承 home 的 pixi 环境作为 fallback
#   - 激活项目的 pixi 环境
#   - 自动合并 PATH（项目 > home > 系统）
#   - 自动 fallback 未定义的变量（如 CC, CXX）
#   - 支持项目特定的环境变量
# ============================================

# 继承上级环境（home → project 分层覆盖）
source_up_if_exists

# 保存 home 环境（用于 fallback）
_home_path="$PATH"
_home_env=$(env)

# 清除 home 的 manifest 指向，避免 pixi 警告
unset PIXI_PROJECT_MANIFEST

# 激活本项目的 pixi 环境
eval "$(pixi shell-hook)"

# PATH 合并：项目 pixi + home pixi + 系统（去重）
PATH="$PATH:$_home_path"
PATH=$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
export PATH

# 自动 fallback：项目未定义的变量恢复 home 的值（排除 pixi 内部变量）
while IFS='=' read -r _name _value; do
  [[ $_name == PIXI_PROJECT_MANIFEST ]] && continue
  [[ -z "${!_name}" && -n "$_value" ]] && export "$_name=$_value"
done <<< "$_home_env"

unset _home_path _home_env _name _value

# p10k 显示：自动从 pixi.toml 读取项目名
export CONDA_DEFAULT_ENV="$(grep -m1 '^name' pixi.toml 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')"

# 修复 pixi shell-hook 覆盖的 HOST 变量（p10k 需要正确的主机名）
export HOST=$(hostname -s 2>/dev/null || hostname)

# ========== 项目特定环境变量（按需修改）==========
# 方式 1：使用 pixi activation script（推荐，在 pixi.toml 中配置）
#   [activation]
#   scripts = ["scripts/env.sh"]
#
# 方式 2：直接在这里设置（如果不想用 pixi activation）
# PROJECT_INSTALL="$PWD/install"
# path_add LD_LIBRARY_PATH "$PROJECT_INSTALL/lib"
# path_add CMAKE_PREFIX_PATH "$PROJECT_INSTALL"



