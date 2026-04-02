#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test_helpers.sh
source "$SCRIPT_DIR/test_helpers.sh"

run_dotfiles_install() {
	local tmp_home="$1" fake_bin="$2" superpowers_repo="$3" log="$4"
	HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" DOTFILES_DIR="$REPO_ROOT" \
		SUPERPOWERS_REPO_URL="$superpowers_repo" bash "$REPO_ROOT/scripts/install_dotfiles.sh" >"$log" 2>&1
}

write_fake_claude_cli() {
	local fake_bin="$1" mcp_list_output="$2" add_json_log="$3" remove_log="$4"
	cat >"$fake_bin/claude" <<EOF
#!/bin/sh
case "\$1" in
  --version)
    echo 'claude 1.0.0'
    exit 0
    ;;
  plugin)
    case "\$2" in
      list)
        exit 0
        ;;
      install|uninstall)
        exit 0
        ;;
      marketplace)
        case "\$3" in
          add|remove)
            exit 0
            ;;
        esac
        ;;
    esac
    ;;
  mcp)
    case "\$2" in
      list)
        cat <<'INNER'
$mcp_list_output
INNER
        exit 0
        ;;
      add)
        exit 0
        ;;
      add-json)
        mkdir -p "$(dirname "$add_json_log")"
        printf '%s\n' "\$4" >"$add_json_log"
        exit 0
        ;;
      remove)
        mkdir -p "$(dirname "$remove_log")"
        printf '%s\n' "\$3" >>"$remove_log"
        exit 0
        ;;
    esac
    ;;
esac
exit 0
EOF
	chmod +x "$fake_bin/claude"
}

test_dotfiles_manifest_and_ssh_block() {
	local tmp_home fake_bin log manifest superpowers_repo superpowers_state
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-dotfiles.log"
	manifest="$tmp_home/.local/state/dotfiles/dotfiles-manifest.tsv"
	superpowers_repo=$(make_fake_superpowers_repo)
	superpowers_state="$tmp_home/.local/state/dotfiles/superpowers.env"
	trap "rm -rf '$tmp_home' '$fake_bin' '$superpowers_repo'" RETURN

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/zsh" "$fake_bin/keychain"

	if ! run_dotfiles_install "$tmp_home" "$fake_bin" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "install_dotfiles.sh failed"
	fi

	assert_file_exists "$manifest"
	assert_contains "$tmp_home/.zshrc" "$manifest"
	assert_contains "$tmp_home/.codex/config.toml" "$manifest"
	assert_contains "$tmp_home/.claude.json" "$manifest"
	assert_contains "$tmp_home/.ssh/config.d/00-dotfiles" "$manifest"
	assert_file_exists "$tmp_home/.codex/config.toml"
	assert_file_exists "$tmp_home/.claude.json"
	assert_file_exists "$superpowers_state"
	assert_symlink "$tmp_home/.agents/skills/superpowers"
	assert_file_exists "$tmp_home/.codex/superpowers/skills/using-superpowers/SKILL.md"
	assert_contains '"autoUpdates": false' "$tmp_home/.claude.json"
	assert_contains 'model = "gpt-5.4"' "$tmp_home/.codex/config.toml"
	assert_contains '[mcp_servers.github]' "$tmp_home/.codex/config.toml"
	assert_contains 'bearer_token_env_var = "GITHUB_PERSONAL_ACCESS_TOKEN"' "$tmp_home/.codex/config.toml"
	assert_file_exists "$tmp_home/.ssh/config"
	assert_contains "# >>> Dotfiles SSH Include >>>" "$tmp_home/.ssh/config"
	assert_contains "Include config.d/*" "$tmp_home/.ssh/config"
}

test_dotfiles_deploys_bb_browser_shell_plugin() {
	local tmp_home fake_bin log manifest superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-dotfiles.log"
	manifest="$tmp_home/.local/state/dotfiles/dotfiles-manifest.tsv"
	superpowers_repo=$(make_fake_superpowers_repo)
	trap "rm -rf '$tmp_home' '$fake_bin' '$superpowers_repo'" RETURN

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/zsh" "$fake_bin/keychain"

	if ! run_dotfiles_install "$tmp_home" "$fake_bin" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "install_dotfiles.sh failed"
	fi

	assert_file_exists "$tmp_home/.config/zsh/plugins/bb-browser.zsh"
	assert_contains 'source "${HOME}/.config/zsh/plugins/bb-browser.zsh"' "$tmp_home/.zshrc"
	assert_contains "$tmp_home/.config/zsh/plugins/bb-browser.zsh" "$manifest"
}

test_bb_browser_install_uses_latest_and_deploys_wrapper() {
	local tmp_home fake_bin log npm_log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser.log"
	npm_log="$tmp_home/npm.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh failed"
	fi

	assert_executable "$tmp_home/.local/bin/bb-browser-user"
	assert_file_exists "$tmp_home/.local/state/dotfiles/bb-browser.env"
	assert_contains "install" "$npm_log"
	assert_contains "bb-browser@latest" "$npm_log"
}

test_bb_browser_install_discovers_browser_and_launches_cdp() {
	local tmp_home fake_bin log npm_log browser_log fetch_log ready_file config_file state_file wrapper_path
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-discovery.log"
	npm_log="$tmp_home/npm-discovery.log"
	browser_log="$tmp_home/google-chrome.log"
	fetch_log="$tmp_home/node-fetch.log"
	ready_file="$tmp_home/.cdp-ready-24444"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$config_file")" "$tmp_home/.config/google-chrome"
	cat >"$config_file" <<'EOF'
{"port":24444,"profileDirectory":"Profile 9"}
EOF

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
script="\$2"
arg="\$3"
case "\$script" in
  *fetch*)
    printf '%s\n' "\$arg" >>"$fetch_log"
    case "\$arg" in
      http://127.0.0.1:24444|http://127.0.0.1:24444/json/version)
        [ -f "$ready_file" ] && exit 0
        exit 1
        ;;
    esac
    exit 1
    ;;
  *config.profileDirectory*)
    /bin/cat <<'INNER'
Profile 9
INNER
    exit 0
    ;;
  *config.port*)
    /bin/cat <<'INNER'
24444
INNER
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/google-chrome" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$browser_log"
port=""
for arg in "\$@"; do
  case "\$arg" in
    --remote-debugging-port=*)
      port="\${arg#--remote-debugging-port=}"
      ;;
  esac
done
[ -n "\$port" ] && : >"$ready_file"
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/google-chrome" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh discovery case failed"
	fi

	assert_executable "$wrapper_path"
	assert_file_exists "$state_file"
	assert_contains "http://127.0.0.1:24444" "$fetch_log"
	assert_contains "remote-debugging-port=24444" "$browser_log"
	assert_contains "user-data-dir=$tmp_home/.config/google-chrome" "$browser_log"
	assert_contains "profile-directory=Profile 9" "$browser_log"
	assert_contains "about:blank" "$browser_log"
}

test_bb_browser_install_fails_without_supported_browser() {
	local tmp_home fake_bin log npm_log tool
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-no-browser.log"
	npm_log="$tmp_home/npm-no-browser.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	for tool in basename cat chmod cp date dirname mkdir rm sleep whoami; do
		ln -s "$(command -v "$tool")" "$fake_bin/$tool"
	done

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/uname"

	if HOME="$tmp_home" PATH="$fake_bin" \
		/bin/bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh unexpectedly succeeded without supported browser"
	fi

	assert_contains "install" "$npm_log"
	assert_contains "bb-browser@latest" "$npm_log"
	assert_contains "未找到受支持浏览器" "$log"
	assert_file_missing "$tmp_home/.local/bin/bb-browser-user"
	assert_file_missing "$tmp_home/.local/state/dotfiles/bb-browser.env"
}

test_bb_browser_wrapper_uses_managed_path_over_preexisting_path() {
	local tmp_home old_bin managed_prefix fake_bin log npm_log state_file
	tmp_home=$(make_temp_dir)
	old_bin=$(make_temp_dir)
	managed_prefix=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-conflict.log"
	npm_log="$tmp_home/npm-conflict.log"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	trap "rm -rf '$tmp_home' '$old_bin' '$managed_prefix' '$fake_bin'" RETURN

	cat >"$old_bin/bb-browser" <<'EOF'
#!/bin/sh
echo "old-bb-browser" >&2
exit 33
EOF
	chmod +x "$old_bin/bb-browser"

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "bin" ] && [ "\$2" = "-g" ]; then
  echo 'Unknown command: "bin"' >&2
  exit 1
fi
if [ "\$1" = "prefix" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$managed_prefix"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  mkdir -p "$managed_prefix/bin"
	cat >"$managed_prefix/bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser managed 2.0.0' ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$managed_prefix/bin/bb-browser"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node"

	if ! HOME="$tmp_home" PATH="$old_bin:$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh conflict case failed"
	fi

	assert_file_exists "$state_file"
	assert_contains "$old_bin/bb-browser" "$state_file"
	assert_contains "$managed_prefix/bin/bb-browser" "$state_file"
	assert_contains 'PREEXISTING_BB_BROWSER=' "$state_file"
	assert_contains 'REAL_BB_BROWSER_PATH=' "$state_file"
	assert_contains "prefix -g" "$npm_log"
	assert_not_contains "bin -g" "$npm_log"

	resolved_path="$(
		HOME="$tmp_home" PATH="$old_bin:$managed_prefix/bin:$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			bash -c "source '$REPO_ROOT/scripts/bb-browser-user.sh'; real_bb_browser"
	)"
	assert_equal "$managed_prefix/bin/bb-browser" "$resolved_path" "managed bb-browser path"

	version_output="$(
		HOME="$tmp_home" PATH="$old_bin:$managed_prefix/bin:$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
			bash "$tmp_home/.local/bin/bb-browser-user" --version
	)"
	assert_equal "bb-browser managed 2.0.0" "$version_output" "wrapper version output"
}

test_bb_browser_uninstall_preserves_preexisting_global_install() {
	local tmp_home fake_bin log npm_log wrapper_path config_file state_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-bb-browser-preexisting.log"
	npm_log="$tmp_home/npm-preexisting.log"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$config_file")" "$(dirname "$state_file")"
	cat >"$wrapper_path" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$wrapper_path"
	cat >"$config_file" <<'EOF'
{"managed":true}
EOF
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=1
INSTALLED_VERSION=9.9.9
WRAPPER_PATH=$wrapper_path
REAL_BB_BROWSER_PATH=/usr/local/bin/bb-browser
EOF

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
mkdir -p "$(dirname "$npm_log")"
printf '%s\n' "\$*" >>"$npm_log"
exit 0
EOF
	chmod +x "$fake_bin/npm"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh bb-browser preexisting case failed"
	fi

	assert_file_missing "$wrapper_path"
	assert_file_missing "$config_file"
	assert_file_missing "$state_file"
	assert_file_missing "$npm_log"
}

test_bb_browser_uninstall_removes_managed_global_install() {
	local tmp_home fake_bin log npm_log wrapper_path config_file state_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-bb-browser-managed.log"
	npm_log="$tmp_home/npm-managed.log"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$config_file")" "$(dirname "$state_file")"
	cat >"$wrapper_path" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$wrapper_path"
	cat >"$config_file" <<'EOF'
{"managed":true}
EOF
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=0
INSTALLED_VERSION=9.9.9
WRAPPER_PATH=$wrapper_path
REAL_BB_BROWSER_PATH=/usr/local/bin/bb-browser
EOF

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
mkdir -p "$(dirname "$npm_log")"
printf '%s\n' "\$*" >>"$npm_log"
exit 0
EOF
	chmod +x "$fake_bin/npm"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh bb-browser managed case failed"
	fi

	assert_file_missing "$wrapper_path"
	assert_file_missing "$config_file"
	assert_file_missing "$state_file"
	assert_file_exists "$npm_log"
	assert_contains "uninstall" "$npm_log"
	assert_contains "bb-browser" "$npm_log"
}

test_bb_browser_uninstall_skips_missing_or_empty_preexisting_marker() {
	local tmp_home_missing tmp_home_empty fake_bin log_missing log_empty npm_log_missing npm_log_empty wrapper_path config_file state_file
	tmp_home_missing=$(make_temp_dir)
	tmp_home_empty=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log_missing="$tmp_home_missing/uninstall-bb-browser-missing.log"
	log_empty="$tmp_home_empty/uninstall-bb-browser-empty.log"
	npm_log_missing="$tmp_home_missing/npm-missing.log"
	npm_log_empty="$tmp_home_empty/npm-empty.log"
	trap "rm -rf '$tmp_home_missing' '$tmp_home_empty' '$fake_bin'" RETURN

	write_fake_npm_bb_browser_stub() {
		local npm_path="$1" npm_log="$2"
		cat >"$npm_path" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "prefix" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "/opt/current-prefix"
  exit 0
fi
if [ "\$1" = "config" ] && [ "\$2" = "get" ] && [ "\$3" = "prefix" ]; then
  printf '%s\n' "/opt/current-prefix"
  exit 0
fi
exit 0
EOF
		chmod +x "$npm_path"
	}

	# Missing PREEXISTING_BB_BROWSER
	wrapper_path="$tmp_home_missing/.local/bin/bb-browser-user"
	config_file="$tmp_home_missing/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home_missing/.local/state/dotfiles/bb-browser.env"
	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$config_file")" "$(dirname "$state_file")"
	cat >"$wrapper_path" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$wrapper_path"
	cat >"$config_file" <<'EOF'
{"managed":true}
EOF
	cat >"$state_file" <<EOF
REAL_BB_BROWSER_PATH=/opt/original-prefix/bin/bb-browser
EOF
	write_fake_npm_bb_browser_stub "$fake_bin/npm" "$npm_log_missing"

	if ! HOME="$tmp_home_missing" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log_missing" 2>&1; then
		cat "$log_missing" >&2
		fail "uninstall.sh bb-browser missing marker case failed"
	fi

	assert_file_missing "$wrapper_path"
	assert_file_missing "$config_file"
	assert_file_missing "$state_file"
	assert_file_missing "$npm_log_missing"

	# Empty PREEXISTING_BB_BROWSER
	wrapper_path="$tmp_home_empty/.local/bin/bb-browser-user"
	config_file="$tmp_home_empty/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home_empty/.local/state/dotfiles/bb-browser.env"
	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$config_file")" "$(dirname "$state_file")"
	cat >"$wrapper_path" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$wrapper_path"
	cat >"$config_file" <<'EOF'
{"managed":true}
EOF
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=
REAL_BB_BROWSER_PATH=/opt/original-prefix/bin/bb-browser
EOF
	write_fake_npm_bb_browser_stub "$fake_bin/npm" "$npm_log_empty"

	if ! HOME="$tmp_home_empty" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log_empty" 2>&1; then
		cat "$log_empty" >&2
		fail "uninstall.sh bb-browser empty marker case failed"
	fi

	assert_file_missing "$wrapper_path"
	assert_file_missing "$config_file"
	assert_file_missing "$state_file"
	assert_file_missing "$npm_log_empty"
}

test_bb_browser_uninstall_targets_recorded_prefix_on_drift() {
	local tmp_home fake_bin log npm_log wrapper_path config_file state_file original_prefix current_prefix
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	original_prefix=$(make_temp_dir)
	current_prefix=$(make_temp_dir)
	log="$tmp_home/uninstall-bb-browser-prefix-drift.log"
	npm_log="$tmp_home/npm-prefix-drift.log"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	trap "rm -rf '$tmp_home' '$fake_bin' '$original_prefix' '$current_prefix'" RETURN

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$config_file")" "$(dirname "$state_file")"
	cat >"$wrapper_path" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$wrapper_path"
	cat >"$config_file" <<'EOF'
{"managed":true}
EOF
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=0
INSTALLED_VERSION=9.9.9
WRAPPER_PATH=$wrapper_path
REAL_BB_BROWSER_PATH=$original_prefix/bin/bb-browser
EOF

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "prefix" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$current_prefix"
  exit 0
fi
if [ "\$1" = "config" ] && [ "\$2" = "get" ] && [ "\$3" = "prefix" ]; then
  printf '%s\n' "$current_prefix"
  exit 0
fi
exit 0
EOF
	chmod +x "$fake_bin/npm"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh bb-browser prefix drift case failed"
	fi

	assert_file_missing "$wrapper_path"
	assert_file_missing "$config_file"
	assert_file_missing "$state_file"
	assert_contains "$original_prefix" "$npm_log"
	assert_contains "uninstall" "$npm_log"
	assert_contains "bb-browser" "$npm_log"
	assert_not_contains "$current_prefix" "$npm_log"
}

test_dotfiles_uninstall_preserves_modified_files() {
	local tmp_home fake_bin install_log uninstall_log superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	install_log="$tmp_home/install-dotfiles.log"
	uninstall_log="$tmp_home/uninstall-dotfiles.log"
	superpowers_repo=$(make_fake_superpowers_repo)
	trap "rm -rf '$tmp_home' '$fake_bin' '$superpowers_repo'" RETURN

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/zsh" "$fake_bin/keychain"

	if ! run_dotfiles_install "$tmp_home" "$fake_bin" "$superpowers_repo" "$install_log"; then
		cat "$install_log" >&2
		fail "install_dotfiles.sh failed"
	fi

	printf '\n# user change\n' >>"$tmp_home/.zshrc"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$uninstall_log" 2>&1; then
		cat "$uninstall_log" >&2
		fail "uninstall.sh --dotfiles failed"
	fi

	assert_file_exists "$tmp_home/.zshrc"
	assert_file_missing "$tmp_home/.gitconfig"
	assert_file_missing "$tmp_home/.codex/config.toml"
	assert_file_missing "$tmp_home/.codex/superpowers"
	assert_file_missing "$tmp_home/.agents/skills/superpowers"
	assert_file_missing "$tmp_home/.local/state/dotfiles/superpowers.env"
	assert_file_exists "$tmp_home/.claude.json"
	assert_file_exists "$tmp_home/.claude/settings.json"
	if [[ -f "$tmp_home/.ssh/config" ]]; then
		assert_not_contains "# >>> Dotfiles SSH Include >>>" "$tmp_home/.ssh/config"
	fi
}

test_claude_runtime_config_preserves_existing_state() {
	local tmp_home fake_bin log superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-runtime-config.log"
	superpowers_repo=$(make_fake_superpowers_repo)
	trap "rm -rf '$tmp_home' '$fake_bin' '$superpowers_repo'" RETURN

	cat >"$tmp_home/.claude.json" <<'EOF'
{
  "numStartups": 42,
  "installMethod": "native",
  "autoUpdates": true
}
EOF

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/zsh" "$fake_bin/keychain"

	if ! run_dotfiles_install "$tmp_home" "$fake_bin" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "install_dotfiles.sh runtime config merge failed"
	fi

	assert_contains '"numStartups": 42' "$tmp_home/.claude.json"
	assert_contains '"installMethod": "native"' "$tmp_home/.claude.json"
	assert_contains '"autoUpdates": false' "$tmp_home/.claude.json"
}

test_gitconfig_identity_migrates_to_local() {
	local tmp_home fake_bin install_log uninstall_log superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	install_log="$tmp_home/install-gitconfig.log"
	uninstall_log="$tmp_home/uninstall-gitconfig.log"
	superpowers_repo=$(make_fake_superpowers_repo)
	trap "rm -rf '$tmp_home' '$fake_bin' '$superpowers_repo'" RETURN

	cat >"$tmp_home/.gitconfig" <<'EOF'
[user]
	name = Legacy User
	email = legacy@example.com
EOF

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/zsh" "$fake_bin/keychain"

	if ! run_dotfiles_install "$tmp_home" "$fake_bin" "$superpowers_repo" "$install_log"; then
		cat "$install_log" >&2
		fail "install_dotfiles.sh gitconfig migration failed"
	fi

	assert_file_exists "$tmp_home/.gitconfig"
	assert_file_exists "$tmp_home/.gitconfig.local"
	assert_contains "[include]" "$tmp_home/.gitconfig"
	assert_contains "path = ~/.gitconfig.local" "$tmp_home/.gitconfig"
	assert_contains "name = Legacy User" "$tmp_home/.gitconfig.local"
	assert_contains "email = legacy@example.com" "$tmp_home/.gitconfig.local"
	assert_not_contains "Legacy User" "$tmp_home/.gitconfig"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$uninstall_log" 2>&1; then
		cat "$uninstall_log" >&2
		fail "uninstall.sh gitconfig preservation failed"
	fi

	assert_file_missing "$tmp_home/.gitconfig"
	assert_file_exists "$tmp_home/.gitconfig.local"
	assert_contains "name = Legacy User" "$tmp_home/.gitconfig.local"
}

test_dotfiles_hook_free_fallback() {
	local tmp_home fake_bin log superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-fallback.log"
	superpowers_repo=$(make_fake_superpowers_repo)
	trap "rm -rf '$tmp_home' '$fake_bin' '$superpowers_repo'" RETURN

	cat >"$fake_bin/jq" <<'EOF'
#!/bin/sh
exit 1
EOF
	cat >"$fake_bin/python3" <<'EOF'
#!/bin/sh
exit 1
EOF
	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/jq" "$fake_bin/python3" "$fake_bin/zsh" "$fake_bin/keychain"

	if ! run_dotfiles_install "$tmp_home" "$fake_bin" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "install_dotfiles.sh fallback failed"
	fi

	assert_file_exists "$tmp_home/.claude/settings.json"
	assert_file_exists "$tmp_home/.claude.json"
	assert_contains '"autoUpdates": false' "$tmp_home/.claude.json"
	assert_not_contains "PostToolUse" "$tmp_home/.claude/settings.json"
}

test_codex_config_preserves_projects_and_keeps_home_subprojects() {
	local tmp_home fake_bin log external_project child_project superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-codex.log"
	external_project="/tmp/codex-external-project"
	child_project="$tmp_home/redundant-project"
	superpowers_repo=$(make_fake_superpowers_repo)
	trap "rm -rf '$tmp_home' '$fake_bin' '$superpowers_repo'" RETURN

	mkdir -p "$tmp_home/.codex"
	cat >"$tmp_home/.codex/config.toml" <<EOF
model = "legacy"

[projects."$external_project"]
trust_level = "trusted"

[projects."$child_project"]
trust_level = "trusted"
EOF

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/zsh" "$fake_bin/keychain"

	if ! run_dotfiles_install "$tmp_home" "$fake_bin" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "install_dotfiles.sh codex merge failed"
	fi

	assert_contains 'model = "gpt-5.4"' "$tmp_home/.codex/config.toml"
	assert_contains '[mcp_servers.openaiDeveloperDocs]' "$tmp_home/.codex/config.toml"
	assert_contains 'url = "https://developers.openai.com/mcp"' "$tmp_home/.codex/config.toml"
	assert_contains '[mcp_servers.github]' "$tmp_home/.codex/config.toml"
	assert_contains 'url = "https://api.githubcopilot.com/mcp/"' "$tmp_home/.codex/config.toml"
	assert_contains 'bearer_token_env_var = "GITHUB_PERSONAL_ACCESS_TOKEN"' "$tmp_home/.codex/config.toml"
	assert_contains '[mcp_servers.tavily]' "$tmp_home/.codex/config.toml"
	assert_contains 'args = ["-y", "tavily-mcp"]' "$tmp_home/.codex/config.toml"
	assert_contains 'env_vars = ["TAVILY_API_KEY"]' "$tmp_home/.codex/config.toml"
	assert_contains '[mcp_servers.fetch]' "$tmp_home/.codex/config.toml"
	assert_contains 'args = ["-y", "@kazuph/mcp-fetch"]' "$tmp_home/.codex/config.toml"
	assert_contains '[mcp_servers.bb-browser]' "$tmp_home/.codex/config.toml"
	assert_contains 'command = "bash"' "$tmp_home/.codex/config.toml"
	assert_contains 'args = ["-c", "\"$HOME/.local/bin/bb-browser-user\" --mcp"]' "$tmp_home/.codex/config.toml"
	assert_not_contains 'args = ["-lc",' "$tmp_home/.codex/config.toml"
	assert_contains "[projects.\"$external_project\"]" "$tmp_home/.codex/config.toml"
	assert_contains "[projects.\"$tmp_home\"]" "$tmp_home/.codex/config.toml"
	assert_contains "[projects.\"$child_project\"]" "$tmp_home/.codex/config.toml"
}

test_pixi_prefers_managed_install_over_system_binary() {
	local tmp_home fake_bin log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-pixi.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/pixi" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 'pixi system 1.0.0' ;;
  install|list) exit 0 ;;
  *) exit 0 ;;
esac
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
cat <<'INNER'
#!/bin/sh
mkdir -p "$HOME/.pixi/bin"
cat >"$HOME/.pixi/bin/pixi" <<'EOF_PIXI'
#!/bin/sh
case "$1" in
  --version) echo 'pixi managed 2.0.0' ;;
  install|list) exit 0 ;;
  *) exit 0 ;;
esac
EOF_PIXI
chmod +x "$HOME/.pixi/bin/pixi"
INNER
EOF
	chmod +x "$fake_bin/pixi" "$fake_bin/curl"

	cat >"$tmp_home/pixi.toml" <<'EOF'
[workspace]
name = "home"
channels = ["conda-forge"]
platforms = ["linux-64"]
EOF

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" SHELL=/bin/zsh \
		bash "$REPO_ROOT/scripts/install_pixi.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_pixi.sh failed"
	fi

	assert_executable "$tmp_home/.pixi/bin/pixi"
	assert_contains "Pixi 已可用: pixi managed 2.0.0" "$log"
}

test_claude_optional_on_macos_when_missing() {
	local tmp_home fake_bin log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-macos.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
if [ "$1" = "-s" ]; then
  echo Darwin
else
  echo arm64
fi
EOF
	cat >"$fake_bin/rustup" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/npm" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/dotnet" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/uname" "$fake_bin/rustup" "$fake_bin/npm" "$fake_bin/dotnet" "$fake_bin/curl"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_claude_code.sh should be optional on macOS"
	fi

	assert_contains "跳过 Claude 插件/MCP 配置" "$log"
}

test_claude_optional_on_linux_when_install_fails() {
	local tmp_home fake_bin log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-linux.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
if [ "$1" = "-s" ]; then
  echo Linux
else
  echo x86_64
fi
EOF
	cat >"$fake_bin/rustup" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/npm" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/dotnet" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
exit 99
EOF
	chmod +x "$fake_bin/uname" "$fake_bin/rustup" "$fake_bin/npm" "$fake_bin/dotnet" "$fake_bin/curl"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_claude_code.sh should be optional on Linux"
	fi

	assert_contains "Claude Code CLI 安装失败，跳过 Claude 插件/MCP 配置" "$log"
}

test_claude_installs_bb_browser_mcp() {
	local tmp_home fake_bin log mcp_log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-bb-browser.log"
	mcp_log="$tmp_home/claude-mcp-add-json.json"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli "$fake_bin" $'tavily: stdio\nfetch: stdio' "$mcp_log" "$tmp_home/claude-mcp-remove.log"

	cat >"$fake_bin/rustup" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/npm" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/dotnet" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/git" <<'EOF'
#!/bin/sh
if [ "$1" = "clone" ] && [ "$2" = "--depth" ] && [ "$3" = "1" ]; then
  dest="$5"
  mkdir -p "$dest/study-master-skill/hooks"
  printf '# study-master\n' >"$dest/study-master-skill/SKILL.md"
  printf '#!/bin/sh\nexit 0\n' >"$dest/study-master-skill/hooks/check-study_master.sh"
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/rustup" "$fake_bin/npm" "$fake_bin/dotnet" "$fake_bin/curl" "$fake_bin/git" "$fake_bin/zsh" "$fake_bin/keychain"

	mkdir -p "$tmp_home/.local/bin" "$tmp_home/.claude/skills/study-master"
	cat >"$tmp_home/.local/bin/bb-browser-user" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$tmp_home/.local/bin/bb-browser-user"
	printf '# study-master\n' >"$tmp_home/.claude/skills/study-master/SKILL.md"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_claude_code.sh bb-browser MCP test failed"
	fi

	assert_file_exists "$mcp_log"
	assert_contains 'bb-browser-user' "$mcp_log"
	assert_contains "$tmp_home/.local/bin/bb-browser-user" "$mcp_log"
	grep -qF -- '--mcp' "$mcp_log" || fail "Expected '--mcp' in $mcp_log"
	assert_contains '"command": "bash"' "$mcp_log"
	assert_contains "\"-c\", \"\\\"$tmp_home/.local/bin/bb-browser-user\\\" --mcp\"" "$mcp_log"
	! grep -qF -- '-lc' "$mcp_log" || fail "Did not expect '-lc' in $mcp_log"
}

test_uninstall_claude_removes_bb_browser_mcp() {
	local tmp_home fake_bin log remove_log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-claude-bb-browser.log"
	remove_log="$tmp_home/claude-mcp-remove.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli "$fake_bin" $'bb-browser: stdio\nfetch: stdio' "$tmp_home/claude-mcp-add-json.json" "$remove_log"

	cat >"$fake_bin/jq" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/jq"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --claude --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh --claude failed"
	fi

	assert_file_exists "$remove_log"
	assert_contains "bb-browser" "$remove_log"
}

test_claude_known_hosts_preserves_symlink() {
	local tmp_home fake_bin log real_known_hosts
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-known-hosts.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/claude" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 'claude 1.0.0'; exit 0 ;;
  plugin)
    case "$2" in
      list|install|uninstall) exit 0 ;;
      marketplace) exit 0 ;;
    esac
    ;;
  mcp)
    case "$2" in
      list|add|add-json|remove) exit 0 ;;
    esac
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/rustup" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/npm" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/dotnet" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/claude" "$fake_bin/rustup" "$fake_bin/npm" "$fake_bin/dotnet" "$fake_bin/curl"

	mkdir -p "$tmp_home/.ssh" "$tmp_home/.claude/skills/study-master"
	printf '# stub\n' >"$tmp_home/.claude/skills/study-master/SKILL.md"
	real_known_hosts="$tmp_home/shared-known-hosts"
	printf 'existing.example ssh-ed25519 AAAAOLD\n' >"$real_known_hosts"
	ln -s "$real_known_hosts" "$tmp_home/.ssh/known_hosts"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_claude_code.sh symlink known_hosts test failed"
	fi

	assert_symlink "$tmp_home/.ssh/known_hosts"
	assert_grep '^github.com ssh-ed25519 ' "$real_known_hosts"
	assert_file_exists "$tmp_home/.claude.json"
	assert_contains '"autoUpdates": false' "$tmp_home/.claude.json"
}

test_claude_installs_study_master_from_new_repo() {
	local tmp_home fake_bin log expected_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-study-master.log"
	expected_repo="https://github.com/Learner-Geek-Perfectionist/agent-study-skills.git"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/claude" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 'claude 1.0.0'; exit 0 ;;
  plugin)
    case "$2" in
      list|install|uninstall) exit 0 ;;
      marketplace) exit 0 ;;
    esac
    ;;
  mcp)
    case "$2" in
      list|add|add-json|remove) exit 0 ;;
    esac
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/rustup" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/npm" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/dotnet" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/git" <<EOF
#!/bin/sh
if [ "\$1" = "clone" ] && [ "\$2" = "--depth" ] && [ "\$3" = "1" ] && [ "\$4" = "$expected_repo" ]; then
  dest="\$5"
  mkdir -p "\$dest/study-master-skill/hooks"
  printf '# study-master\\n' >"\$dest/study-master-skill/SKILL.md"
  printf '#!/bin/sh\\nexit 0\\n' >"\$dest/study-master-skill/hooks/check-study_master.sh"
  exit 0
fi
exit 1
EOF
	chmod +x "$fake_bin/claude" "$fake_bin/rustup" "$fake_bin/npm" "$fake_bin/dotnet" "$fake_bin/curl" "$fake_bin/git"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_claude_code.sh study-master repo test failed"
	fi

	assert_file_exists "$tmp_home/.claude/skills/study-master/SKILL.md"
	assert_file_exists "$tmp_home/.claude/hooks/check-study_master.sh"
	assert_contains "study-master Skill 安装完成" "$log"
}

test_macos_brew_maintenance_launchagent_created() {
	local tmp_home fake_bin log plist script legacy_cleanup_plist legacy_autoupdate_plist
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/macos-install.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/xcode-select" <<'EOF'
#!/bin/sh
case "$1" in
  --version) exit 0 ;;
  -p) echo /Library/Developer/CommandLineTools; exit 0 ;;
  --install|--reset) exit 0 ;;
esac
exit 0
EOF
	cat >"$fake_bin/brew" <<'EOF'
#!/bin/sh
cmd="$1"
shift || true
case "$cmd" in
  tap)
    if [ $# -eq 0 ]; then
      exit 0
    fi
    exit 0
    ;;
  list)
    exit 0
    ;;
  ls)
    exit 1
    ;;
  install|cleanup|update|upgrade)
    exit 0
    ;;
  autoupdate)
    case "$1" in
      delete) exit 0 ;;
    esac
    ;;
  commands)
    echo autoupdate
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/launchctl" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/dscl" <<'EOF'
#!/bin/sh
exit 1
EOF
	chmod +x "$fake_bin/xcode-select" "$fake_bin/brew" "$fake_bin/launchctl" "$fake_bin/dscl"

	legacy_cleanup_plist="$tmp_home/Library/LaunchAgents/com.dotfiles.brew-cleanup.plist"
	legacy_autoupdate_plist="$tmp_home/Library/LaunchAgents/com.github.domt4.homebrew-autoupdate.plist"
	mkdir -p "$(dirname "$legacy_cleanup_plist")"
	printf 'legacy cleanup\n' >"$legacy_cleanup_plist"
	printf 'legacy autoupdate\n' >"$legacy_autoupdate_plist"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_macos.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_macos.sh failed"
	fi

	plist="$tmp_home/Library/LaunchAgents/com.dotfiles.brew-maintenance.plist"
	script="$tmp_home/Library/Application Support/com.dotfiles/brew-maintenance.sh"
	assert_file_exists "$plist"
	assert_file_exists "$script"
	assert_contains "<string>com.dotfiles.brew-maintenance</string>" "$plist"
	assert_contains "<string>/bin/bash</string>" "$plist"
	assert_contains "$script" "$plist"
	assert_contains 'upgrade --formula -v' "$script"
	assert_contains 'upgrade --cask -v --greedy' "$script"
	assert_contains 'cleanup --prune=all' "$script"
	assert_file_missing "$legacy_cleanup_plist"
	assert_file_missing "$legacy_autoupdate_plist"
}

run_test "Dotfiles manifest and SSH include block" test_dotfiles_manifest_and_ssh_block
run_test "Dotfiles deploys bb-browser shell plugin" test_dotfiles_deploys_bb_browser_shell_plugin
run_test "bb-browser install uses latest and deploys wrapper" test_bb_browser_install_uses_latest_and_deploys_wrapper
run_test "bb-browser install discovers browser and launches CDP" test_bb_browser_install_discovers_browser_and_launches_cdp
run_test "bb-browser install fails without supported browser" test_bb_browser_install_fails_without_supported_browser
run_test "bb-browser wrapper uses managed path over preexisting path" test_bb_browser_wrapper_uses_managed_path_over_preexisting_path
run_test "bb-browser uninstall preserves preexisting global install" test_bb_browser_uninstall_preserves_preexisting_global_install
run_test "bb-browser uninstall removes managed global install" test_bb_browser_uninstall_removes_managed_global_install
run_test "bb-browser uninstall skips missing or empty preexisting marker" test_bb_browser_uninstall_skips_missing_or_empty_preexisting_marker
run_test "bb-browser uninstall targets recorded prefix on drift" test_bb_browser_uninstall_targets_recorded_prefix_on_drift
run_test "Dotfiles uninstall preserves modified files" test_dotfiles_uninstall_preserves_modified_files
run_test "Claude runtime config preserves existing state" test_claude_runtime_config_preserves_existing_state
run_test "Git config identity migrates to local include" test_gitconfig_identity_migrates_to_local
run_test "Dotfiles hook-free fallback" test_dotfiles_hook_free_fallback
run_test "Codex config preserves subprojects" test_codex_config_preserves_projects_and_keeps_home_subprojects
run_test "Pixi prefers managed install" test_pixi_prefers_managed_install_over_system_binary
run_test "Claude optional on macOS" test_claude_optional_on_macos_when_missing
run_test "Claude optional on Linux" test_claude_optional_on_linux_when_install_fails
run_test "Claude installs bb-browser MCP" test_claude_installs_bb_browser_mcp
run_test "Claude uninstall removes bb-browser MCP" test_uninstall_claude_removes_bb_browser_mcp
run_test "Claude known_hosts preserves symlink" test_claude_known_hosts_preserves_symlink
run_test "Claude installs study-master from new repo" test_claude_installs_study_master_from_new_repo
run_test "macOS brew maintenance LaunchAgent" test_macos_brew_maintenance_launchagent_created

section "Done"
pass "Smoke checks completed"
