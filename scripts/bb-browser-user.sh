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

real_bb_browser() {
	command -v bb-browser
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

main "$@"
