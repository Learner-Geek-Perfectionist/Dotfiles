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

load_config_values() {
	[[ "${BB_BROWSER_CONFIG_LOADED:-0}" == "1" ]] && return 0

	local config_file browser port profile_dir
	config_file="$(config_file_path)"

	{
		IFS= read -r browser || true
		IFS= read -r port || true
		IFS= read -r profile_dir || true
	} < <(
		node -e '
const fs = require("fs");
const configPath = process.argv[1];
// Keep Edge as the managed target here.
// Chrome 136+ no longer honors remote-debugging switches on the default data dir
// unless a non-standard --user-data-dir is used, which conflicts with our
// "reuse the real logged-in default profile" requirement.
// Reference: https://developer.chrome.com/blog/remote-debugging-port?hl=zh-cn
const defaults = {
  browser: "microsoft-edge",
  port: "19825",
  profileDirectory: "Default",
};

try {
  if (!configPath || !fs.existsSync(configPath)) {
    process.stdout.write(`${defaults.browser}\n${defaults.port}\n${defaults.profileDirectory}`);
    process.exit(0);
  }

  const raw = fs.readFileSync(configPath, "utf8");
  const config = raw.trim() ? JSON.parse(raw) : {};
  const browser = typeof config.browser === "string" && config.browser.trim() ? config.browser : defaults.browser;
  const portValue = config.port ?? config.remoteDebuggingPort ?? config.cdpPort;
  const parsedPort = Number.parseInt(String(portValue ?? ""), 10);
  const port = Number.isInteger(parsedPort) && parsedPort > 0 ? String(parsedPort) : defaults.port;
  const profileValue = config.profileDirectory ?? config.profileDir ?? config.profile;
  const profileDirectory =
    typeof profileValue === "string" && profileValue.trim() ? profileValue : defaults.profileDirectory;

  process.stdout.write(`${browser}\n${port}\n${profileDirectory}`);
} catch {
  process.stdout.write(`${defaults.browser}\n${defaults.port}\n${defaults.profileDirectory}`);
}
' "$config_file" 2>/dev/null || printf '%s\n%s\n%s\n' "microsoft-edge" "19825" "Default"
	)

	BB_BROWSER_CONFIG_BROWSER="${browser:-microsoft-edge}"
	BB_BROWSER_CONFIG_PORT="${port:-19825}"
	BB_BROWSER_CONFIG_PROFILE_DIRECTORY="${profile_dir:-Default}"
	BB_BROWSER_CONFIG_LOADED=1
}

loopback_host() {
	printf '%s\n' "${BB_BROWSER_LOOPBACK_HOST:-127.0.0.1}"
}

daemon_host() {
	printf '%s\n' "${BB_BROWSER_DAEMON_HOST:-$(loopback_host)}"
}

daemon_port() {
	printf '%s\n' "${BB_BROWSER_DAEMON_PORT:-19824}"
}

daemon_status_url() {
	printf 'http://%s:%s/status\n' "$(daemon_host)" "$(daemon_port)"
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

	if command -v curl &>/dev/null; then
		curl -fsS -H 'accept: application/json' "${cdp_url}/json/version" >/dev/null 2>&1
		return $?
	fi

	node -e '
const url = (process.argv[1] || "").replace(/\/$/, "");
fetch(`${url}/json/version`, { headers: { accept: "application/json" } })
  .then((response) => process.exit(response.ok ? 0 : 1))
  .catch(() => process.exit(1));
' "$cdp_url"
}

daemon_token_file_path() {
	if declare -F bb_browser_daemon_token_file &>/dev/null; then
		bb_browser_daemon_token_file
	else
		echo "$HOME/.bb-browser/daemon.token"
	fi
}

daemon_pid_file_path() {
	if declare -F bb_browser_daemon_pid_file &>/dev/null; then
		bb_browser_daemon_pid_file
	else
		echo "$HOME/.bb-browser/daemon.pid"
	fi
}

daemon_log_file_path() {
	if declare -F bb_browser_daemon_log_file &>/dev/null; then
		bb_browser_daemon_log_file
	else
		echo "/tmp/bb-browser-daemon-wrapper.log"
	fi
}

write_private_file() {
	local target="$1" content="$2" dir tmp previous_umask
	dir="$(dirname "$target")"
	mkdir -p "$dir"

	previous_umask="$(umask)"
	umask 077
	tmp="$(mktemp "$dir/.tmp.XXXXXX")" || {
		umask "$previous_umask"
		return 1
	}
	umask "$previous_umask"

	printf '%s' "$content" >"$tmp" || {
		rm -f "$tmp"
		return 1
	}

	mv -f "$tmp" "$target" || {
		rm -f "$tmp"
		return 1
	}
}

daemon_entry_path_from_real_bb_browser() {
	local real_path="$1" prefix candidate
	[[ -n "$real_path" && "$real_path" == */bin/* ]] || return 1

	prefix="$(dirname "$(dirname "$real_path")")"
	for candidate in \
		"$prefix/lib/node_modules/bb-browser/dist/daemon.js" \
		"$prefix/node_modules/bb-browser/dist/daemon.js"
	do
		if [[ -f "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	return 1
}

daemon_entry_path() {
	local real_path npm_root

	real_path="$(real_bb_browser 2>/dev/null || true)"
	if daemon_entry_path_from_real_bb_browser "$real_path"; then
		return 0
	fi

	npm_root="$(npm root -g 2>/dev/null || true)"
	[[ -n "$npm_root" ]] || return 1

	if [[ -f "$npm_root/bb-browser/dist/daemon.js" ]]; then
		printf '%s\n' "$npm_root/bb-browser/dist/daemon.js"
		return 0
	fi

	return 1
}

daemon_status_ok() {
	local token="$1" status_url
	status_url="$(daemon_status_url)"

	if command -v curl &>/dev/null; then
		curl -fsS -H "Authorization: Bearer ${token}" "$status_url" 2>/dev/null | tr -d '[:space:]' | grep -q '"running":true'
		return $?
	fi

	node -e '
const token = process.argv[1];
const statusUrl = process.argv[2];
fetch(statusUrl, {
  headers: { Authorization: `Bearer ${token}` }
}).then(async (response) => {
  if (!response.ok) process.exit(1);
  const body = await response.json();
  process.exit(body && body.running ? 0 : 1);
}).catch(() => process.exit(1));
' "$token" "$status_url"
}

cdp_host_from_url() {
	local cdp_url="$1" authority
	authority="${cdp_url#*://}"
	authority="${authority%%/*}"

	if [[ "$authority" == \[*\]:* ]]; then
		printf '%s]\n' "${authority%%]:*}"
		return 0
	fi

	if [[ "$authority" == \[*\] ]]; then
		printf '%s\n' "$authority"
		return 0
	fi

	if [[ "$authority" == *:* ]]; then
		printf '%s\n' "${authority%%:*}"
		return 0
	fi

	if [[ -n "$authority" ]]; then
		printf '%s\n' "$authority"
		return 0
	fi

	printf '%s\n' "$(loopback_host)"
}

cdp_port_from_url() {
	local cdp_url="$1" authority
	authority="${cdp_url#*://}"
	authority="${authority%%/*}"

	if [[ "$authority" == \[*\]:* || "$authority" == *:* ]]; then
		printf '%s\n' "${authority##*:}"
		return 0
	fi

	printf '%s\n' "19825"
}

generate_daemon_token() {
	if command -v openssl &>/dev/null; then
		openssl rand -hex 16
		return 0
	fi

	od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
}

daemon_command_matches_pid() {
	local pid="$1" command_line
	[[ "$pid" =~ ^[0-9]+$ ]] || return 1

	command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
	[[ "$command_line" == *"bb-browser/dist/daemon.js"* ]]
}

daemon_command_line_for_pid() {
	local pid="$1"
	[[ "$pid" =~ ^[0-9]+$ ]] || return 1
	ps -p "$pid" -o command= 2>/dev/null || true
}

daemon_matches_runtime_target() {
	local pid="$1" daemon_bind_host="$2" daemon_bind_port="$3" cdp_host="$4" cdp_port="$5"
	local command_line

	command_line="$(daemon_command_line_for_pid "$pid")"
	[[ -n "$command_line" ]] || return 1
	[[ "$command_line" == *"bb-browser/dist/daemon.js"* ]] || return 1
	[[ "$command_line" == *"-H ${daemon_bind_host}"* ]] || return 1
	[[ "$command_line" == *"--cdp-host ${cdp_host}"* ]] || return 1
	[[ "$command_line" == *"--cdp-port ${cdp_port}"* ]] || return 1
	[[ "$command_line" == *"--port ${daemon_bind_port}"* ]] || return 1
}

daemon_pid_list() {
	ps -x -o pid= -o command= 2>/dev/null | awk '/[n]ode .*bb-browser\/dist\/daemon\.js/ { print $1 }'
}

stop_daemon_pid() {
	local pid="$1"
	[[ "$pid" =~ ^[0-9]+$ ]] || return 1

	kill "$pid" >/dev/null 2>&1 || return 0
	for _ in {1..5}; do
		sleep 1
		kill -0 "$pid" >/dev/null 2>&1 || return 0
	done

	kill -9 "$pid" >/dev/null 2>&1 || true
}

stop_existing_daemon() {
	local pid_file pid stopped_pid
	pid_file="$(daemon_pid_file_path)"

	if [[ -f "$pid_file" ]]; then
		pid="$(cat "$pid_file" 2>/dev/null || true)"
		if daemon_command_matches_pid "$pid"; then
			stop_daemon_pid "$pid" || true
			stopped_pid="$pid"
		fi
		rm -f "$pid_file"
	fi

	while IFS= read -r pid; do
		[[ -n "$pid" && "$pid" != "${stopped_pid:-}" ]] || continue
		daemon_command_matches_pid "$pid" || continue
		stop_daemon_pid "$pid" || true
	done < <(daemon_pid_list)
}

ensure_daemon_running() {
	local cdp_url="$1" token_file pid_file token daemon_path cdp_host cdp_port daemon_log pid daemon_bind_host daemon_bind_port

	token_file="$(daemon_token_file_path)"
	pid_file="$(daemon_pid_file_path)"
	cdp_host="$(cdp_host_from_url "$cdp_url")"
	cdp_port="$(cdp_port_from_url "$cdp_url")"
	daemon_bind_host="$(daemon_host)"
	daemon_bind_port="$(daemon_port)"
	if [[ -f "$token_file" ]]; then
		token="$(cat "$token_file" 2>/dev/null || true)"
		pid="$(cat "$pid_file" 2>/dev/null || true)"
		if [[ -n "$token" && -n "$pid" ]] && daemon_matches_runtime_target "$pid" "$daemon_bind_host" "$daemon_bind_port" "$cdp_host" "$cdp_port" &&
			daemon_status_ok "$token"; then
			return 0
		fi
	fi

	daemon_path="$(daemon_entry_path)" || {
		print_error "无法定位 bb-browser daemon.js"
		return 1
	}

	token="$(generate_daemon_token)"
	daemon_log="$(daemon_log_file_path)"

	stop_existing_daemon
	write_private_file "$token_file" "$token" || {
		print_error "无法写入 bb-browser daemon token"
		return 1
	}

	nohup node "$daemon_path" -H "$daemon_bind_host" --cdp-host "$cdp_host" --cdp-port "$cdp_port" --port "$daemon_bind_port" --token "$token" >"$daemon_log" 2>&1 </dev/null &
	pid="$!"
	write_private_file "$pid_file" "$pid" || {
		print_error "无法写入 bb-browser daemon pid"
		stop_existing_daemon
		rm -f "$token_file"
		return 1
	}

	for _ in {1..15}; do
		sleep 1
		if daemon_status_ok "$token"; then
			return 0
		fi
	done

	stop_existing_daemon
	rm -f "$token_file"
	print_error "bb-browser daemon 未能在 ${daemon_bind_host}:${daemon_bind_port} 就绪"
	return 1
}

require_node() {
	if command -v node &>/dev/null; then
		return 0
	fi

	print_error "node 未找到"
	return 1
}

discover_browser_command() {
	local browser_pref candidate resolved os_name
	os_name="$(uname -s)"
	browser_pref="$(configured_browser)"

	case "$os_name" in
	Darwin)
		local mac_candidates=()
		case "$browser_pref" in
		auto)
			mac_candidates=(
				"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
				"/Applications/Google Chrome Dev.app/Contents/MacOS/Google Chrome Dev"
				"/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary"
				"/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta"
				"/Applications/Arc.app/Contents/MacOS/Arc"
				"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
				"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
			)
			;;
		google-chrome | chrome)
			mac_candidates=("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
			;;
		google-chrome-dev | chrome-dev)
			mac_candidates=("/Applications/Google Chrome Dev.app/Contents/MacOS/Google Chrome Dev")
			;;
		google-chrome-canary | chrome-canary)
			mac_candidates=("/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary")
			;;
		google-chrome-beta | chrome-beta)
			mac_candidates=("/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta")
			;;
		arc)
			mac_candidates=("/Applications/Arc.app/Contents/MacOS/Arc")
			;;
		microsoft-edge | edge)
			mac_candidates=("/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge")
			;;
		brave-browser | brave)
			mac_candidates=("/Applications/Brave Browser.app/Contents/MacOS/Brave Browser")
			;;
		*)
			print_error "不支持的浏览器配置: $browser_pref"
			return 1
			;;
		esac

		for candidate in "${mac_candidates[@]}"; do
			[[ -x "$candidate" ]] || continue
			printf '%s\n' "$candidate"
			return 0
		done
		;;
	Linux)
		local linux_candidates=()
		case "$browser_pref" in
		auto)
			linux_candidates=(
				"google-chrome"
				"google-chrome-stable"
				"microsoft-edge"
				"brave-browser"
				"chromium-browser"
				"chromium"
			)
			;;
		google-chrome | chrome)
			linux_candidates=("google-chrome" "google-chrome-stable")
			;;
		microsoft-edge | edge)
			linux_candidates=("microsoft-edge")
			;;
		brave-browser | brave)
			linux_candidates=("brave-browser")
			;;
		chromium)
			linux_candidates=("chromium-browser" "chromium")
			;;
		*)
			print_error "不支持的浏览器配置: $browser_pref"
			return 1
			;;
		esac

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

configured_browser() {
	load_config_values
	printf '%s\n' "$BB_BROWSER_CONFIG_BROWSER"
}

configured_port() {
	load_config_values
	printf '%s\n' "$BB_BROWSER_CONFIG_PORT"
}

configured_profile_directory() {
	load_config_values
	printf '%s\n' "$BB_BROWSER_CONFIG_PROFILE_DIRECTORY"
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

browser_process_name() {
	local browser_command="$1"

	case "$(browser_identity "$browser_command" 2>/dev/null || true)" in
	microsoft-edge-macos)
		printf '%s\n' "Microsoft Edge"
		;;
	microsoft-edge-linux)
		printf '%s\n' "microsoft-edge"
		;;
	*)
		return 1
		;;
	esac
}

browser_running() {
	local process_name="$1"
	[[ -n "$process_name" ]] || return 1
	command -v pgrep &>/dev/null || return 1
	pgrep -x "$process_name" >/dev/null 2>&1
}

browser_pid_list() {
	local process_name="$1"
	[[ -n "$process_name" ]] || return 1
	command -v pgrep &>/dev/null || return 1
	pgrep -x "$process_name" 2>/dev/null || true
}

browser_process_matches_launch_target() {
	local pid="$1" port="$2" profile_root="$3" profile_dir="$4" command_line
	[[ "$pid" =~ ^[0-9]+$ ]] || return 1
	command -v ps &>/dev/null || return 1

	command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
	[[ -n "$command_line" ]] || return 1
	[[ "$command_line" == *"--remote-debugging-port=$port"* ]] || return 1
	[[ "$command_line" == *"--user-data-dir=$profile_root"* ]] || return 1
	[[ "$command_line" == *"--profile-directory=$profile_dir"* ]] || return 1
}

running_browser_matches_launch_target() {
	local process_name="$1" port="$2" profile_root="$3" profile_dir="$4" pid found_pid=0
	[[ -n "$process_name" ]] || return 2
	command -v ps &>/dev/null || return 2

	while IFS= read -r pid; do
		[[ -n "$pid" ]] || continue
		found_pid=1
		if browser_process_matches_launch_target "$pid" "$port" "$profile_root" "$profile_dir"; then
			return 0
		fi
	done < <(browser_pid_list "$process_name")

	[[ "$found_pid" == "1" ]] || return 2
	return 1
}

quit_browser() {
	local browser_command="$1" process_name identity
	process_name="$(browser_process_name "$browser_command" 2>/dev/null || true)"
	identity="$(browser_identity "$browser_command" 2>/dev/null || true)"

	case "$identity" in
	microsoft-edge-macos)
		if command -v osascript &>/dev/null; then
			osascript -e 'tell application "Microsoft Edge" to quit' >/dev/null 2>&1 || true
		fi
		;;
	esac

	if [[ -n "$process_name" ]] && browser_running "$process_name"; then
		if command -v pkill &>/dev/null; then
			pkill -x "$process_name" >/dev/null 2>&1 || true
		fi
	fi

	for _ in {1..15}; do
		sleep 1
		browser_running "$process_name" || return 0
	done

	return 1
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
	local cdp_url browser_command port profile_dir profile_root process_name cdp_target_status

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

	process_name="$(browser_process_name "$browser_command" 2>/dev/null || true)"
	cdp_url="http://$(loopback_host):$port"
	if can_connect_cdp "$cdp_url"; then
		cdp_target_status=2
		if [[ -n "$process_name" ]]; then
			if running_browser_matches_launch_target "$process_name" "$port" "$profile_root" "$profile_dir"; then
				cdp_target_status=0
			else
				cdp_target_status=$?
			fi
		fi

		case "$cdp_target_status" in
		0 | 2)
			printf '%s\n' "$cdp_url"
			return 0
			;;
		esac

		if ! quit_browser "$browser_command"; then
			print_error "退出浏览器失败: $process_name"
			return 1
		fi
	fi

	if [[ -n "$process_name" ]] && browser_running "$process_name"; then
		if ! quit_browser "$browser_command"; then
			print_error "退出浏览器失败: $process_name"
			return 1
		fi
	fi

	launch_browser_with_profile "$browser_command" "$port" "$profile_root" "$profile_dir"

	for _ in {1..15}; do
		sleep 1
		if can_connect_cdp "$cdp_url"; then
			printf '%s\n' "$cdp_url"
			return 0
		fi
	done

	print_error "CDP 端口未就绪: $cdp_url"
	return 1
}

doctor() {
	local browser_path browser_command profile_root

	require_node || return 1

	if ! browser_path="$(real_bb_browser 2>/dev/null)"; then
		print_error "bb-browser 未找到"
		return 1
	fi

	if ! browser_command="$(discover_browser_command)"; then
		print_error "未找到受支持浏览器"
		return 1
	fi

	profile_root="$(discover_profile_root "$browser_command" 2>/dev/null || true)"
	if [[ -z "$profile_root" ]]; then
		print_error "无法确定浏览器配置目录: $browser_command"
		return 1
	fi

	if [[ ! -d "$profile_root" ]]; then
		print_error "浏览器配置目录不存在: $profile_root"
		return 1
	fi

	if ! daemon_entry_path >/dev/null; then
		print_error "无法定位 bb-browser daemon.js"
		return 1
	fi

	configured_port >/dev/null
	configured_profile_directory >/dev/null
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
	ensure_daemon_running "$cdp_url" || return 1

	exec "$browser_path" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
