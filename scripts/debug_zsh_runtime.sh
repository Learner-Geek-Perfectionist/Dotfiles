#!/bin/bash

set -euo pipefail

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

pass() {
	printf 'PASS: %s\n' "$1"
}

assert_equal() {
	local expected="$1" actual="$2" label="$3"
	[[ "$expected" == "$actual" ]] || fail "$label: expected '$expected', got '$actual'"
}

assert_file_missing() {
	local path="$1"
	[[ ! -e "$path" ]] || fail "expected missing path: $path"
}

live_home="${HOME:-/Users/ouyangzhaoxin}"
live_zshrc="$live_home/.zshrc"
live_age_tokens="$live_home/.config/zsh/plugins/age-tokens.zsh"

[[ -f "$live_zshrc" ]] || fail "missing live .zshrc: $live_zshrc"
[[ -f "$live_age_tokens" ]] || fail "missing live age-tokens.zsh: $live_age_tokens"

tmp_home="$(mktemp -d)"
fake_bin="$(mktemp -d)"
trap 'rm -rf "$tmp_home" "$fake_bin"' EXIT

mkdir -p "$tmp_home/.config/zsh/plugins" "$tmp_home/.ssh"
cp "$live_zshrc" "$tmp_home/.zshrc"
[[ -f "$live_home/.zshenv" ]] && cp "$live_home/.zshenv" "$tmp_home/.zshenv"
[[ -f "$live_home/.zprofile" ]] && cp "$live_home/.zprofile" "$tmp_home/.zprofile"
cp "$live_age_tokens" "$tmp_home/.config/zsh/plugins/age-tokens.zsh"

cat >"$tmp_home/.config/zsh/plugins/platform.zsh" <<'EOF'
# debug fixture
EOF

cat >"$tmp_home/.config/zsh/plugins/double-esc-clear.zsh" <<'EOF'
# debug fixture
EOF

cat >"$tmp_home/.config/zsh/plugins/ssh-keychain-unlock.zsh" <<'EOF'
# debug fixture
EOF

cat >"$tmp_home/.config/zsh/plugins/zinit.zsh" <<'EOF'
count=0
[[ -f "$HOME/zinit-load-count" ]] && count=$(<"$HOME/zinit-load-count")
count=$((count + 1))
printf '%s\n' "$count" >"$HOME/zinit-load-count"
zinit() { :; }
EOF

cat >"$fake_bin/open" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$HOME/open.log"
EOF
chmod +x "$fake_bin/open"

cat >"$fake_bin/age" <<'EOF'
#!/bin/sh
printf '%s\n' 'export DEBUG_ZSH_RUNTIME_SECRET="fake-secret"'
EOF
chmod +x "$fake_bin/age"

: >"$tmp_home/.ssh/id_ed25519"
: >"$tmp_home/.ssh/id_ed25519.pub"
: >"$tmp_home/.tokens.sh.age"

codex_url="codex://threads/019dcc72-81d8-7e41-bb02-cdd44b6cba4a"
bundle_id="com.openai.codex"

HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" \
	zsh -ic "source ~/.zshrc; open -b $bundle_id -u '$codex_url'; open '$tmp_home/.zshrc'; source ~/.zshrc" >/dev/null 2>&1 ||
	fail "sourcing live .zshrc fixture failed"

assert_equal "-b $bundle_id -u $codex_url" "$(sed -n '1p' "$tmp_home/open.log")" "Codex deep link open call"
assert_equal "-R $tmp_home/.zshrc" "$(sed -n '2p' "$tmp_home/open.log")" "Finder reveal open call"
assert_equal "1" "$(cat "$tmp_home/zinit-load-count")" "zinit load count after re-source"
pass "live .zshrc keeps Codex deep links intact and avoids zinit re-source"

preloaded_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home" "$fake_bin" "$preloaded_home"' EXIT
mkdir -p "$preloaded_home/.config/zsh/plugins"
cp "$live_zshrc" "$preloaded_home/.zshrc"
cat >"$preloaded_home/.config/zsh/plugins/zinit.zsh" <<'EOF'
printf loaded >"$HOME/zinit-should-not-load"
EOF

HOME="$preloaded_home" TERM="xterm-256color" \
	zsh -c 'zinit() { :; }; source ~/.zshrc; print -r -- "${DOTFILES_ZINIT_LOADED:-unset}" >"$HOME/zinit-guard-flag"' >/dev/null 2>&1 ||
	fail "preloaded zinit fixture failed"

assert_equal "1" "$(cat "$preloaded_home/zinit-guard-flag")" "preloaded zinit guard flag"
assert_file_missing "$preloaded_home/zinit-should-not-load"
pass "live .zshrc detects preloaded zinit without re-sourcing plugin stack"

age_log="$tmp_home/age-xtrace.log"
HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
	zsh -c 'setopt xtrace; source "$HOME/.config/zsh/plugins/age-tokens.zsh"' >"$age_log" 2>&1 ||
	fail "age-tokens xtrace fixture failed"

if rg -q 'DEBUG_ZSH_RUNTIME_SECRET="fake-secret"|fake-secret' "$age_log"; then
	fail "age-tokens leaked decrypted fixture secret under xtrace"
fi
pass "live age-tokens keeps decrypted values hidden under xtrace"
