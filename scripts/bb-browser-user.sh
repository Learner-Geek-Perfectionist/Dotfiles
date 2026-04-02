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

config_file_path() {
	if declare -F bb_browser_config_file &>/dev/null; then
		bb_browser_config_file
	else
		echo "$HOME/.config/dotfiles/bb-browser.json"
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
	local state_file wrapper_path resolved_path preexisting_path

	load_state_file || true
	wrapper_path="$HOME/.local/bin/bb-browser-user"
	resolved_path="${REAL_BB_BROWSER_PATH:-}"
	preexisting_path="${PREEXISTING_BB_BROWSER_PATH:-}"

	if [[ -n "$resolved_path" && -x "$resolved_path" && "$resolved_path" != "$wrapper_path" ]]; then
		printf '%s\n' "$resolved_path"
		return 0
	fi

	if [[ -n "$preexisting_path" && -x "$preexisting_path" && "$preexisting_path" != "$wrapper_path" ]]; then
		printf '%s\n' "$preexisting_path"
		return 0
	fi

	if [[ -n "${PREEXISTING_BB_BROWSER:-}" && "${PREEXISTING_BB_BROWSER}" != "0" && "${PREEXISTING_BB_BROWSER}" != "1" &&
		-x "${PREEXISTING_BB_BROWSER}" && "${PREEXISTING_BB_BROWSER}" != "$wrapper_path" ]]; then
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

require_node() {
	if command -v node &>/dev/null; then
		return 0
	fi

	print_error "node 未找到"
	return 1
}

discover_browser_command() {
	local candidate resolved os_name
	os_name="$(uname -s)"

	case "$os_name" in
	Darwin)
		local mac_candidates=(
			"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
			"/Applications/Google Chrome Dev.app/Contents/MacOS/Google Chrome Dev"
			"/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary"
			"/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta"
			"/Applications/Arc.app/Contents/MacOS/Arc"
			"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
			"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
		)

		for candidate in "${mac_candidates[@]}"; do
			[[ -x "$candidate" ]] || continue
			printf '%s\n' "$candidate"
			return 0
		done
		;;
	Linux)
		local linux_candidates=(
			"google-chrome"
			"google-chrome-stable"
			"microsoft-edge"
			"brave-browser"
			"chromium-browser"
			"chromium"
		)

		for candidate in "${linux_candidates[@]}"; do
			resolved="$(command -v "$candidate" 2>/dev/null || true)"
			[[ -n "$resolved" ]] || continue
			printf '%s\n' "$resolved"
			return 0
		done
		;;
	esac

	return 1
}

configured_port() {
	local config_file port
	config_file="$(config_file_path)"
	port="$(
		node -e '
const fs = require("fs");
const configPath = process.argv[1];
const fallback = "19825";

try {
  if (!configPath || !fs.existsSync(configPath)) {
    process.stdout.write(fallback);
    process.exit(0);
  }

  const raw = fs.readFileSync(configPath, "utf8");
  const config = raw.trim() ? JSON.parse(raw) : {};
  const value = config.port ?? config.remoteDebuggingPort ?? config.cdpPort;
  const parsed = Number.parseInt(String(value ?? ""), 10);
  process.stdout.write(Number.isInteger(parsed) && parsed > 0 ? String(parsed) : fallback);
} catch {
  process.stdout.write(fallback);
}
' "$config_file" 2>/dev/null || true
	)"
	port="${port//$'\n'/}"
	[[ -n "$port" ]] || port="19825"
	printf '%s\n' "$port"
}

configured_profile_directory() {
	local config_file profile_dir
	config_file="$(config_file_path)"
	profile_dir="$(
		node -e '
const fs = require("fs");
const configPath = process.argv[1];
const fallback = "Default";

try {
  if (!configPath || !fs.existsSync(configPath)) {
    process.stdout.write(fallback);
    process.exit(0);
  }

  const raw = fs.readFileSync(configPath, "utf8");
  const config = raw.trim() ? JSON.parse(raw) : {};
  const value = config.profileDirectory ?? config.profileDir ?? config.profile;
  process.stdout.write(typeof value === "string" && value.trim() ? value : fallback);
} catch {
  process.stdout.write(fallback);
}
' "$config_file" 2>/dev/null || true
	)"
	profile_dir="${profile_dir//$'\n'/}"
	[[ -n "$profile_dir" ]] || profile_dir="Default"
	printf '%s\n' "$profile_dir"
}

browser_identity() {
	local browser_command="$1"

	case "$browser_command" in
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
		printf '%s\n' "google-chrome-macos"
		;;
	"/Applications/Google Chrome Dev.app/Contents/MacOS/Google Chrome Dev")
		printf '%s\n' "google-chrome-dev-macos"
		;;
	"/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary")
		printf '%s\n' "google-chrome-canary-macos"
		;;
	"/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta")
		printf '%s\n' "google-chrome-beta-macos"
		;;
	"/Applications/Arc.app/Contents/MacOS/Arc")
		printf '%s\n' "arc-macos"
		;;
	"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge")
		printf '%s\n' "microsoft-edge-macos"
		;;
	"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser")
		printf '%s\n' "brave-browser-macos"
		;;
	*/google-chrome | */google-chrome-stable | google-chrome | google-chrome-stable)
		printf '%s\n' "google-chrome-linux"
		;;
	*/microsoft-edge | microsoft-edge)
		printf '%s\n' "microsoft-edge-linux"
		;;
	*/brave-browser | brave-browser)
		printf '%s\n' "brave-browser-linux"
		;;
	*/chromium-browser | chromium-browser | */chromium | chromium)
		printf '%s\n' "chromium-linux"
		;;
	*)
		return 1
		;;
	esac
}

discover_profile_root() {
	local browser_command="$1"
	local identity

	identity="$(browser_identity "$browser_command" 2>/dev/null || true)"

	case "$identity" in
	google-chrome-macos)
		printf '%s\n' "$HOME/Library/Application Support/Google/Chrome"
		;;
	google-chrome-linux)
		printf '%s\n' "$HOME/.config/google-chrome"
		;;
	google-chrome-dev-macos)
		printf '%s\n' "$HOME/Library/Application Support/Google/Chrome Dev"
		;;
	google-chrome-canary-macos)
		printf '%s\n' "$HOME/Library/Application Support/Google/Chrome Canary"
		;;
	google-chrome-beta-macos)
		printf '%s\n' "$HOME/Library/Application Support/Google/Chrome Beta"
		;;
	arc-macos)
		printf '%s\n' "$HOME/Library/Application Support/Arc"
		;;
	microsoft-edge-macos)
		printf '%s\n' "$HOME/Library/Application Support/Microsoft Edge"
		;;
	microsoft-edge-linux)
		printf '%s\n' "$HOME/.config/microsoft-edge"
		;;
	brave-browser-macos)
		printf '%s\n' "$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
		;;
	brave-browser-linux)
		printf '%s\n' "$HOME/.config/BraveSoftware/Brave-Browser"
		;;
	chromium-linux)
		printf '%s\n' "$HOME/.config/chromium"
		;;
	*)
		return 1
		;;
	esac
}

launch_browser_with_profile() {
	local browser_command="$1"
	local port="$2"
	local profile_root="$3"
	local profile_dir="$4"
	local log_file="/tmp/bb-browser-wrapper.log"

	"$browser_command" \
		"--remote-debugging-port=$port" \
		"--user-data-dir=$profile_root" \
		"--profile-directory=$profile_dir" \
		--no-first-run \
		--no-default-browser-check \
		about:blank >"$log_file" 2>&1 &
}

resolve_cdp_url() {
	local cdp_url browser_command port profile_dir profile_root attempt

	cdp_url="${BB_BROWSER_CDP_URL:-}"
	if [[ -n "$cdp_url" ]] && can_connect_cdp "$cdp_url"; then
		printf '%s\n' "${cdp_url%/}"
		return 0
	fi

	if ! browser_command="$(discover_browser_command)"; then
		print_error "未找到受支持浏览器"
		return 1
	fi

	port="$(configured_port)"
	profile_dir="$(configured_profile_directory)"
	profile_root="$(discover_profile_root "$browser_command" 2>/dev/null || true)"

	if [[ -z "$profile_root" ]]; then
		print_error "无法确定浏览器配置目录: $browser_command"
		return 1
	fi

	if [[ ! -d "$profile_root" ]]; then
		print_error "浏览器配置目录不存在: $profile_root"
		return 1
	fi

	cdp_url="http://127.0.0.1:$port"
	if can_connect_cdp "$cdp_url"; then
		printf '%s\n' "$cdp_url"
		return 0
	fi

	launch_browser_with_profile "$browser_command" "$port" "$profile_root" "$profile_dir"

	for attempt in {1..10}; do
		sleep 1
		if can_connect_cdp "$cdp_url"; then
			printf '%s\n' "$cdp_url"
			return 0
		fi
	done

	print_error "浏览器已启动但 CDP 端口未就绪: $cdp_url"
	return 1
}

doctor() {
	local browser_path

	require_node || return 1

	if ! browser_path="$(real_bb_browser 2>/dev/null)"; then
		print_error "bb-browser 未找到"
		return 1
	fi

	if ! resolve_cdp_url >/dev/null; then
		return 1
	fi

	return 0
}

main() {
	local browser_path cdp_url

	if [[ "${1:-}" == "doctor" ]]; then
		shift || true
		doctor "$@"
		return $?
	fi

	require_node || return 1

	if ! browser_path="$(real_bb_browser 2>/dev/null)"; then
		print_error "bb-browser 未找到"
		return 1
	fi

	cdp_url="$(resolve_cdp_url)" || return 1
	export BB_BROWSER_CDP_URL="$cdp_url"

	exec "$browser_path" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
