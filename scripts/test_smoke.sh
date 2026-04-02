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
			bash "$tmp_home/.local/bin/bb-browser-user" --version
	)"
	assert_equal "bb-browser managed 2.0.0" "$version_output" "wrapper version output"
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
run_test "bb-browser wrapper uses managed path over preexisting path" test_bb_browser_wrapper_uses_managed_path_over_preexisting_path
run_test "Dotfiles uninstall preserves modified files" test_dotfiles_uninstall_preserves_modified_files
run_test "Claude runtime config preserves existing state" test_claude_runtime_config_preserves_existing_state
run_test "Git config identity migrates to local include" test_gitconfig_identity_migrates_to_local
run_test "Dotfiles hook-free fallback" test_dotfiles_hook_free_fallback
run_test "Codex config preserves subprojects" test_codex_config_preserves_projects_and_keeps_home_subprojects
run_test "Pixi prefers managed install" test_pixi_prefers_managed_install_over_system_binary
run_test "Claude optional on macOS" test_claude_optional_on_macos_when_missing
run_test "Claude optional on Linux" test_claude_optional_on_linux_when_install_fails
run_test "Claude known_hosts preserves symlink" test_claude_known_hosts_preserves_symlink
run_test "Claude installs study-master from new repo" test_claude_installs_study_master_from_new_repo
run_test "macOS brew maintenance LaunchAgent" test_macos_brew_maintenance_launchagent_created

section "Done"
pass "Smoke checks completed"
