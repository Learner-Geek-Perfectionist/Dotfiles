#!/bin/bash
# bb-browser wrapper that routes interactive use to the managed binary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_utils() {
	local candidate

	if [[ -n "${DOTFILES_DIR:-}" ]]; then
		candidate="$DOTFILES_DIR/lib/utils.sh"
		if [[ -f "$candidate" ]]; then
			# shellcheck source=/dev/null
			source "$candidate"
			return 0
		fi
	fi

	for candidate in "$SCRIPT_DIR/../lib/utils.sh"; do
		[[ -n "$candidate" && -f "$candidate" ]] || continue
		# shellcheck source=/dev/null
		source "$candidate"
		return 0
	done

	return 1
}

load_utils || true

if ! declare -F print_error &>/dev/null; then
	print_error() {
		printf '%s\n' "$1" >&2
	}
fi

state_file_path() {
	if declare -F bb_browser_state_file &>/dev/null; then
		bb_browser_state_file
	else
		echo "$HOME/.local/state/dotfiles/bb-browser.env"
	fi
}

load_state_file() {
	local state_file
	state_file="$(state_file_path)"

	[[ -f "$state_file" ]] || return 1
	# shellcheck source=/dev/null
	source "$state_file"
	return 0
}

real_bb_browser() {
	local state_file wrapper_path resolved_path

	load_state_file || true
	wrapper_path="$HOME/.local/bin/bb-browser-user"
	resolved_path="${REAL_BB_BROWSER_PATH:-}"

	if [[ -n "$resolved_path" && -x "$resolved_path" && "$resolved_path" != "$wrapper_path" ]]; then
		printf '%s\n' "$resolved_path"
		return 0
	fi

	if [[ -n "${PREEXISTING_BB_BROWSER:-}" && -x "$PREEXISTING_BB_BROWSER" && "$PREEXISTING_BB_BROWSER" != "$wrapper_path" ]]; then
		printf '%s\n' "$PREEXISTING_BB_BROWSER"
		return 0
	fi

	while IFS= read -r candidate; do
		[[ -n "$candidate" && "$candidate" != "$wrapper_path" ]] || continue
		printf '%s\n' "$candidate"
		return 0
	done < <(type -aP bb-browser 2>/dev/null)

	return 1
}

can_connect_cdp() {
	local cdp_url="${1%/}"

	node -e '
const url = (process.argv[1] || "").replace(/\/$/, "");
fetch(`${url}/json/version`, { headers: { accept: "application/json" } })
  .then((response) => process.exit(response.ok ? 0 : 1))
  .catch(() => process.exit(1));
' "$cdp_url"
}

doctor() {
	local browser_path cdp_url

	if ! command -v node &>/dev/null; then
		print_error "node 未找到"
		return 1
	fi

	if ! browser_path="$(real_bb_browser 2>/dev/null)"; then
		print_error "bb-browser 未找到"
		return 1
	fi

	cdp_url="${BB_BROWSER_CDP_URL:-}"
	if [[ -z "$cdp_url" ]]; then
		print_error "BB_BROWSER_CDP_URL 未设置"
		return 1
	fi

	if ! can_connect_cdp "$cdp_url"; then
		print_error "无法连接到 BB_BROWSER_CDP_URL: $cdp_url"
		return 1
	fi

	return 0
}

main() {
	if [[ "${1:-}" == "doctor" ]]; then
		shift || true
		doctor "$@"
		return $?
	fi

	exec "$(real_bb_browser)" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
