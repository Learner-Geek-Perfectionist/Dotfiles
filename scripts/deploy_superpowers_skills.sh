#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

repo_url="${SUPERPOWERS_REPO_URL:-https://github.com/obra/superpowers.git}"
clone_dir="${1:-$HOME/.codex/superpowers}"
link_dir="${2:-$HOME/.agents/skills/superpowers}"
state_file="${3:-$(superpowers_state_file)}"
skills_target="$clone_dir/skills"

ensure_clone() {
	if [[ -d "$clone_dir/.git" ]]; then
		local origin normalized_origin normalized_repo_url
		origin=$(git -C "$clone_dir" remote get-url origin 2>/dev/null || true)
		normalized_origin=$(normalize_git_remote "$origin" 2>/dev/null || true)
		normalized_repo_url=$(normalize_git_remote "$repo_url" 2>/dev/null || true)
		if [[ -n "$origin" && "$normalized_origin" != "$normalized_repo_url" ]]; then
			print_warn "superpowers 仓库 origin 不匹配，跳过: $clone_dir"
			return 1
		fi
		git -C "$clone_dir" pull --ff-only >/dev/null 2>&1 || {
			print_warn "superpowers 更新失败，跳过: $clone_dir"
			return 1
		}
		return 0
	fi

	if [[ -e "$clone_dir" ]]; then
		print_warn "superpowers 目标已存在且不是 Git 仓库，跳过: $clone_dir"
		return 1
	fi

	git clone "$repo_url" "$clone_dir" >/dev/null 2>&1 || {
		print_warn "superpowers 克隆失败，跳过: $repo_url"
		return 1
	}
}

ensure_link() {
	mkdir -p "$(dirname "$link_dir")"

	if [[ -L "$link_dir" ]]; then
		local current_target
		current_target=$(readlink "$link_dir" 2>/dev/null || true)
		if [[ "$current_target" == "$skills_target" ]]; then
			return 0
		fi
		rm -f "$link_dir"
		ln -s "$skills_target" "$link_dir"
		return 0
	fi

	if [[ -e "$link_dir" ]]; then
		print_warn "superpowers 技能路径已存在且不是符号链接，跳过: $link_dir"
		return 1
	fi

	ln -s "$skills_target" "$link_dir"
}

write_state() {
	local recorded_repo_url
	recorded_repo_url=$(git -C "$clone_dir" remote get-url origin 2>/dev/null || printf '%s' "$repo_url")
	mkdir -p "$(dirname "$state_file")"
	{
		printf 'SUPERPOWERS_REPO_URL=%q\n' "$recorded_repo_url"
		printf 'SUPERPOWERS_CLONE_DIR=%q\n' "$clone_dir"
		printf 'SUPERPOWERS_LINK_DIR=%q\n' "$link_dir"
	} >"$state_file"
	chmod 600 "$state_file"
}

main() {
	command -v git &>/dev/null || {
		print_warn "git 未找到，跳过 superpowers skills 部署"
		return 1
	}

	ensure_clone || return 1

	if [[ ! -d "$skills_target" ]]; then
		print_warn "superpowers 缺少 skills 目录，跳过: $skills_target"
		return 1
	fi

	ensure_link || return 1
	write_state
}

main "$@"
