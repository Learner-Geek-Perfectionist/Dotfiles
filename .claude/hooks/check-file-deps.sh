#!/usr/bin/env bash
# PostToolUse Hook: 在 Write/Edit 后检查 file-deps.json，输出关联文件提醒
# 输出到 stderr（Claude Code 读取 stderr 作为反馈），始终 exit 0（不阻断工具执行）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS_FILE="$SCRIPT_DIR/../file-deps.json"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 读取 stdin 中的 tool_input JSON
input="$(cat)"

# 提取 file_path
file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || true
if [[ -z "$file_path" ]]; then
  exit 0
fi

# 转为相对于项目根目录的路径
rel_path="${file_path#"$PROJECT_ROOT"/}"

# 如果路径没变（不在项目目录下），静默退出
if [[ "$rel_path" == "$file_path" ]]; then
  exit 0
fi

# 检查映射表是否存在
if [[ ! -f "$DEPS_FILE" ]]; then
  exit 0
fi

# 查找关联文件
deps="$(jq -r --arg key "$rel_path" '.[$key] // empty | .[]' "$DEPS_FILE" 2>/dev/null)"
if [[ -z "$deps" ]]; then
  exit 0
fi

# 输出提醒到 stderr
{
  echo ""
  echo "## file-deps: 你修改了 ${rel_path}，请检查以下关联文件是否需要同步更新："
  echo "$deps" | while IFS= read -r dep; do
    echo "  - $dep"
  done
  echo ""
} >&2

exit 0
