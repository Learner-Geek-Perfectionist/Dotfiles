#!/bin/bash

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

	cat >"$fake_bin/zsh" <<'EOF'
#!/bin/sh
exit 0
EOF

	chmod +x "$fake_bin/curl" "$fake_bin/zsh"
}

run_linux_install() {
	local tmp_home="$1" fake_bin="$2" source_repo="$3" branch="$4" log="$5"
	local cmd
	cmd="HOME=$tmp_home PATH=$fake_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin SHELL=/usr/bin/zsh DOTFILES_REPO_URL=$source_repo DEFAULT_BRANCH=$branch bash $REPO_ROOT/install.sh"

	if command -v script &>/dev/null; then
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
	printf '%s\t%s\n' "$source_repo" "$branch"
}

test_linux_full_install_flow() {
	local tmp_home fake_bin log source_info source_repo branch manifest
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/linux-full-install.log"
	manifest="$tmp_home/.local/state/dotfiles/dotfiles-manifest.tsv"

	create_fake_linux_bin "$fake_bin"
	source_info=$(prepare_clone_source)
	source_repo="${source_info%%$'\t'*}"
	branch="${source_info#*$'\t'}"
	trap "rm -rf '$tmp_home' '$fake_bin' '$source_repo'" RETURN

	if ! run_linux_install "$tmp_home" "$fake_bin" "$source_repo" "$branch" "$log"; then
		cat "$log" >&2
		fail "Linux full install failed in Docker"
	fi

	assert_executable "$tmp_home/.pixi/bin/pixi"
	assert_file_exists "$tmp_home/.zshrc"
	assert_file_exists "$tmp_home/.gitconfig"
	assert_file_exists "$manifest"
	assert_file_exists "$tmp_home/.ssh/config"
	assert_contains "# >>> Dotfiles SSH Include >>>" "$tmp_home/.ssh/config"
}

test_linux_reinstall_is_idempotent() {
	local tmp_home fake_bin log source_info source_repo branch marker_count
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/linux-reinstall.log"

	create_fake_linux_bin "$fake_bin"
	source_info=$(prepare_clone_source)
	source_repo="${source_info%%$'\t'*}"
	branch="${source_info#*$'\t'}"
	trap "rm -rf '$tmp_home' '$fake_bin' '$source_repo'" RETURN

	if ! run_linux_install "$tmp_home" "$fake_bin" "$source_repo" "$branch" "$log"; then
		cat "$log" >&2
		fail "Initial Linux install failed in Docker"
	fi

	if ! run_linux_install "$tmp_home" "$fake_bin" "$source_repo" "$branch" "$log"; then
		cat "$log" >&2
		fail "Repeated Linux install failed in Docker"
	fi

	marker_count=$(grep -c "# >>> Dotfiles SSH Include >>>" "$tmp_home/.ssh/config")
	assert_equal "1" "$marker_count" "SSH include block count"
}

test_linux_uninstall_flow() {
	local tmp_home fake_bin log source_info source_repo branch
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/linux-uninstall.log"

	create_fake_linux_bin "$fake_bin"
	source_info=$(prepare_clone_source)
	source_repo="${source_info%%$'\t'*}"
	branch="${source_info#*$'\t'}"
	trap "rm -rf '$tmp_home' '$fake_bin' '$source_repo'" RETURN

	if ! run_linux_install "$tmp_home" "$fake_bin" "$source_repo" "$branch" "$log"; then
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
}

run_test "Linux full install flow" test_linux_full_install_flow
run_test "Linux reinstall idempotency" test_linux_reinstall_is_idempotent
run_test "Linux uninstall flow" test_linux_uninstall_flow

section "Done"
pass "Linux Docker integration checks completed"
