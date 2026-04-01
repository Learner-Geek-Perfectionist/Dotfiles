#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test_helpers.sh
source "$SCRIPT_DIR/test_helpers.sh"

test_dotfiles_manifest_and_ssh_block() {
	local tmp_home fake_bin log manifest
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-dotfiles.log"
	manifest="$tmp_home/.local/state/dotfiles/dotfiles-manifest.tsv"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/zsh" "$fake_bin/keychain"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" DOTFILES_DIR="$REPO_ROOT" \
		bash "$REPO_ROOT/scripts/install_dotfiles.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_dotfiles.sh failed"
	fi

	assert_file_exists "$manifest"
	assert_contains "$tmp_home/.zshrc" "$manifest"
	assert_contains "$tmp_home/.codex/config.toml" "$manifest"
	assert_contains "$tmp_home/.ssh/config.d/00-dotfiles" "$manifest"
	assert_file_exists "$tmp_home/.codex/config.toml"
	assert_contains 'model = "gpt-5.4"' "$tmp_home/.codex/config.toml"
	assert_file_exists "$tmp_home/.ssh/config"
	assert_contains "# >>> Dotfiles SSH Include >>>" "$tmp_home/.ssh/config"
	assert_contains "Include config.d/*" "$tmp_home/.ssh/config"
}

test_dotfiles_uninstall_preserves_modified_files() {
	local tmp_home fake_bin install_log uninstall_log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	install_log="$tmp_home/install-dotfiles.log"
	uninstall_log="$tmp_home/uninstall-dotfiles.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/keychain" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$fake_bin/zsh" "$fake_bin/keychain"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" DOTFILES_DIR="$REPO_ROOT" \
		bash "$REPO_ROOT/scripts/install_dotfiles.sh" >"$install_log" 2>&1; then
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
	assert_file_exists "$tmp_home/.claude/settings.json"
	if [[ -f "$tmp_home/.ssh/config" ]]; then
		assert_not_contains "# >>> Dotfiles SSH Include >>>" "$tmp_home/.ssh/config"
	fi
}

test_dotfiles_hook_free_fallback() {
	local tmp_home fake_bin log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-fallback.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

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

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" DOTFILES_DIR="$REPO_ROOT" \
		bash "$REPO_ROOT/scripts/install_dotfiles.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_dotfiles.sh fallback failed"
	fi

	assert_file_exists "$tmp_home/.claude/settings.json"
	assert_not_contains "PostToolUse" "$tmp_home/.claude/settings.json"
}

test_codex_config_preserves_projects_and_keeps_home_subprojects() {
	local tmp_home fake_bin log external_project child_project
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-codex.log"
	external_project="/tmp/codex-external-project"
	child_project="$tmp_home/redundant-project"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

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

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" DOTFILES_DIR="$REPO_ROOT" \
		bash "$REPO_ROOT/scripts/install_dotfiles.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_dotfiles.sh codex merge failed"
	fi

	assert_contains 'model = "gpt-5.4"' "$tmp_home/.codex/config.toml"
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
}

test_macos_cleanup_launchagent_created() {
	local tmp_home fake_bin log plist
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
  install|cleanup)
    exit 0
    ;;
  autoupdate)
    case "$1" in
      status) echo 'Autoupdate is stopped'; exit 0 ;;
      start) exit 0 ;;
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

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/macos_install.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "macos_install.sh failed"
	fi

	plist="$tmp_home/Library/LaunchAgents/com.dotfiles.brew-cleanup.plist"
	assert_file_exists "$plist"
	assert_contains "<string>cleanup</string>" "$plist"
	assert_contains "<string>--prune=all</string>" "$plist"
}

run_test "Dotfiles manifest and SSH include block" test_dotfiles_manifest_and_ssh_block
run_test "Dotfiles uninstall preserves modified files" test_dotfiles_uninstall_preserves_modified_files
run_test "Dotfiles hook-free fallback" test_dotfiles_hook_free_fallback
run_test "Codex config preserves subprojects" test_codex_config_preserves_projects_and_keeps_home_subprojects
run_test "Pixi prefers managed install" test_pixi_prefers_managed_install_over_system_binary
run_test "Claude optional on macOS" test_claude_optional_on_macos_when_missing
run_test "Claude optional on Linux" test_claude_optional_on_linux_when_install_fails
run_test "Claude known_hosts preserves symlink" test_claude_known_hosts_preserves_symlink
run_test "macOS cleanup LaunchAgent" test_macos_cleanup_launchagent_created

section "Done"
pass "Smoke checks completed"
