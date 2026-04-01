#!/bin/bash
# 部署 Codex CLI 配置：
# 1) 以仓库内 config.toml 为基线
# 2) 保留本机已有的 [projects."..."] 项（但移除当前 HOME 下的冗余子目录）
# 3) 自动确保当前 HOME 被标记为 trusted

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

src="${1:-$DOTFILES_DIR/.codex/config.toml}"
dest="${2:-$HOME/.codex/config.toml}"
trust_path="${3:-$HOME}"

[[ -f "$src" ]] || exit 0

mkdir -p "$(dirname "$dest")"

tmp_output="$(mktemp)"
tmp_projects="$(mktemp)"
trap 'rm -f "$tmp_output" "$tmp_projects"' EXIT

cp -f "$src" "$tmp_output"

if [[ -f "$dest" ]]; then
	awk -v trust_path="$trust_path" '
		function flush_block() {
			if (!in_block || skip_block || block_header == "") {
				block_header = ""
				block_body = ""
				return
			}
			if (seen[block_header]++) {
				block_header = ""
				block_body = ""
				return
			}
			if (printed_any) print ""
			print block_header
			if (block_body != "") printf "%s", block_body
			printed_any = 1
			block_header = ""
			block_body = ""
		}

		/^\[projects\."/ {
			flush_block()
			in_block = 1
			block_header = $0
			block_body = ""
			skip_block = ($0 == "[projects.\"" trust_path "\"]")
			if (!skip_block && index($0, "[projects.\"" trust_path "/") == 1) skip_block = 1
			next
		}

		/^\[/ {
			flush_block()
			in_block = 0
			skip_block = 0
			# 只从现有配置继承 [projects."..."]；其他段统一以仓库基线为准。
			next
		}

		{
			if (in_block) block_body = block_body $0 "\n"
		}

		END {
			flush_block()
		}
	' "$dest" >"$tmp_projects"
fi

if [[ -s "$tmp_projects" ]]; then
	printf '\n%s\n' "$(cat "$tmp_projects")" >>"$tmp_output"
fi

printf '\n[projects."%s"]\ntrust_level = "trusted"\n' "$trust_path" >>"$tmp_output"

mv "$tmp_output" "$dest"
chmod 600 "$dest"
