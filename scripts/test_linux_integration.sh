#!/bin/bash
# shellcheck disable=SC2064

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test_helpers.sh
source "$SCRIPT_DIR/test_helpers.sh"

create_fake_linux_bin() {
	local fake_bin="$1"

	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
for arg in "$@"; do
  if [ "$arg" = "https://pixi.sh/install.sh" ]; then
    cat <<'INNER'
#!/bin/sh
mkdir -p "$HOME/.pixi/bin"
cat >"$HOME/.pixi/bin/pixi" <<'EOF_PIXI'
#!/bin/sh
case "$1" in
  --version) echo 'pixi docker 1.0.0' ;;
  install|list) exit 0 ;;
  *) exit 0 ;;
esac
EOF_PIXI
chmod +x "$HOME/.pixi/bin/pixi"
INNER
    exit 0
  fi
done
	exit 99
EOF

	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
if [ "$1" = "-s" ]; then
  echo Linux
else
  echo x86_64
fi
EOF

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
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

	cat >"$fake_bin/sed" <<'EOF'
#!/bin/sh
if [ "$1" = "-i" ]; then
  shift
  exec /usr/bin/sed -i '' "$@"
fi
exec /usr/bin/sed "$@"
EOF

	cat >"$fake_bin/script" <<'EOF'
#!/bin/bash
set -euo pipefail

logfile=""
cmd=""

while [ $# -gt 0 ]; do
  case "$1" in
    -q|-e)
      shift
      ;;
    -a)
      logfile="$2"
      shift 2
      ;;
    -c)
      cmd="$2"
      shift 2
      ;;
    *)
      [ -z "$logfile" ] && logfile="$1"
      shift
      ;;
  esac
done

if [ -n "$cmd" ]; then
  if [ -n "$logfile" ] && [ "$logfile" != "/dev/null" ]; then
    set +e
    bash -c "$cmd" 2>&1 | tee -a "$logfile"
    rc=${PIPESTATUS[0]}
    set -e
    exit "$rc"
  fi
  exec bash -c "$cmd"
fi

if [ -n "$logfile" ] && [ "$logfile" != "/dev/null" ]; then
  cat /dev/stdin | tee -a "$logfile"
else
	cat
fi
EOF

	chmod +x "$fake_bin/curl" "$fake_bin/dotnet" "$fake_bin/npm" "$fake_bin/rustup" "$fake_bin/script" "$fake_bin/sed" "$fake_bin/uname" "$fake_bin/zsh"
}

run_linux_install() {
	local tmp_home="$1" fake_bin="$2" source_repo="$3" branch="$4" superpowers_repo="$5" log="$6"
	local cmd
	cmd="HOME=$tmp_home PATH=$fake_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin SHELL=/usr/bin/zsh DOTFILES_REPO_URL=$source_repo DEFAULT_BRANCH=$branch SUPERPOWERS_REPO_URL=$superpowers_repo bash $REPO_ROOT/install.sh"

	if command -v script &>/dev/null && script -qec "true" /dev/null >/dev/null 2>&1; then
		script -qec "$cmd" /dev/null >"$log" 2>&1
	else
		eval "$cmd" >"$log" 2>&1
	fi
}

prepare_clone_source() {
	local source_repo branch
	source_repo=$(make_temp_dir)
	git clone "$REPO_ROOT" "$source_repo" >/dev/null 2>&1
	branch=$(git -C "$source_repo" branch --show-current 2>/dev/null || true)
	if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
		branch="ci-test"
		git -C "$source_repo" checkout -b "$branch" >/dev/null 2>&1
	fi

	if command -v rsync &>/dev/null; then
		rsync -a --exclude='.git' "$REPO_ROOT/" "$source_repo/"
	else
		(
			cd "$REPO_ROOT"
			tar --exclude='.git' -cf - .
		) | (
			cd "$source_repo"
			tar -xf -
		)
	fi

	git -C "$source_repo" config user.name "Dotfiles Test"
	git -C "$source_repo" config user.email "dotfiles@example.com"
	git -C "$source_repo" add -A
	git -C "$source_repo" commit -m "test snapshot" >/dev/null 2>&1 || true

	printf '%s\t%s\n' "$source_repo" "$branch"
}

test_linux_full_install_flow() {
	local tmp_home fake_bin log source_info source_repo branch manifest superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/linux-full-install.log"
	manifest="$tmp_home/.local/state/dotfiles/dotfiles-manifest.tsv"
	superpowers_repo=$(make_fake_superpowers_repo)

	create_fake_linux_bin "$fake_bin"
	source_info=$(prepare_clone_source)
	source_repo="${source_info%%$'\t'*}"
	branch="${source_info#*$'\t'}"
	trap "rm -rf '$tmp_home' '$fake_bin' '$source_repo' '$superpowers_repo'" RETURN

	if ! run_linux_install "$tmp_home" "$fake_bin" "$source_repo" "$branch" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "Linux full install failed in Docker"
	fi

	assert_executable "$tmp_home/.pixi/bin/pixi"
	assert_file_exists "$tmp_home/.zshrc"
	assert_file_exists "$tmp_home/.gitconfig"
	assert_file_exists "$manifest"
	assert_symlink "$tmp_home/.agents/skills/superpowers"
	assert_file_exists "$tmp_home/.codex/superpowers/skills/using-superpowers/SKILL.md"
	assert_file_exists "$tmp_home/.ssh/config"
	assert_contains "# >>> Dotfiles SSH Include >>>" "$tmp_home/.ssh/config"
}

test_linux_reinstall_is_idempotent() {
	local tmp_home fake_bin log source_info source_repo branch marker_count superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/linux-reinstall.log"
	superpowers_repo=$(make_fake_superpowers_repo)

	create_fake_linux_bin "$fake_bin"
	source_info=$(prepare_clone_source)
	source_repo="${source_info%%$'\t'*}"
	branch="${source_info#*$'\t'}"
	trap "rm -rf '$tmp_home' '$fake_bin' '$source_repo' '$superpowers_repo'" RETURN

	if ! run_linux_install "$tmp_home" "$fake_bin" "$source_repo" "$branch" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "Initial Linux install failed in Docker"
	fi

	if ! run_linux_install "$tmp_home" "$fake_bin" "$source_repo" "$branch" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "Repeated Linux install failed in Docker"
	fi

	marker_count=$(grep -c "# >>> Dotfiles SSH Include >>>" "$tmp_home/.ssh/config")
	assert_equal "1" "$marker_count" "SSH include block count"
}

test_linux_uninstall_flow() {
	local tmp_home fake_bin log source_info source_repo branch superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/linux-uninstall.log"
	superpowers_repo=$(make_fake_superpowers_repo)

	create_fake_linux_bin "$fake_bin"
	source_info=$(prepare_clone_source)
	source_repo="${source_info%%$'\t'*}"
	branch="${source_info#*$'\t'}"
	trap "rm -rf '$tmp_home' '$fake_bin' '$source_repo' '$superpowers_repo'" RETURN

	if ! run_linux_install "$tmp_home" "$fake_bin" "$source_repo" "$branch" "$superpowers_repo" "$log"; then
		cat "$log" >&2
		fail "Linux install before uninstall failed"
	fi

	printf '\n# modified in docker integration test\n' >>"$tmp_home/.zshrc"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
		bash "$REPO_ROOT/uninstall.sh" --all --force >>"$log" 2>&1; then
		cat "$log" >&2
		fail "Linux uninstall failed in Docker"
	fi

	assert_file_exists "$tmp_home/.zshrc"
	assert_file_missing "$tmp_home/.gitconfig"
	assert_file_missing "$tmp_home/.pixi"
	assert_file_missing "$tmp_home/.codex/superpowers"
	assert_file_missing "$tmp_home/.agents/skills/superpowers"
}

run_test "Linux full install flow" test_linux_full_install_flow
run_test "Linux reinstall idempotency" test_linux_reinstall_is_idempotent
run_test "Linux uninstall flow" test_linux_uninstall_flow

section "Done"
pass "Linux Docker integration checks completed"
