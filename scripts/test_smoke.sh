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

write_fake_claude_cli_with_update_logs() {
	local fake_bin="$1" plugin_list_output="$2" mcp_list_output="$3" add_json_log="$4" remove_log="$5"
	local plugin_install_log="$6" plugin_update_log="$7" marketplace_update_log="$8"
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
        cat <<'INNER'
$plugin_list_output
INNER
        exit 0
        ;;
      install)
        mkdir -p "$(dirname "$plugin_install_log")"
        printf '%s\n' "\$3" >>"$plugin_install_log"
        exit 0
        ;;
      update)
        mkdir -p "$(dirname "$plugin_update_log")"
        printf '%s\n' "\$3" >>"$plugin_update_log"
        exit 0
        ;;
      uninstall)
        exit 0
        ;;
      marketplace)
        case "\$3" in
          add|remove)
            exit 0
            ;;
          update)
            mkdir -p "$(dirname "$marketplace_update_log")"
            if [ -n "\${4:-}" ]; then
              printf '%s\n' "\$4" >>"$marketplace_update_log"
            else
              printf '%s\n' "__all__" >>"$marketplace_update_log"
            fi
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

write_fake_study_master_git() {
	local fake_bin="$1" expected_repo="$2" clone_content="$3" pull_content="$4" git_log="$5"
	cat >"$fake_bin/git" <<EOF
#!/bin/sh
if [ "\$1" = "clone" ] && [ "\$2" = "--depth" ] && [ "\$3" = "1" ] && [ "\$4" = "$expected_repo" ]; then
  dest="\$5"
  mkdir -p "\$dest/.git" "\$dest/study-master-skill/hooks"
  printf '%s\n' '$clone_content' >"\$dest/study-master-skill/SKILL.md"
  printf '#!/bin/sh\nexit 0\n' >"\$dest/study-master-skill/hooks/check-study_master.sh"
  mkdir -p "$(dirname "$git_log")"
  printf 'clone %s\n' "\$dest" >>"$git_log"
  exit 0
fi
if [ "\$1" = "-C" ] && [ "\$3" = "remote" ] && [ "\$4" = "get-url" ] && [ "\$5" = "origin" ]; then
  printf '%s\n' "$expected_repo"
  exit 0
fi
if [ "\$1" = "-C" ] && [ "\$3" = "pull" ] && [ "\$4" = "--ff-only" ]; then
  repo_dir="\$2"
  printf '%s\n' '$pull_content' >"\$repo_dir/study-master-skill/SKILL.md"
  printf '#!/bin/sh\nexit 0\n' >"\$repo_dir/study-master-skill/hooks/check-study_master.sh"
  mkdir -p "$(dirname "$git_log")"
  printf 'pull %s\n' "\$repo_dir" >>"$git_log"
  exit 0
fi
exit 1
EOF
	chmod +x "$fake_bin/git"
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
	local tmp_home fake_bin log npm_log state_file shim_path
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser.log"
	npm_log="$tmp_home/npm.log"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	shim_path="$tmp_home/.local/bin/bb-browser"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$tmp_home/.config/google-chrome" "$tmp_home/.config/microsoft-edge"
cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
url=""
for arg in "$@"; do
  url="$arg"
done
case "$url" in
  http://127.0.0.1:19825/json/version)
    printf '%s\n' '{}'
    exit 0
    ;;
  http://127.0.0.1:19824/status)
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/google-chrome" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/curl" "$fake_bin/google-chrome" "$fake_bin/microsoft-edge" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh failed"
	fi

	assert_executable "$shim_path"
	assert_executable "$tmp_home/.local/bin/bb-browser-user"
	assert_file_exists "$state_file"
	assert_contains "install" "$npm_log"
	assert_contains "bb-browser@latest" "$npm_log"
	assert_contains "PREEXISTING_BB_BROWSER=0" "$state_file"
	assert_contains "REAL_BB_BROWSER_PATH=$fake_bin/bb-browser" "$state_file"
}

test_bb_browser_install_patches_managed_mcp_dist_file_only() {
	local tmp_home fake_bin log npm_log state_file mcp_file real_node
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-patch.log"
	npm_log="$tmp_home/npm-patch.log"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	mcp_file="$tmp_home/fake-node-modules/bb-browser/dist/mcp.js"
	real_node="$(command -v node)"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$tmp_home/.config/google-chrome" "$tmp_home/.config/microsoft-edge"
cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
  cat >"$mcp_file" <<'INNER'
import { execFile, spawn } from "child_process";
import { existsSync } from "fs";
import { dirname, resolve } from "path";
var sessionOpenedTabs = /* @__PURE__ */ new Set();
async function isDaemonRunning() {
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 2000);
    const res = await fetch(\`\${DAEMON_BASE_URL}/status\`, { signal: controller.signal });
    clearTimeout(t);
    return res.ok;
  } catch { return false; }
}
async function ensureDaemon() {
  if (await isDaemonRunning()) return;
  const child = spawn(process.execPath, [getDaemonPath()], {
    detached: true,
    stdio: "ignore",
    env: { ...process.env }
  });
  child.unref();
}
async function sendCommand(request) {
  await ensureDaemon();
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), COMMAND_TIMEOUT);
  const response = await fetch(\`\${DAEMON_BASE_URL}/command\`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request),
    signal: controller.signal
  });
  clearTimeout(timeoutId);
  return await response.json();
}
INNER
fi
exit 0
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  "$REPO_ROOT/scripts/patch_bb_browser_dist.mjs")
    exec "$real_node" "\$@"
    ;;
  -e)
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
url=""
for arg in "$@"; do
  url="$arg"
done
case "$url" in
  http://127.0.0.1:19825/json/version)
    printf '%s\n' '{}'
    exit 0
    ;;
  http://127.0.0.1:19824/status)
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/google-chrome" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/curl" "$fake_bin/google-chrome" "$fake_bin/microsoft-edge" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh patch case failed"
	fi

	assert_executable "$tmp_home/.local/bin/bb-browser-user"
	assert_file_exists "$state_file"
	assert_contains 'import { readFile } from "fs/promises";' "$mcp_file"
	assert_contains 'var MCP_DAEMON_BASE_URL = DAEMON_BASE_URL.replace("://localhost:", "://127.0.0.1:");' "$mcp_file"
	assert_contains 'if (res.status === 401 && cachedDaemonToken && !retrying) {' "$mcp_file"
	assert_contains 'Authorization: `Bearer ${token}`' "$mcp_file"
	assert_contains '// If bb-browser already uses daemon.json config, it has native token/host support.' "$REPO_ROOT/scripts/patch_bb_browser_dist.mjs"
}

test_bb_browser_dist_patch_supports_mcp_spawn_with_cdp_args_without_cli_js() {
	local tmp_dir dist_dir mcp_file output_file
	tmp_dir=$(make_temp_dir)
	dist_dir="$tmp_dir/dist"
	mcp_file="$dist_dir/mcp.js"
	output_file="$tmp_dir/patch-output.log"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	mkdir -p "$dist_dir"
	cat >"$mcp_file" <<'EOF'
import { execFile, spawn } from "child_process";
import { existsSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";
var sessionOpenedTabs = /* @__PURE__ */ new Set();
function getDaemonPath() {
  const currentDir = dirname(fileURLToPath(import.meta.url));
  const sameDirPath = resolve(currentDir, "daemon.js");
  if (existsSync(sameDirPath)) return sameDirPath;
  return resolve(currentDir, "../../daemon/dist/index.js");
}
async function isDaemonRunning() {
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 2e3);
    const res = await fetch(`${DAEMON_BASE_URL}/status`, { signal: controller.signal });
    clearTimeout(t);
    return res.ok;
  } catch {
    return false;
  }
}
async function ensureDaemon() {
  if (await isDaemonRunning()) return;
  let cdpArgs = [];
  try {
    const cliPath = getCliPath();
    await new Promise((resolve2, reject) => {
      execFile(process.execPath, [cliPath, "daemon", "status", "--json"], { timeout: 15e3 }, (err, stdout) => {
        if (err) reject(err);
        else resolve2(stdout);
      });
    });
    if (await isDaemonRunning()) return;
  } catch {
    const { readFile } = await import("fs/promises");
    const os = await import("os");
    const path = await import("path");
    try {
      const portFile = path.join(os.default.homedir(), ".bb-browser", "browser", "cdp-port");
      const port = (await readFile(portFile, "utf8")).trim();
      if (port) cdpArgs = ["--cdp-port", port];
    } catch {
    }
  }
  const child = spawn(process.execPath, [getDaemonPath(), ...cdpArgs], {
    detached: true,
    stdio: "ignore",
    env: { ...process.env }
  });
  child.unref();
}
async function sendCommand(request) {
  await ensureDaemon();
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), COMMAND_TIMEOUT);
  try {
    const response = await fetch(`${DAEMON_BASE_URL}/command`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(request),
      signal: controller.signal
    });
    clearTimeout(timeoutId);
    return await response.json();
  } catch (error) {
    clearTimeout(timeoutId);
    throw error;
  }
}
EOF

	if ! node "$REPO_ROOT/scripts/patch_bb_browser_dist.mjs" "$dist_dir" >"$output_file" 2>&1; then
		cat "$output_file" >&2
		fail "patch_bb_browser_dist.mjs failed on mcp cdpArgs variant without cli.js"
	fi

	assert_contains 'patched 1 file(s)' "$output_file"
	assert_contains 'var MCP_DAEMON_BASE_URL = DAEMON_BASE_URL.replace("://localhost:", "://127.0.0.1:");' "$mcp_file"
	assert_contains 'const child = spawn(process.execPath, [getDaemonPath(), "--host", "127.0.0.1", ...cdpArgs], {' "$mcp_file"
	assert_contains 'const response = await daemonFetch(`${MCP_DAEMON_BASE_URL}/command`' "$mcp_file"
}

test_managed_xiaohongshu_search_template_corrects_stale_search_context() {
	local template_path first_result first_title first_url
	template_path="$REPO_ROOT/scripts/bb-browser-sites/xiaohongshu/search.js"
	assert_file_exists "$template_path"

	first_result="$(
		node - "$template_path" <<'NODE'
const fs = require("fs");

const templatePath = process.argv[2];
const raw = fs.readFileSync(templatePath, "utf8");
const fnSource = raw.replace(/\/\*[\s\S]*?\*\/\s*/, "");
const adapterFn = eval(`(${fnSource})`);

function makeStoreFeed(title, author = "作者", likes = "1") {
  return {
    id: title,
    xsecToken: `tok-${title}`,
    noteCard: {
      displayTitle: title,
      type: "normal",
      user: { nickname: author },
      interactInfo: { likedCount: likes },
    },
  };
}

function makeResp(title, author = "作者", likes = "1") {
  return {
    success: true,
    data: {
      has_more: true,
      items: [
        {
          id: `id-${title}`,
          xsec_token: `xt-${title}`,
          note_card: {
            display_title: title,
            type: "normal",
            user: { nickname: author },
            interact_info: { liked_count: likes },
          },
        },
      ],
    },
  };
}

(async () => {
  const originalSetTimeout = globalThis.setTimeout;
  const originalDocument = globalThis.document;
  const originalXHR = globalThis.XMLHttpRequest;

  try {
    globalThis.setTimeout = (fn) => {
      fn();
      return 0;
    };

    const searchStore = {
      searchValue: "AI agent",
      hasMore: true,
      feeds: [makeStoreFeed("AI标题", "AI作者", "99")],
      searchContext: { keyword: "AI agent", page: 7, searchId: "old-search-id" },
      rootSearchId: "old-search-id",
      resetSearchNoteStore() {
        this.feeds = [];
      },
      resetSearchRelatedInfo() {},
      setRootSearchId(value) {
        this.rootSearchId = value;
      },
      mutateSearchValue(value) {
        this.searchValue = value;
      },
      async loadMore() {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", "//edith.xiaohongshu.com/api/sns/web/v1/search/notes");
        xhr.send(JSON.stringify({
          keyword: this.searchContext.keyword,
          page: this.searchContext.page,
          page_size: 20,
          search_id: this.searchContext.searchId,
          sort: "general",
          note_type: 0,
          ext_flags: [],
          geo: "",
          image_formats: ["jpg", "webp", "avif"],
        }));
      },
    };

    globalThis.document = {
      querySelector(selector) {
        if (selector !== "#app") return null;
        return {
          __vue_app__: {
            config: {
              globalProperties: {
                $pinia: {
                  _s: new Map([["search", searchStore]]),
                },
              },
            },
          },
        };
      },
    };

    class MockXHR {
      constructor() {
        this.listeners = {};
        this.readyState = 0;
        this.responseText = "";
        this.__url = "";
      }
      open(method, url) {
        this.__url = url;
      }
      addEventListener(type, fn) {
        this.listeners[type] ||= [];
        this.listeners[type].push(fn);
      }
      send(body) {
        const parsed = JSON.parse(body);
        const response = parsed.keyword === "美食" && parsed.page === 1
          ? makeResp("家常菜", "弘学美食日记", "4081")
          : makeResp("AI标题", "AI作者", "99");

        searchStore.feeds = response.data.items.map((item) => ({
          id: item.id,
          xsecToken: item.xsec_token,
          noteCard: {
            displayTitle: item.note_card.display_title,
            type: item.note_card.type,
            user: { nickname: item.note_card.user.nickname },
            interactInfo: { likedCount: item.note_card.interact_info.liked_count },
          },
        }));
        searchStore.searchContext.keyword = parsed.keyword;
        searchStore.searchContext.page = parsed.page;
        searchStore.searchContext.searchId = parsed.search_id;
        this.readyState = 4;
        this.responseText = JSON.stringify(response);
        for (const fn of this.listeners.loadend || []) {
          fn.call(this);
        }
      }
    }

    globalThis.XMLHttpRequest = MockXHR;

    const result = await adapterFn({ keyword: "美食" });
    process.stdout.write([
      result.notes?.[0]?.title || "",
      result.notes?.[0]?.url || "",
    ].join("\t"));
  } finally {
    globalThis.setTimeout = originalSetTimeout;
    globalThis.document = originalDocument;
    globalThis.XMLHttpRequest = originalXHR;
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
	)"

	first_title="${first_result%%	*}"
	first_url="${first_result#*	}"

	assert_equal "家常菜" "$first_title" "managed xiaohongshu template stale context result"
	[[ "$first_url" == *"https://www.xiaohongshu.com/explore/id-家常菜"* ]] || fail "Expected openable note URL, got '$first_url'"
	[[ "$first_url" == *"xsec_token=xt-%E5%AE%B6%E5%B8%B8%E8%8F%9C"* ]] || fail "Expected xsec_token in note URL, got '$first_url'"
	[[ "$first_url" == *"xsec_source=pc_search"* ]] || fail "Expected xsec_source in note URL, got '$first_url'"
}

test_bb_browser_fresh_install_marker_drives_managed_uninstall() {
	local tmp_home fake_bin managed_prefix install_log uninstall_log npm_log state_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	managed_prefix=$(make_temp_dir)
	install_log="$tmp_home/install-bb-browser-managed.log"
	uninstall_log="$tmp_home/uninstall-bb-browser-managed.log"
	npm_log="$tmp_home/npm-managed.log"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	trap "rm -rf '$tmp_home' '$fake_bin' '$managed_prefix'" RETURN

	mkdir -p "$tmp_home/.config/google-chrome" "$tmp_home/.config/microsoft-edge"
cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
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
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$managed_prefix/bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
  exit 0
fi
if [ "\$1" = "--prefix" ] && [ "\$2" = "$managed_prefix" ] && [ "\$3" = "uninstall" ] && [ "\$4" = "-g" ] && [ "\$5" = "bb-browser" ]; then
  rm -f "$managed_prefix/bin/bb-browser"
  exit 0
fi
exit 0
EOF
	cat >"$fake_bin/node" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
url=""
for arg in "$@"; do
  url="$arg"
done
case "$url" in
  http://127.0.0.1:19825/json/version)
    printf '%s\n' '{}'
    exit 0
    ;;
  http://127.0.0.1:19824/status)
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/google-chrome" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/curl" "$fake_bin/google-chrome" "$fake_bin/microsoft-edge" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$install_log" 2>&1; then
		cat "$install_log" >&2
		fail "install_bb_browser.sh managed ownership test failed"
	fi

	assert_file_exists "$state_file"
	assert_contains "PREEXISTING_BB_BROWSER=0" "$state_file"
	assert_contains "REAL_BB_BROWSER_PATH=$managed_prefix/bin/bb-browser" "$state_file"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$uninstall_log" 2>&1; then
		cat "$uninstall_log" >&2
		fail "uninstall.sh managed ownership test failed"
	fi

	assert_file_missing "$state_file"
	assert_contains "$managed_prefix" "$npm_log"
	assert_contains "uninstall" "$npm_log"
	assert_file_missing "$managed_prefix/bin/bb-browser"
}

test_bb_browser_install_discovers_browser_and_launches_cdp() {
	local tmp_home fake_bin log npm_log chrome_log edge_log fetch_log daemon_log pkill_log ready_file daemon_ready_file config_file state_file wrapper_path token_file version_output
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-discovery.log"
	npm_log="$tmp_home/npm-discovery.log"
	chrome_log="$tmp_home/google-chrome.log"
	edge_log="$tmp_home/microsoft-edge.log"
	fetch_log="$tmp_home/node-fetch.log"
	daemon_log="$tmp_home/daemon.log"
	pkill_log="$tmp_home/pkill.log"
	ready_file="$tmp_home/.cdp-ready-19825"
	daemon_ready_file="$tmp_home/.daemon-ready"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	token_file="$tmp_home/.bb-browser/daemon.token"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$config_file")" "$tmp_home/.config/google-chrome" "$tmp_home/.config/microsoft-edge"
	cat >"$config_file" <<'EOF'
{"browser":"microsoft-edge","port":24444,"profileDirectory":"Profile 9"}
EOF

cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    printf '%s\n' "\$*" >>"$daemon_log"
    mkdir -p "$(dirname "$token_file")"
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
script="\$2"
arg="\$3"
status_url="\$4"
case "\$script" in
  *fetch*)
    printf '%s\n' "\$arg" >>"$fetch_log"
    case "\$status_url" in
      http://127.0.0.1:19824/status)
        [ -f "$daemon_ready_file" ] && exit 0
        exit 1
        ;;
    esac
    case "\$arg" in
      http://127.0.0.1:19825|http://127.0.0.1:19825/json/version)
        [ -f "$ready_file" ] && exit 0
        exit 1
        ;;
    esac
    exit 1
    ;;
  *crypto.randomBytes*)
    /bin/cat <<'INNER'
daemon-token
INNER
    exit 0
    ;;
  *url.hostname*)
    /bin/cat <<'INNER'
127.0.0.1
INNER
    exit 0
    ;;
  *url.port*)
    /bin/cat <<'INNER'
19825
INNER
    exit 0
    ;;
  *config.browser*config.port*config.profileDirectory*)
    /bin/cat <<'INNER'
microsoft-edge
19825
Default
INNER
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/google-chrome" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$chrome_log"
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$edge_log"
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
	cat >"$fake_bin/openssl" <<'EOF'
#!/bin/sh
printf '%s\n' 'daemon-token'
EOF
	cat >"$fake_bin/curl" <<EOF
#!/bin/sh
url=""
for arg in "\$@"; do
  url="\$arg"
done
printf '%s\n' "\$url" >>"$fetch_log"
case "\$url" in
  http://127.0.0.1:19824/status)
    [ -f "$daemon_ready_file" ] || exit 22
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
  http://127.0.0.1:19825/json/version)
    [ -f "$ready_file" ] || exit 22
    printf '%s\n' '{}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/pkill" <<EOF
#!/bin/sh
	printf '%s\n' "\$*" >>"$pkill_log"
	exit 0
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/google-chrome" "$fake_bin/microsoft-edge" "$fake_bin/uname" "$fake_bin/openssl" "$fake_bin/curl" "$fake_bin/pkill"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh discovery case failed"
	fi

	version_output="$(
		HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			bash "$wrapper_path" --version
	)"

	assert_executable "$wrapper_path"
	assert_file_exists "$state_file"
	assert_equal "bb-browser 9.9.9" "$version_output" "wrapper version output"
	assert_contains "http://127.0.0.1:19825" "$fetch_log"
	assert_contains "remote-debugging-port=19825" "$edge_log"
	assert_contains "user-data-dir=$tmp_home/.config/microsoft-edge" "$edge_log"
	assert_contains "profile-directory=Default" "$edge_log"
	assert_contains "about:blank" "$edge_log"
	grep -qF -- "-H 127.0.0.1" "$daemon_log" || fail "Expected '-H 127.0.0.1' in $daemon_log"
	grep -qF -- "--cdp-host 127.0.0.1" "$daemon_log" || fail "Expected '--cdp-host 127.0.0.1' in $daemon_log"
	grep -qF -- "--cdp-port 19825" "$daemon_log" || fail "Expected '--cdp-port 19825' in $daemon_log"
	grep -qF -- "--port 19824" "$daemon_log" || fail "Expected '--port 19824' in $daemon_log"
	grep -qF -- "--token daemon-token" "$daemon_log" || fail "Expected '--token daemon-token' in $daemon_log"
	assert_file_exists "$token_file"
	assert_mode "600" "$token_file"
	assert_file_missing "$chrome_log"
	assert_file_missing "$pkill_log"
}

test_bb_browser_install_keeps_token_private_when_chmod_fails() {
	local tmp_home fake_bin log npm_log edge_log fetch_log daemon_log ready_file daemon_ready_file config_file token_file wrapper_path version_output
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-token-mode.log"
	npm_log="$tmp_home/npm-token-mode.log"
	edge_log="$tmp_home/microsoft-edge-token-mode.log"
	fetch_log="$tmp_home/node-fetch-token-mode.log"
	daemon_log="$tmp_home/daemon-token-mode.log"
	ready_file="$tmp_home/.cdp-ready-19825"
	daemon_ready_file="$tmp_home/.daemon-ready"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	token_file="$tmp_home/.bb-browser/daemon.token"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$config_file")" "$tmp_home/.config/microsoft-edge"
	cat >"$config_file" <<'EOF'
{"browser":"microsoft-edge","port":24444,"profileDirectory":"Profile 9"}
EOF

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  /bin/chmod +x "$fake_bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    printf '%s\n' "\$*" >>"$daemon_log"
    mkdir -p "$(dirname "$token_file")"
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
script="\$2"
arg="\$3"
status_url="\$4"
case "\$script" in
  *fetch*)
    printf '%s\n' "\$arg" >>"$fetch_log"
    case "\$status_url" in
      http://127.0.0.1:19824/status)
        [ -f "$daemon_ready_file" ] && exit 0
        exit 1
        ;;
    esac
    case "\$arg" in
      http://127.0.0.1:19825|http://127.0.0.1:19825/json/version)
        [ -f "$ready_file" ] && exit 0
        exit 1
        ;;
    esac
    exit 1
    ;;
  *config.browser*config.port*config.profileDirectory*)
    printf '%s\n%s\n%s\n' 'microsoft-edge' '19825' 'Default'
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$edge_log"
: >"$ready_file"
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	cat >"$fake_bin/openssl" <<'EOF'
#!/bin/sh
printf '%s\n' 'daemon-token'
EOF
	cat >"$fake_bin/curl" <<EOF
#!/bin/sh
url=""
for arg in "\$@"; do
  url="\$arg"
done
printf '%s\n' "\$url" >>"$fetch_log"
case "\$url" in
  http://127.0.0.1:19824/status)
    [ -f "$daemon_ready_file" ] || exit 22
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
  http://127.0.0.1:19825/json/version)
    [ -f "$ready_file" ] || exit 22
    printf '%s\n' '{}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/chmod" <<EOF
#!/bin/sh
last=""
for arg in "\$@"; do
  last="\$arg"
done
if [ "\$last" = "$token_file" ]; then
  exit 1
fi
exec /bin/chmod "\$@"
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/microsoft-edge" "$fake_bin/uname" "$fake_bin/openssl" "$fake_bin/curl" "$fake_bin/chmod"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh token mode case failed"
	fi

	version_output="$(
		HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			bash "$wrapper_path" --version
	)"

	assert_file_exists "$token_file"
	assert_mode "600" "$token_file"
	assert_equal "bb-browser 9.9.9" "$version_output" "wrapper version output"
}

test_bb_browser_install_writes_edge_default_config_and_verifies_mcp() {
	local tmp_home fake_bin log npm_log edge_log init_log config_file wrapper_path state_file ready_file daemon_ready_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-default-config.log"
	npm_log="$tmp_home/npm-default-config.log"
	edge_log="$tmp_home/microsoft-edge-default.log"
	init_log="$tmp_home/mcp-bootstrap.log"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	ready_file="$tmp_home/.cdp-ready-19825"
	daemon_ready_file="$tmp_home/.daemon-ready"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$config_file")" "$tmp_home/.config/microsoft-edge"
	cat >"$config_file" <<'EOF'
{"browser":"microsoft-edge","port":19825,"profileDirectory":"Profile bb-browser"}
EOF

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >"\${BB_BROWSER_MCP_LOG:-\$HOME/mcp-bootstrap.log}"
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
script="\$2"
case "\$script" in
  *config.browser*config.port*config.profileDirectory*)
    printf '%s\n%s\n%s\n' 'microsoft-edge' '19825' 'Profile bb-browser'
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/curl" <<EOF
#!/bin/sh
url=""
for arg in "\$@"; do
  url="\$arg"
done
case "\$url" in
  http://127.0.0.1:19825/json/version)
    [ -f "$ready_file" ] || exit 22
    printf '%s\n' '{}'
    exit 0
    ;;
  http://127.0.0.1:19824/status)
    [ -f "$daemon_ready_file" ] || exit 22
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/openssl" <<'EOF'
#!/bin/sh
printf '%s\n' 'daemon-token'
EOF
	cat >"$fake_bin/microsoft-edge" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$edge_log"
: >"$ready_file"
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/curl" "$fake_bin/openssl" "$fake_bin/microsoft-edge" "$fake_bin/uname"

	if HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_MCP_LOG="$init_log" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		:
	else
		cat "$log" >&2
		fail "install_bb_browser.sh default config test failed"
	fi

	assert_file_exists "$wrapper_path"
	assert_file_exists "$state_file"
	assert_file_exists "$config_file"
	assert_contains '"browser": "microsoft-edge"' "$config_file"
	assert_contains '"profileDirectory": "Default"' "$config_file"
	assert_contains '"port": 19825' "$config_file"
	assert_file_exists "$init_log"
}

test_bb_browser_wrapper_uses_overridden_loopback_and_daemon_endpoint() {
	local tmp_home fake_bin log npm_log edge_log fetch_log daemon_log ready_file daemon_ready_file config_file state_file wrapper_path token_file version_output
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-loopback.log"
	npm_log="$tmp_home/npm-loopback.log"
	edge_log="$tmp_home/microsoft-edge-loopback.log"
	fetch_log="$tmp_home/node-fetch-loopback.log"
	daemon_log="$tmp_home/daemon-loopback.log"
	ready_file="$tmp_home/.cdp-ready-19825"
	daemon_ready_file="$tmp_home/.daemon-ready"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	token_file="$tmp_home/.bb-browser/daemon.token"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$config_file")" "$tmp_home/.config/microsoft-edge"
	cat >"$config_file" <<'EOF'
{"browser":"microsoft-edge","port":24444,"profileDirectory":"Profile 9"}
EOF

cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    printf '%s\n' "\$*" >>"$daemon_log"
    mkdir -p "$(dirname "$token_file")"
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
script="\$2"
arg="\$3"
status_url="\$4"
case "\$script" in
  *fetch*)
    printf '%s\n' "\$arg" >>"$fetch_log"
    case "\$status_url" in
      http://localhost:24446/status)
        [ -f "$daemon_ready_file" ] && exit 0
        exit 1
        ;;
    esac
    case "\$arg" in
      http://localhost:19825|http://localhost:19825/json/version)
        [ -f "$ready_file" ] && exit 0
        exit 1
        ;;
    esac
    exit 1
    ;;
  *crypto.randomBytes*)
    printf '%s\n' 'daemon-token'
    exit 0
    ;;
  *url.hostname*)
    printf '%s\n' 'localhost'
    exit 0
    ;;
  *url.port*)
    printf '%s\n' '19825'
    exit 0
    ;;
  *config.browser*config.port*config.profileDirectory*)
    printf '%s\n%s\n%s\n' 'microsoft-edge' '19825' 'Default'
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$edge_log"
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
	cat >"$fake_bin/openssl" <<'EOF'
#!/bin/sh
printf '%s\n' 'daemon-token'
EOF
	cat >"$fake_bin/curl" <<EOF
#!/bin/sh
url=""
for arg in "\$@"; do
  url="\$arg"
done
printf '%s\n' "\$url" >>"$fetch_log"
case "\$url" in
  http://localhost:24446/status)
    [ -f "$daemon_ready_file" ] || exit 22
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
  http://localhost:19825/json/version)
    [ -f "$ready_file" ] || exit 22
    printf '%s\n' '{}'
    exit 0
    ;;
esac
exit 22
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/microsoft-edge" "$fake_bin/uname" "$fake_bin/openssl" "$fake_bin/curl"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_LOOPBACK_HOST="localhost" \
		BB_BROWSER_DAEMON_HOST="localhost" \
		BB_BROWSER_DAEMON_PORT="24446" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh loopback override case failed"
	fi

	version_output="$(
		HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			BB_BROWSER_LOOPBACK_HOST="localhost" \
			BB_BROWSER_DAEMON_HOST="localhost" \
			BB_BROWSER_DAEMON_PORT="24446" \
			bash "$wrapper_path" --version
	)"

	assert_equal "bb-browser 9.9.9" "$version_output" "wrapper version output"
	assert_contains "http://localhost:19825" "$fetch_log"
	grep -qF -- "-H localhost" "$daemon_log" || fail "Expected '-H localhost' in $daemon_log"
	grep -qF -- "--cdp-host localhost" "$daemon_log" || fail "Expected '--cdp-host localhost' in $daemon_log"
	grep -qF -- "--port 24446" "$daemon_log" || fail "Expected '--port 24446' in $daemon_log"
	assert_file_exists "$token_file"
}

test_bb_browser_wrapper_defaults_to_edge_default_profile() {
	local tmp_home browser profile_dir
	tmp_home=$(make_temp_dir)
	trap "rm -rf '$tmp_home'" RETURN

	browser="$(
		HOME="$tmp_home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
			bash -lc "source '$REPO_ROOT/scripts/bb-browser-user.sh'; configured_browser"
	)"
	profile_dir="$(
		HOME="$tmp_home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
			bash -lc "source '$REPO_ROOT/scripts/bb-browser-user.sh'; configured_profile_directory"
	)"

	assert_equal "microsoft-edge" "$browser" "default browser"
	assert_equal "Default" "$profile_dir" "default profile directory"
}

test_bb_browser_wrapper_doctor_is_side_effect_free() {
	local tmp_home fake_bin log browser_log daemon_log fetch_log ready_file daemon_ready_file state_file token_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/bb-browser-doctor.log"
	browser_log="$tmp_home/microsoft-edge.log"
	daemon_log="$tmp_home/daemon.log"
	fetch_log="$tmp_home/node-fetch.log"
	ready_file="$tmp_home/.cdp-ready-24444"
	daemon_ready_file="$tmp_home/.daemon-ready"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	token_file="$tmp_home/.bb-browser/daemon.token"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$state_file")" "$tmp_home/.config/microsoft-edge" "$tmp_home/fake-node-modules/bb-browser/dist"
	: >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=0
REAL_BB_BROWSER_PATH=$fake_bin/bb-browser
EOF

	cat >"$fake_bin/bb-browser" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  *) exit 0 ;;
esac
EOF
	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    printf '%s\n' "\$*" >>"$daemon_log"
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
script="\$2"
arg="\$3"
status_url="\$4"
case "\$script" in
  *fetch*)
    printf '%s\n' "\$arg" >>"$fetch_log"
    case "\$status_url" in
      http://127.0.0.1:19824/status)
        [ -f "$daemon_ready_file" ] && exit 0
        exit 1
        ;;
    esac
    case "\$arg" in
      http://127.0.0.1:24444|http://127.0.0.1:24444/json/version)
        [ -f "$ready_file" ] && exit 0
        exit 1
        ;;
    esac
    exit 1
    ;;
  *crypto.randomBytes*)
    printf '%s\n' 'daemon-token'
    exit 0
    ;;
  *url.hostname*)
    printf '%s\n' '127.0.0.1'
    exit 0
    ;;
  *url.port*)
    printf '%s\n' '24444'
    exit 0
    ;;
  *config.browser*config.port*config.profileDirectory*)
    printf '%s\n%s\n%s\n' 'microsoft-edge' '24444' 'Profile bb-browser'
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$browser_log"
: >"$ready_file"
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/bb-browser" "$fake_bin/npm" "$fake_bin/node" "$fake_bin/microsoft-edge" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/bb-browser-user.sh" doctor >"$log" 2>&1; then
		cat "$log" >&2
		fail "bb-browser-user.sh doctor unexpectedly failed"
	fi

	assert_file_missing "$browser_log"
	assert_file_missing "$daemon_log"
	assert_file_missing "$token_file"
}

test_bb_browser_wrapper_restarts_edge_when_running_without_cdp() {
	local tmp_home fake_bin wrapper_path state_file config_file edge_log kill_log ready_file daemon_ready_file edge_running_flag version_output
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	edge_log="$tmp_home/microsoft-edge-restart.log"
	kill_log="$tmp_home/pkill.log"
	ready_file="$tmp_home/.cdp-ready-19825"
	daemon_ready_file="$tmp_home/.daemon-ready"
	edge_running_flag="$tmp_home/.edge-running"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$state_file")" "$(dirname "$config_file")" "$tmp_home/.config/microsoft-edge" "$tmp_home/fake-node-modules/bb-browser/dist"
	: >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
	: >"$edge_running_flag"
	cp "$REPO_ROOT/scripts/bb-browser-user.sh" "$wrapper_path"
	chmod +x "$wrapper_path"
	cat >"$config_file" <<'EOF'
{"browser":"microsoft-edge","port":19825,"profileDirectory":"Default"}
EOF
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=0
REAL_BB_BROWSER_PATH=$fake_bin/bb-browser
EOF

	cat >"$fake_bin/bb-browser" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  *) exit 0 ;;
esac
EOF
	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/curl" <<EOF
#!/bin/sh
url=""
for arg in "\$@"; do
  url="\$arg"
done
case "\$url" in
  http://127.0.0.1:19825/json/version)
    [ -f "$ready_file" ] || exit 22
    printf '%s\n' '{}'
    exit 0
    ;;
  http://127.0.0.1:19824/status)
    [ -f "$daemon_ready_file" ] || exit 22
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/pgrep" <<EOF
#!/bin/sh
[ -f "$edge_running_flag" ] && exit 0
exit 1
EOF
	cat >"$fake_bin/pkill" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$kill_log"
rm -f "$edge_running_flag"
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$edge_log"
if [ ! -f "$edge_running_flag" ]; then
  : >"$ready_file"
fi
exit 0
EOF
	cat >"$fake_bin/openssl" <<'EOF'
#!/bin/sh
printf '%s\n' 'daemon-token'
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/bb-browser" "$fake_bin/npm" "$fake_bin/node" "$fake_bin/curl" "$fake_bin/pgrep" "$fake_bin/pkill" "$fake_bin/microsoft-edge" "$fake_bin/openssl" "$fake_bin/uname"

	version_output="$(
		HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			bash "$wrapper_path" --version
	)"

	assert_equal "bb-browser 9.9.9" "$version_output" "wrapper version output"
	assert_contains "microsoft-edge" "$kill_log"
	assert_contains "remote-debugging-port=19825" "$edge_log"
	assert_contains "profile-directory=Default" "$edge_log"
}

test_bb_browser_wrapper_restarts_edge_when_cdp_profile_mismatches() {
	local tmp_home fake_bin wrapper_path state_file config_file edge_log kill_log ready_file daemon_ready_file edge_running_flag version_output
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	edge_log="$tmp_home/microsoft-edge-mismatch.log"
	kill_log="$tmp_home/pkill-mismatch.log"
	ready_file="$tmp_home/.cdp-ready-19825"
	daemon_ready_file="$tmp_home/.daemon-ready"
	edge_running_flag="$tmp_home/.edge-running"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$state_file")" "$(dirname "$config_file")" "$tmp_home/.config/microsoft-edge" "$tmp_home/fake-node-modules/bb-browser/dist"
	: >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
	: >"$edge_running_flag"
	: >"$ready_file"
	cp "$REPO_ROOT/scripts/bb-browser-user.sh" "$wrapper_path"
	chmod +x "$wrapper_path"
	cat >"$config_file" <<'EOF'
{"browser":"microsoft-edge","port":19825,"profileDirectory":"Default"}
EOF
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=0
REAL_BB_BROWSER_PATH=$fake_bin/bb-browser
EOF

	cat >"$fake_bin/bb-browser" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  *) exit 0 ;;
esac
EOF
	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/curl" <<EOF
#!/bin/sh
url=""
for arg in "\$@"; do
  url="\$arg"
done
case "\$url" in
  http://127.0.0.1:19825/json/version)
    [ -f "$ready_file" ] || exit 22
    printf '%s\n' '{}'
    exit 0
    ;;
  http://127.0.0.1:19824/status)
    [ -f "$daemon_ready_file" ] || exit 22
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/pgrep" <<EOF
#!/bin/sh
if [ -f "$edge_running_flag" ] && [ "\$1" = "-x" ] && [ "\$2" = "microsoft-edge" ]; then
  printf '%s\n' '4242'
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/ps" <<EOF
#!/bin/sh
if [ "\$1" = "-p" ] && [ "\$2" = "4242" ] && [ "\$3" = "-o" ] && [ "\$4" = "command=" ]; then
  printf '%s\n' "$fake_bin/microsoft-edge --remote-debugging-port=19825 --user-data-dir=$tmp_home/.config/microsoft-edge --profile-directory=Profile bb-browser about:blank"
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/pkill" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$kill_log"
rm -f "$edge_running_flag" "$ready_file"
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$edge_log"
: >"$edge_running_flag"
: >"$ready_file"
exit 0
EOF
	cat >"$fake_bin/openssl" <<'EOF'
#!/bin/sh
printf '%s\n' 'daemon-token'
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/bb-browser" "$fake_bin/npm" "$fake_bin/node" "$fake_bin/curl" "$fake_bin/pgrep" "$fake_bin/ps" "$fake_bin/pkill" "$fake_bin/microsoft-edge" "$fake_bin/openssl" "$fake_bin/uname"

	version_output="$(
		HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			bash "$wrapper_path" --version
	)"

	assert_equal "bb-browser 9.9.9" "$version_output" "wrapper version output"
	assert_contains "microsoft-edge" "$kill_log"
	assert_contains "remote-debugging-port=19825" "$edge_log"
	assert_contains "profile-directory=Default" "$edge_log"
}

test_bb_browser_restarts_daemon_when_cdp_target_changes() {
	local tmp_home fake_bin daemon_log fetch_log token_file pid_file old_daemon_path old_pid daemon_ready_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	daemon_log="$tmp_home/daemon-restart.log"
	fetch_log="$tmp_home/fetch-restart.log"
	token_file="$tmp_home/.bb-browser/daemon.token"
	pid_file="$tmp_home/.bb-browser/daemon.pid"
	old_daemon_path="$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
	daemon_ready_file="$tmp_home/.daemon-ready"
	old_pid=""
	trap "kill '${old_pid:-}' >/dev/null 2>&1 || true; rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$token_file")" "$(dirname "$old_daemon_path")"
	: >"$old_daemon_path"
	printf '%s\n' 'stale-token' >"$token_file"
	bash -c "exec -a 'node $old_daemon_path -H 127.0.0.1 --cdp-host 127.0.0.1 --cdp-port 16666 --port 19824 --token stale-token' sleep 1000" &
	old_pid="$!"
	printf '%s\n' "$old_pid" >"$pid_file"

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/openssl" <<'EOF'
#!/bin/sh
printf '%s\n' 'new-token'
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    printf '%s\n' "\$*" >>"$daemon_log"
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/curl" <<EOF
#!/bin/sh
url=""
auth=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -H)
      shift
      auth="\$1"
      ;;
    *)
      url="\$1"
      ;;
  esac
  shift
done
printf '%s | %s\n' "\$auth" "\$url" >>"$fetch_log"
case "\$url" in
  http://127.0.0.1:19824/status)
    case "\$auth" in
      "Authorization: Bearer stale-token")
        printf '%s\n' '{"running":true}'
        exit 0
        ;;
      "Authorization: Bearer new-token")
        [ -f "$daemon_ready_file" ] || exit 22
        printf '%s\n' '{"running":true}'
        exit 0
        ;;
    esac
    ;;
esac
exit 22
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/openssl" "$fake_bin/node" "$fake_bin/curl"

	HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash -c "source '$REPO_ROOT/scripts/bb-browser-user.sh'; ensure_daemon_running 'http://127.0.0.1:24444'"

	grep -qF -- "--cdp-port 24444" "$daemon_log" || fail "Expected daemon restart with new CDP port in $daemon_log"
	grep -qF -- "--token new-token" "$daemon_log" || fail "Expected daemon restart with new token in $daemon_log"
	if kill -0 "$old_pid" >/dev/null 2>&1; then
		fail "Expected stale daemon process to be stopped: $old_pid"
	fi
	old_pid=""
}

test_bb_browser_doctor_finds_daemon_from_recorded_real_path_when_npm_root_drifts() {
	local tmp_home fake_bin managed_prefix state_file log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	managed_prefix=$(make_temp_dir)
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	log="$tmp_home/bb-browser-doctor-drift.log"
	trap "rm -rf '$tmp_home' '$fake_bin' '$managed_prefix'" RETURN

	mkdir -p "$(dirname "$state_file")" "$managed_prefix/bin" "$managed_prefix/lib/node_modules/bb-browser/dist" "$tmp_home/.config/microsoft-edge"
	cat >"$managed_prefix/bin/bb-browser" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  *) exit 0 ;;
esac
EOF
	chmod +x "$managed_prefix/bin/bb-browser"
	: >"$managed_prefix/lib/node_modules/bb-browser/dist/daemon.js"
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=0
PREEXISTING_BB_BROWSER_PATH=
PREEXISTING_WRAPPER=0
PREEXISTING_WRAPPER_BACKUP_PATH=
INSTALLED_VERSION=9.9.9
WRAPPER_PATH=$tmp_home/.local/bin/bb-browser-user
REAL_BB_BROWSER_PATH=$managed_prefix/bin/bb-browser
EOF

	cat >"$fake_bin/npm" <<'EOF'
#!/bin/sh
if [ "$1" = "root" ] && [ "$2" = "-g" ]; then
  printf '%s\n' '/tmp/drifted-node-modules'
  exit 0
fi
exit 1
EOF
	cat >"$fake_bin/node" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/microsoft-edge" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$managed_prefix/bin:$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/bb-browser-user.sh" doctor >"$log" 2>&1; then
		cat "$log" >&2
		fail "bb-browser-user.sh doctor drift case failed"
	fi
}

test_bb_browser_install_fails_without_supported_browser() {
	local tmp_home fake_bin managed_prefix log npm_log tool
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	managed_prefix=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-no-browser.log"
	npm_log="$tmp_home/npm-no-browser.log"
	trap "rm -rf '$tmp_home' '$fake_bin' '$managed_prefix'" RETURN

	for tool in basename cat chmod cp date dirname mkdir mktemp rm sleep whoami; do
		ln -s "$(command -v "$tool")" "$fake_bin/$tool"
	done

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "prefix" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$managed_prefix"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  mkdir -p "$managed_prefix/bin"
  cat >"$managed_prefix/bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$managed_prefix/bin/bb-browser"
fi
if [ "\$1" = "--prefix" ] && [ "\$2" = "$managed_prefix" ] && [ "\$3" = "uninstall" ] && [ "\$4" = "-g" ] && [ "\$5" = "bb-browser" ]; then
  rm -f "$managed_prefix/bin/bb-browser"
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
	assert_file_missing "$managed_prefix/bin/bb-browser"
}

test_bb_browser_install_preserves_preexisting_managed_prefix_artifact_on_failure() {
	local tmp_home fake_bin managed_prefix log npm_log tool
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	managed_prefix=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-preexisting-managed.log"
	npm_log="$tmp_home/npm-preexisting-managed.log"
	trap "rm -rf '$tmp_home' '$fake_bin' '$managed_prefix'" RETURN

	mkdir -p "$managed_prefix/bin"
	cat >"$managed_prefix/bin/bb-browser" <<'EOF'
#!/bin/sh
case "$1" in
  --version) echo 'bb-browser preexisting 1.0.0' ;;
  doctor) exit 1 ;;
  *) exit 0 ;;
esac
EOF
	chmod +x "$managed_prefix/bin/bb-browser"

	for tool in basename cat chmod cp date dirname mkdir mktemp rm sleep whoami; do
		ln -s "$(command -v "$tool")" "$fake_bin/$tool"
	done

	cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "prefix" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$managed_prefix"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$managed_prefix/bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser managed 9.9.9' ;;
  doctor) exit 1 ;;
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
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/uname"

	if HOME="$tmp_home" PATH="$managed_prefix/bin:$fake_bin" \
		/bin/bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh unexpectedly succeeded with preexisting managed package"
	fi

	assert_contains "install" "$npm_log"
	assert_contains "bb-browser@latest" "$npm_log"
	assert_contains "bb-browser 健康检查失败" "$log"
	assert_not_contains "uninstall -g bb-browser" "$npm_log"
	assert_file_missing "$tmp_home/.local/bin/bb-browser-user"
	assert_file_missing "$tmp_home/.local/state/dotfiles/bb-browser.env"
	assert_file_exists "$managed_prefix/bin/bb-browser"
	assert_contains "bb-browser preexisting 1.0.0" "$managed_prefix/bin/bb-browser"
}

test_bb_browser_wrapper_uses_managed_path_over_preexisting_path() {
	local tmp_home old_bin managed_prefix fake_bin log npm_log state_file curl_log ready_file daemon_ready_file
	tmp_home=$(make_temp_dir)
	old_bin=$(make_temp_dir)
	managed_prefix=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-bb-browser-conflict.log"
	npm_log="$tmp_home/npm-conflict.log"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	curl_log="$tmp_home/curl-conflict.log"
	ready_file="$tmp_home/.cdp-ready-19825"
	daemon_ready_file="$tmp_home/.daemon-ready"
	trap "rm -rf '$tmp_home' '$old_bin' '$managed_prefix' '$fake_bin'" RETURN

	mkdir -p "$tmp_home/.config/google-chrome" "$tmp_home/.config/microsoft-edge"
	cat >"$old_bin/bb-browser" <<'EOF'
#!/bin/sh
echo "old-bb-browser" >&2
exit 33
EOF
	chmod +x "$old_bin/bb-browser"

cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
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
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"2.0.0"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$managed_prefix/bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<EOF
#!/bin/sh
case "\$1" in
  *daemon.js)
    : >"$daemon_ready_file"
    exit 0
    ;;
esac
exit 0
EOF
	cat >"$fake_bin/google-chrome" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<EOF
#!/bin/sh
url=""
for arg in "\$@"; do
  url="\$arg"
done
printf '%s\n' "\$url" >>"$curl_log"
case "\$url" in
  http://127.0.0.1:19824/status)
    [ -f "$daemon_ready_file" ] || exit 22
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
  http://127.0.0.1:19825/json/version)
    : >"$ready_file"
    printf '%s\n' '{}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/google-chrome" "$fake_bin/microsoft-edge" "$fake_bin/curl" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$old_bin:$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_bb_browser.sh conflict case failed"
	fi

	assert_file_exists "$state_file"
	assert_contains "PREEXISTING_BB_BROWSER=1" "$state_file"
	assert_contains "PREEXISTING_BB_BROWSER_PATH=$old_bin/bb-browser" "$state_file"
	assert_contains "$managed_prefix/bin/bb-browser" "$state_file"
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
	assert_contains "http://127.0.0.1:19825/json/version" "$curl_log"
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
PREEXISTING_BB_BROWSER_PATH=/usr/local/bin/bb-browser
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

test_bb_browser_uninstall_restores_preexisting_command_shim() {
	local tmp_home fake_bin log shim_path shim_backup_path config_file state_file original_shim_content
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-bb-browser-shim-restore.log"
	shim_path="$tmp_home/.local/bin/bb-browser"
	shim_backup_path="$tmp_home/backup dir/bb-browser.preexisting"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	original_shim_content='#!/bin/sh
echo "user shim preserved"
'
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$shim_path")" "$(dirname "$shim_backup_path")" "$(dirname "$config_file")" "$(dirname "$state_file")"
	cat >"$shim_path" <<'EOF'
#!/bin/sh
echo "managed shim"
EOF
	chmod +x "$shim_path"
	printf '%s' "$original_shim_content" >"$shim_backup_path"
	chmod +x "$shim_backup_path"
	cat >"$config_file" <<'EOF'
{"managed":true}
EOF
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=1
PREEXISTING_BB_BROWSER_PATH=/usr/local/bin/bb-browser
PREEXISTING_SHIM=1
PREEXISTING_SHIM_BACKUP_PATH=$(printf '%q' "$shim_backup_path")
SHIM_PATH=$shim_path
PREEXISTING_WRAPPER=0
WRAPPER_PATH=$tmp_home/.local/bin/bb-browser-user
REAL_BB_BROWSER_PATH=/usr/local/bin/bb-browser
EOF

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh bb-browser shim restore case failed"
	fi

	assert_file_exists "$shim_path"
	assert_contains "user shim preserved" "$shim_path"
	assert_file_missing "$config_file"
	assert_file_missing "$state_file"
	assert_file_missing "$shim_backup_path"
}

test_bb_browser_install_and_uninstall_restore_preexisting_wrapper() {
	local tmp_home fake_bin install_log uninstall_log npm_log wrapper_path state_file
	local site_path original_wrapper_content original_site_content
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	install_log="$tmp_home/install-bb-browser-wrapper-restore.log"
	uninstall_log="$tmp_home/uninstall-bb-browser-wrapper-restore.log"
	npm_log="$tmp_home/npm-wrapper-restore.log"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	site_path="$tmp_home/.bb-browser/bb-sites/xiaohongshu/search.js"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	original_wrapper_content='#!/bin/sh
echo "user wrapper preserved"
'
	original_site_content='legacy xiaohongshu adapter preserved
'
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$site_path")" "$tmp_home/.config/google-chrome" "$tmp_home/.config/microsoft-edge"
	printf '%s' "$original_wrapper_content" >"$wrapper_path"
	printf '%s' "$original_site_content" >"$site_path"
	chmod +x "$wrapper_path"

cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
fi
if [ "\$1" = "install" ] && [ "\$2" = "-g" ] && [ "\$3" = "bb-browser@latest" ]; then
  cat >"$fake_bin/bb-browser" <<'INNER'
#!/bin/sh
case "\$1" in
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$fake_bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
fi
exit 0
EOF
	cat >"$fake_bin/node" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/google-chrome" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
url=""
for arg in "$@"; do
  url="$arg"
done
case "$url" in
  http://127.0.0.1:19825/json/version)
    printf '%s\n' '{}'
    exit 0
    ;;
  http://127.0.0.1:19824/status)
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/google-chrome" "$fake_bin/microsoft-edge" "$fake_bin/curl" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$install_log" 2>&1; then
		cat "$install_log" >&2
		fail "install_bb_browser.sh preexisting wrapper restore test failed"
	fi

	assert_file_exists "$state_file"
	assert_contains "PREEXISTING_BB_BROWSER=0" "$state_file"
	assert_contains 'PREEXISTING_WRAPPER=1' "$state_file"
	assert_not_contains "user wrapper preserved" "$wrapper_path"
	assert_not_contains "legacy xiaohongshu adapter preserved" "$site_path"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$uninstall_log" 2>&1; then
		cat "$uninstall_log" >&2
		fail "uninstall.sh preexisting wrapper restore test failed"
	fi

	assert_file_exists "$wrapper_path"
	assert_file_exists "$site_path"
	assert_contains "user wrapper preserved" "$wrapper_path"
	assert_contains "legacy xiaohongshu adapter preserved" "$site_path"
	assert_file_missing "$state_file"
	assert_contains "uninstall" "$npm_log"
}

test_bb_browser_reinstall_preserves_managed_ownership() {
	local tmp_home fake_bin managed_prefix install_log reinstall_log uninstall_log npm_log state_file wrapper_path
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	managed_prefix=$(make_temp_dir)
	install_log="$tmp_home/install-bb-browser-reinstall.log"
	reinstall_log="$tmp_home/reinstall-bb-browser.log"
	uninstall_log="$tmp_home/uninstall-bb-browser-reinstall.log"
	npm_log="$tmp_home/npm-reinstall.log"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	trap "rm -rf '$tmp_home' '$fake_bin' '$managed_prefix'" RETURN

	mkdir -p "$tmp_home/.config/google-chrome" "$tmp_home/.config/microsoft-edge"
cat >"$fake_bin/npm" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$npm_log"
if [ "\$1" = "root" ] && [ "\$2" = "-g" ]; then
  printf '%s\n' "$tmp_home/fake-node-modules"
  exit 0
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
  --version) echo 'bb-browser 9.9.9' ;;
  --mcp)
    cat >/dev/null
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bb-browser","version":"9.9.9"}}}'
    printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[]}}'
    exit 0
    ;;
  *) exit 0 ;;
esac
INNER
  chmod +x "$managed_prefix/bin/bb-browser"
  mkdir -p "$tmp_home/fake-node-modules/bb-browser/dist"
  : >"$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
  exit 0
fi
if [ "\$1" = "--prefix" ] && [ "\$2" = "$managed_prefix" ] && [ "\$3" = "uninstall" ] && [ "\$4" = "-g" ] && [ "\$5" = "bb-browser" ]; then
  rm -f "$managed_prefix/bin/bb-browser"
  exit 0
fi
exit 0
EOF
	cat >"$fake_bin/node" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/google-chrome" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/microsoft-edge" <<'EOF'
#!/bin/sh
exit 0
EOF
	cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
url=""
for arg in "$@"; do
  url="$arg"
done
case "$url" in
  http://127.0.0.1:19825/json/version)
    printf '%s\n' '{}'
    exit 0
    ;;
  http://127.0.0.1:19824/status)
    printf '%s\n' '{"running":true}'
    exit 0
    ;;
esac
exit 22
EOF
	cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
echo 'Linux'
EOF
	chmod +x "$fake_bin/npm" "$fake_bin/node" "$fake_bin/google-chrome" "$fake_bin/microsoft-edge" "$fake_bin/curl" "$fake_bin/uname"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$install_log" 2>&1; then
		cat "$install_log" >&2
		fail "install_bb_browser.sh initial managed reinstall test failed"
	fi

	assert_file_exists "$state_file"
	assert_contains "PREEXISTING_BB_BROWSER=0" "$state_file"
	assert_contains "PREEXISTING_WRAPPER=0" "$state_file"
	assert_contains "REAL_BB_BROWSER_PATH=$managed_prefix/bin/bb-browser" "$state_file"
	assert_file_exists "$wrapper_path"

	if ! HOME="$tmp_home" PATH="$managed_prefix/bin:$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		BB_BROWSER_CDP_URL="http://127.0.0.1:19825" \
		bash "$REPO_ROOT/scripts/install_bb_browser.sh" >"$reinstall_log" 2>&1; then
		cat "$reinstall_log" >&2
		fail "install_bb_browser.sh second managed reinstall test failed"
	fi

	assert_contains "PREEXISTING_BB_BROWSER=0" "$state_file"
	assert_contains 'PREEXISTING_BB_BROWSER_PATH=' "$state_file"
	assert_contains "PREEXISTING_WRAPPER=0" "$state_file"
	assert_contains "REAL_BB_BROWSER_PATH=$managed_prefix/bin/bb-browser" "$state_file"

	if ! HOME="$tmp_home" PATH="$managed_prefix/bin:$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$uninstall_log" 2>&1; then
		cat "$uninstall_log" >&2
		fail "uninstall.sh managed reinstall ownership test failed"
	fi

	assert_file_missing "$state_file"
	assert_file_missing "$wrapper_path"
	assert_file_missing "$managed_prefix/bin/bb-browser"
	assert_contains "$managed_prefix" "$npm_log"
	assert_contains "uninstall" "$npm_log"
}

test_bb_browser_uninstall_removes_managed_global_install() {
	local tmp_home fake_bin log npm_log wrapper_path config_file state_file token_file pid_file daemon_path daemon_pid
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-bb-browser-managed.log"
	npm_log="$tmp_home/npm-managed.log"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	config_file="$tmp_home/.config/dotfiles/bb-browser.json"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	token_file="$tmp_home/.bb-browser/daemon.token"
	pid_file="$tmp_home/.bb-browser/daemon.pid"
	daemon_path="$tmp_home/fake-node-modules/bb-browser/dist/daemon.js"
	daemon_pid=""

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$config_file")" "$(dirname "$state_file")" "$(dirname "$token_file")" "$(dirname "$daemon_path")"
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
PREEXISTING_BB_BROWSER_PATH=
INSTALLED_VERSION=9.9.9
WRAPPER_PATH=$wrapper_path
REAL_BB_BROWSER_PATH=/usr/local/bin/bb-browser
EOF
	printf '%s\n' 'daemon-token' >"$token_file"
	: >"$daemon_path"
	bash -c "exec -a 'node $daemon_path' sleep 1000" &
	daemon_pid="$!"
	trap "kill '$daemon_pid' >/dev/null 2>&1 || true; rm -rf '$tmp_home' '$fake_bin'" RETURN
	printf '%s\n' "$daemon_pid" >"$pid_file"

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
	if kill -0 "$daemon_pid" >/dev/null 2>&1; then
		fail "Expected daemon process to be stopped: $daemon_pid"
	fi
	assert_file_missing "$token_file"
	assert_file_missing "$pid_file"
}

test_bb_browser_uninstall_restores_wrapper_backup_with_escaped_path_without_python() {
	local tmp_home fake_bin log wrapper_path state_file backup_path
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-bb-browser-escaped-path.log"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	backup_path="$tmp_home/backup dir/bb-browser-user.preexisting"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$state_file")" "$(dirname "$backup_path")"
	cat >"$wrapper_path" <<'EOF'
#!/bin/sh
echo "current wrapper"
EOF
	chmod +x "$wrapper_path"
	cat >"$backup_path" <<'EOF'
#!/bin/sh
echo "restored wrapper"
EOF
	chmod +x "$backup_path"
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=1
PREEXISTING_WRAPPER=1
PREEXISTING_WRAPPER_BACKUP_PATH=$(printf '%q' "$backup_path")
REAL_BB_BROWSER_PATH=$(printf '%q' "/usr/local/bin/bb-browser")
EOF

	cat >"$fake_bin/python3" <<'EOF'
#!/bin/sh
printf '%s\n' "${2:-}"
exit 0
EOF
	chmod +x "$fake_bin/python3"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh escaped backup path case failed"
	fi

	assert_file_exists "$wrapper_path"
	assert_contains "restored wrapper" "$wrapper_path"
	assert_file_missing "$backup_path"
	assert_file_missing "$state_file"
}

test_bb_browser_state_readers_use_consistent_field_order() {
	local tmp_home state_file install_partial uninstall_partial install_output uninstall_output
	tmp_home=$(make_temp_dir)
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	install_partial=$(mktemp "$REPO_ROOT/scripts/install_bb_browser.partial.XXXXXX")
	uninstall_partial=$(mktemp "$REPO_ROOT/scripts/uninstall.partial.XXXXXX")
	trap "rm -rf '$tmp_home'; rm -f '$install_partial' '$uninstall_partial'" RETURN

	mkdir -p "$(dirname "$state_file")"
	cat >"$state_file" <<'EOF'
PREEXISTING_BB_BROWSER=1
PREEXISTING_BB_BROWSER_PATH=/usr/local/bin/bb-browser
PREEXISTING_WRAPPER=1
PREEXISTING_WRAPPER_BACKUP_PATH=/tmp/bb-browser-user.preexisting
INSTALLED_VERSION=9.9.9
WRAPPER_PATH=/tmp/bb-browser-user
REAL_BB_BROWSER_PATH=/opt/managed/bin/bb-browser
EOF

	awk '/^main "\$@"/{exit} {print}' "$REPO_ROOT/scripts/install_bb_browser.sh" >"$install_partial"
	awk '/^# 解析参数/{exit} {print}' "$REPO_ROOT/uninstall.sh" >"$uninstall_partial"

	install_output="$(
		HOME="$tmp_home" bash -lc "STATE_FILE='$state_file'; source '$install_partial'; read_existing_install_state"
	)"
	uninstall_output="$(
		HOME="$tmp_home" bash -lc "source '$uninstall_partial'; read_bb_browser_install_state '$state_file'"
	)"

	assert_equal "$install_output" "$uninstall_output" "bb-browser state reader output"
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
PREEXISTING_BB_BROWSER_PATH=
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
	assert_not_contains '"installMethod": "native"' "$tmp_home/.claude.json"
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
	assert_not_contains '[mcp_servers.bb-browser]' "$tmp_home/.codex/config.toml"
	assert_not_contains 'args = ["-lc",' "$tmp_home/.codex/config.toml"
	assert_contains "[projects.\"$external_project\"]" "$tmp_home/.codex/config.toml"
	assert_contains "[projects.\"$tmp_home\"]" "$tmp_home/.codex/config.toml"
	assert_contains "[projects.\"$child_project\"]" "$tmp_home/.codex/config.toml"
}

test_codex_config_includes_bb_browser_when_wrapper_exists() {
	local tmp_home fake_bin log superpowers_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-codex-wrapper.log"
	superpowers_repo=$(make_fake_superpowers_repo)
	trap "rm -rf '$tmp_home' '$fake_bin' '$superpowers_repo'" RETURN

	mkdir -p "$tmp_home/.local/bin"
	cat >"$tmp_home/.local/bin/bb-browser-user" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$tmp_home/.local/bin/bb-browser-user"

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
		fail "install_dotfiles.sh codex wrapper merge failed"
	fi

	assert_contains '[mcp_servers.bb-browser]' "$tmp_home/.codex/config.toml"
	assert_contains 'command = "bash"' "$tmp_home/.codex/config.toml"
	assert_contains 'args = ["-c", "\"$HOME/.local/bin/bb-browser-user\" --mcp"]' "$tmp_home/.codex/config.toml"
}

test_file_deps_include_codex_deploy_for_bb_browser_install() {
	local has_codex_dep has_patch_dep has_xiaohongshu_template_dep
	has_codex_dep="$(
		node -e '
const fs = require("fs");
const deps = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const list = deps["scripts/install_bb_browser.sh"] || [];
process.stdout.write(list.includes("scripts/deploy_codex_config.sh") ? "yes" : "no");
' "$REPO_ROOT/.claude/file-deps.json"
	)"
	has_patch_dep="$(
		node -e '
const fs = require("fs");
const deps = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const list = deps["scripts/install_bb_browser.sh"] || [];
process.stdout.write(list.includes("scripts/patch_bb_browser_dist.mjs") ? "yes" : "no");
' "$REPO_ROOT/.claude/file-deps.json"
	)"
	has_xiaohongshu_template_dep="$(
		node -e '
const fs = require("fs");
const deps = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const list = deps["scripts/install_bb_browser.sh"] || [];
process.stdout.write(list.includes("scripts/bb-browser-sites/xiaohongshu/search.js") ? "yes" : "no");
' "$REPO_ROOT/.claude/file-deps.json"
	)"
	assert_equal "yes" "$has_codex_dep" "install_bb_browser codex deploy dependency"
	assert_equal "yes" "$has_patch_dep" "install_bb_browser patch helper dependency"
	assert_equal "yes" "$has_xiaohongshu_template_dep" "install_bb_browser xiaohongshu template dependency"
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
	local tmp_home fake_bin log mcp_log state_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-bb-browser.log"
	mcp_log="$tmp_home/claude-mcp-add-json.json"
	state_file="$tmp_home/.local/state/dotfiles/claude-bb-browser-mcp.env"
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
	assert_file_exists "$state_file"
	assert_contains "DOTFILES_MANAGED=1" "$state_file"
}

test_claude_skips_bb_browser_mcp_without_wrapper() {
	local tmp_home fake_bin log mcp_log remove_log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-no-bb-browser.log"
	mcp_log="$tmp_home/claude-mcp-add-json.json"
	remove_log="$tmp_home/claude-mcp-remove.log"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli "$fake_bin" $'bb-browser: stdio\ntavily: stdio\nfetch: stdio' "$mcp_log" "$remove_log"

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

	mkdir -p "$tmp_home/.claude/skills/study-master"
	printf '# study-master\n' >"$tmp_home/.claude/skills/study-master/SKILL.md"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_claude_code.sh wrapper-absent MCP test failed"
	fi

	assert_file_exists "$mcp_log"
	assert_not_contains 'bb-browser-user' "$mcp_log"
	assert_file_missing "$remove_log"
}

test_claude_removes_managed_bb_browser_mcp_without_wrapper() {
	local tmp_home fake_bin log mcp_log remove_log state_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-no-bb-browser-managed.log"
	mcp_log="$tmp_home/claude-mcp-add-json.json"
	remove_log="$tmp_home/claude-mcp-remove.log"
	state_file="$tmp_home/.local/state/dotfiles/claude-bb-browser-mcp.env"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli "$fake_bin" $'bb-browser: stdio\ntavily: stdio\nfetch: stdio' "$mcp_log" "$remove_log"

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

	mkdir -p "$tmp_home/.claude/skills/study-master" "$(dirname "$state_file")"
	printf '# study-master\n' >"$tmp_home/.claude/skills/study-master/SKILL.md"
	cat >"$state_file" <<'EOF'
DOTFILES_MANAGED=1
EOF

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_claude_code.sh managed wrapper-absent MCP cleanup test failed"
	fi

	assert_file_exists "$mcp_log"
	assert_not_contains 'bb-browser-user' "$mcp_log"
	assert_file_exists "$remove_log"
	assert_contains "bb-browser" "$remove_log"
	assert_file_missing "$state_file"
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
	mkdir -p "$tmp_home/.local/state/dotfiles"
	cat >"$tmp_home/.local/state/dotfiles/claude-bb-browser-mcp.env" <<'EOF'
DOTFILES_MANAGED=1
EOF

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --claude --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh --claude failed"
	fi

	assert_file_exists "$remove_log"
	assert_contains "bb-browser" "$remove_log"
	assert_file_missing "$tmp_home/.local/state/dotfiles/claude-bb-browser-mcp.env"
}

test_uninstall_claude_preserves_user_owned_bb_browser_mcp() {
	local tmp_home fake_bin log remove_log
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-claude-bb-browser-user-owned.log"
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
		fail "uninstall.sh --claude user-owned MCP preservation failed"
	fi

	assert_file_exists "$remove_log"
	assert_not_contains "bb-browser" "$remove_log"
}

test_uninstall_claude_removes_study_master_vendor_repo() {
	local tmp_home fake_bin log remove_log vendor_repo sibling_dir sibling_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-claude-study-master-vendor.log"
	remove_log="$tmp_home/claude-mcp-remove.log"
	vendor_repo="$tmp_home/.claude/vendor/agent-study-skills"
	sibling_dir="$tmp_home/.claude/vendor/keep"
	sibling_file="$sibling_dir/marker.txt"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli "$fake_bin" $'fetch: stdio' "$tmp_home/claude-mcp-add-json.json" "$remove_log"

	mkdir -p "$vendor_repo/.git" "$tmp_home/.claude/skills/study-master" "$tmp_home/.claude/hooks" "$sibling_dir"
	printf 'repo\n' >"$vendor_repo/README.md"
	printf '# study-master\n' >"$tmp_home/.claude/skills/study-master/SKILL.md"
	printf '#!/bin/sh\nexit 0\n' >"$tmp_home/.claude/hooks/check-study_master.sh"
	printf 'keep\n' >"$sibling_file"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --claude --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh --claude vendor cleanup test failed"
	fi

	assert_file_missing "$vendor_repo"
	assert_file_exists "$sibling_file"
}

test_dotfiles_uninstall_removes_wrapper_integrations() {
	local tmp_home fake_bin log remove_log shim_path wrapper_path state_file codex_config mcp_state_file
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-dotfiles-wrapper-integrations.log"
	remove_log="$tmp_home/claude-mcp-remove.log"
	shim_path="$tmp_home/.local/bin/bb-browser"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	mcp_state_file="$tmp_home/.local/state/dotfiles/claude-bb-browser-mcp.env"
	codex_config="$tmp_home/.codex/config.toml"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli "$fake_bin" $'bb-browser: stdio\nfetch: stdio' "$tmp_home/claude-mcp-add-json.json" "$remove_log"

	mkdir -p "$(dirname "$shim_path")" "$(dirname "$wrapper_path")" "$(dirname "$state_file")" "$(dirname "$codex_config")"
	cat >"$shim_path" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$shim_path"
	cat >"$wrapper_path" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$wrapper_path"
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=1
PREEXISTING_BB_BROWSER_PATH=/usr/local/bin/bb-browser
PREEXISTING_SHIM=0
SHIM_PATH=$shim_path
WRAPPER_PATH=$wrapper_path
REAL_BB_BROWSER_PATH=/usr/local/bin/bb-browser
EOF
	cat >"$mcp_state_file" <<'EOF'
DOTFILES_MANAGED=1
EOF
	cat >"$codex_config" <<'EOF'
model = "gpt-5.4"

[mcp_servers.fetch]
command = "npx"
args = ["-y", "@kazuph/mcp-fetch"]

[mcp_servers.bb-browser]
command = "bash"
args = ["-c", "\"$HOME/.local/bin/bb-browser-user\" --mcp"]
EOF

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh --dotfiles wrapper integration cleanup failed"
	fi

	assert_file_missing "$shim_path"
	assert_file_missing "$wrapper_path"
	assert_file_missing "$state_file"
	assert_file_missing "$mcp_state_file"
	assert_file_exists "$remove_log"
	assert_contains "bb-browser" "$remove_log"
	assert_file_exists "$codex_config"
	assert_contains '[mcp_servers.fetch]' "$codex_config"
	assert_not_contains '[mcp_servers.bb-browser]' "$codex_config"
}

test_dotfiles_uninstall_preserves_user_owned_bb_browser_mcp() {
	local tmp_home fake_bin log remove_log wrapper_path state_file codex_config
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/uninstall-dotfiles-wrapper-integrations-user-owned.log"
	remove_log="$tmp_home/claude-mcp-remove.log"
	wrapper_path="$tmp_home/.local/bin/bb-browser-user"
	state_file="$tmp_home/.local/state/dotfiles/bb-browser.env"
	codex_config="$tmp_home/.codex/config.toml"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli "$fake_bin" $'bb-browser: stdio\nfetch: stdio' "$tmp_home/claude-mcp-add-json.json" "$remove_log"

	mkdir -p "$(dirname "$wrapper_path")" "$(dirname "$state_file")" "$(dirname "$codex_config")"
	cat >"$wrapper_path" <<'EOF'
#!/bin/sh
exit 0
EOF
	chmod +x "$wrapper_path"
	cat >"$state_file" <<EOF
PREEXISTING_BB_BROWSER=1
PREEXISTING_BB_BROWSER_PATH=/usr/local/bin/bb-browser
PREEXISTING_WRAPPER=0
WRAPPER_PATH=$wrapper_path
REAL_BB_BROWSER_PATH=/usr/local/bin/bb-browser
EOF
	cat >"$codex_config" <<'EOF'
model = "gpt-5.4"

[mcp_servers.fetch]
command = "npx"
args = ["-y", "@kazuph/mcp-fetch"]

[mcp_servers.bb-browser]
command = "bash"
args = ["-c", "\"$HOME/.local/bin/bb-browser-user\" --mcp"]
EOF

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/uninstall.sh" --dotfiles --force >"$log" 2>&1; then
		cat "$log" >&2
		fail "uninstall.sh --dotfiles user-owned MCP preservation failed"
	fi

	assert_file_missing "$wrapper_path"
	assert_file_missing "$state_file"
	assert_file_missing "$remove_log"
	assert_file_exists "$codex_config"
	assert_contains '[mcp_servers.fetch]' "$codex_config"
	assert_not_contains '[mcp_servers.bb-browser]' "$codex_config"
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
	cat >"$tmp_home/.claude.json" <<'EOF'
{
  "installMethod": "native",
  "autoUpdates": true
}
EOF
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
	assert_not_contains '"installMethod": "native"' "$tmp_home/.claude.json"
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

test_claude_updates_marketplaces_and_plugins() {
	local tmp_home fake_bin log install_log update_log marketplace_log expected_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log="$tmp_home/install-claude-updates.log"
	install_log="$tmp_home/claude-plugin-install.log"
	update_log="$tmp_home/claude-plugin-update.log"
	marketplace_log="$tmp_home/claude-marketplace-update.log"
	expected_repo="https://github.com/Learner-Geek-Perfectionist/agent-study-skills.git"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli_with_update_logs \
		"$fake_bin" \
		$'github@claude-plugins-official\nsuperpowers@superpowers-marketplace\nexample-skills@anthropic-agent-skills' \
		$'tavily: stdio\nfetch: stdio\nopen-websearch: stdio\nbb-browser: stdio' \
		"$tmp_home/claude-mcp-add-json.json" \
		"$tmp_home/claude-mcp-remove.log" \
		"$install_log" \
		"$update_log" \
		"$marketplace_log"

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
	write_fake_study_master_git "$fake_bin" "$expected_repo" "# study-master v1" "# study-master v2" "$tmp_home/git.log"
	chmod +x "$fake_bin/rustup" "$fake_bin/npm" "$fake_bin/dotnet" "$fake_bin/curl"

	mkdir -p "$tmp_home/.claude/plugins" "$tmp_home/.claude/skills" "$tmp_home/.claude/hooks"
	cat >"$tmp_home/.claude/plugins/known_marketplaces.json" <<'EOF'
{
  "anthropic-agent-skills": {
    "source": {
      "source": "github",
      "repo": "anthropics/skills"
    }
  },
  "superpowers-marketplace": {
    "source": {
      "source": "github",
      "repo": "obra/superpowers-marketplace"
    }
  },
  "claude-plugins-official": {
    "source": {
      "source": "github",
      "repo": "anthropics/claude-plugins-official"
    }
  },
  "claude-hud": {
    "source": {
      "source": "github",
      "repo": "jarrodwatts/claude-hud"
    }
  }
}
EOF

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log" 2>&1; then
		cat "$log" >&2
		fail "install_claude_code.sh update test failed"
	fi

	assert_file_exists "$marketplace_log"
	assert_contains "__all__" "$marketplace_log"
	assert_file_exists "$update_log"
	assert_contains "github@claude-plugins-official" "$update_log"
	assert_contains "superpowers@superpowers-marketplace" "$update_log"
	assert_contains "example-skills@anthropic-agent-skills" "$update_log"
	assert_file_exists "$install_log"
	assert_contains "pyright-lsp@claude-plugins-official" "$install_log"
}

test_claude_refreshes_study_master_on_rerun() {
	local tmp_home fake_bin log_first log_second expected_repo
	tmp_home=$(make_temp_dir)
	fake_bin=$(make_temp_dir)
	log_first="$tmp_home/install-claude-study-master-first.log"
	log_second="$tmp_home/install-claude-study-master-second.log"
	expected_repo="https://github.com/Learner-Geek-Perfectionist/agent-study-skills.git"
	trap "rm -rf '$tmp_home' '$fake_bin'" RETURN

	write_fake_claude_cli_with_update_logs \
		"$fake_bin" \
		'' \
		$'tavily: stdio\nfetch: stdio\nopen-websearch: stdio\nbb-browser: stdio' \
		"$tmp_home/claude-mcp-add-json.json" \
		"$tmp_home/claude-mcp-remove.log" \
		"$tmp_home/claude-plugin-install.log" \
		"$tmp_home/claude-plugin-update.log" \
		"$tmp_home/claude-marketplace-update.log"

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
	write_fake_study_master_git "$fake_bin" "$expected_repo" "# study-master v1" "# study-master v2" "$tmp_home/git.log"
	chmod +x "$fake_bin/rustup" "$fake_bin/npm" "$fake_bin/dotnet" "$fake_bin/curl"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log_first" 2>&1; then
		cat "$log_first" >&2
		fail "install_claude_code.sh initial study-master refresh test failed"
	fi

	assert_contains "# study-master v1" "$tmp_home/.claude/skills/study-master/SKILL.md"

	if ! HOME="$tmp_home" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		bash "$REPO_ROOT/scripts/install_claude_code.sh" >"$log_second" 2>&1; then
		cat "$log_second" >&2
		fail "install_claude_code.sh rerun study-master refresh test failed"
	fi

	assert_contains "# study-master v2" "$tmp_home/.claude/skills/study-master/SKILL.md"
	assert_contains "pull " "$tmp_home/git.log"
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

run_kitty_ssh_utils_case() {
	local scenario="$1" cwd_value="$2" output_file="$3"

	REPO_ROOT="$REPO_ROOT" SCENARIO="$scenario" CASE_CWD="$cwd_value" python3 - <<'PY' >"$output_file"
import importlib.util
import json
import os
import pathlib
import sys
import types
from urllib.parse import urlparse

captured = {}


def fake_set_cwd_in_cmdline(cwd, argv):
    for idx, token in enumerate(tuple(argv)):
        if token == "--kitten" and idx + 1 < len(argv) and argv[idx + 1].startswith("cwd="):
            argv[idx + 1] = f"cwd={cwd}"
            return
        if token.startswith("--kitten=cwd="):
            argv[idx] = f"--kitten=cwd={cwd}"
            return

    argv[3:3] = ["--kitten", f"cwd={cwd}"]


class FakeConnectionData:
    def __init__(self, hostname):
        self.hostname = hostname


def fake_is_kitten_cmdline(argv):
    return argv[:2] == ["kitten", "ssh"] or argv[:3] == ["kitty", "+kitten", "ssh"]


def fake_get_connection_data(argv, extra_args=()):
    if not fake_is_kitten_cmdline(argv):
        return None

    for token in reversed(argv):
        if token in {"kitty", "kitten", "+kitten", "ssh"}:
            continue
        if token.startswith("-") or token.startswith("cwd="):
            continue
        if token.startswith("--kitten"):
            if "--kitten" in extra_args:
                continue
            return None
        if token.startswith("ssh://"):
            parsed = urlparse(token)
            return FakeConnectionData(parsed.hostname or "")
        return FakeConnectionData(token)

    return None


def fake_parse_launch_args(args):
    captured["args"] = args
    return args, []


def fake_launch(boss, opts, remaining):
    captured["opts"] = opts
    captured["remaining"] = remaining


kitty_pkg = types.ModuleType("kitty")
kitty_pkg.__path__ = []
kitty_launch_mod = types.ModuleType("kitty.launch")
kitty_kittens_mod = types.ModuleType("kittens")
kitty_kittens_mod.__path__ = []
kitty_kittens_ssh_mod = types.ModuleType("kittens.ssh")
kitty_kittens_ssh_mod.__path__ = []
kitty_kittens_ssh_utils_mod = types.ModuleType("kittens.ssh.utils")
kitty_launch_mod.launch = fake_launch
kitty_launch_mod.parse_launch_args = fake_parse_launch_args
kitty_kittens_ssh_utils_mod.set_cwd_in_cmdline = fake_set_cwd_in_cmdline
kitty_kittens_ssh_utils_mod.is_kitten_cmdline = fake_is_kitten_cmdline
kitty_kittens_ssh_utils_mod.get_connection_data = fake_get_connection_data
sys.modules["kitty"] = kitty_pkg
sys.modules["kitty.launch"] = kitty_launch_mod
sys.modules["kittens"] = kitty_kittens_mod
sys.modules["kittens.ssh"] = kitty_kittens_ssh_mod
sys.modules["kittens.ssh.utils"] = kitty_kittens_ssh_utils_mod

repo_root = pathlib.Path(os.environ["REPO_ROOT"])
spec = importlib.util.spec_from_file_location(
    "ssh_utils_under_test",
    repo_root / ".config/kitty/ssh_utils.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

scenario = os.environ["SCENARIO"]
cwd_value = os.environ.get("CASE_CWD") or None


class Child:
    foreground_processes = []


class Screen:
    last_reported_cwd = None


class Window:
    id = 42
    child = Child()
    cwd_of_child = "/Users/local/path"
    screen = Screen()

    def ssh_kitten_cmdline(self):
        if scenario == "ssh":
            return ["kitten", "ssh", "--kitten", "cwd=/placeholder", "yumi"]
        if scenario == "kitty-ssh":
            return ["kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "yumi"]
        if scenario == "inline-kitten":
            return ["kitten", "ssh", "--kitten=cwd=/placeholder", "yumi"]
        if scenario == "kitty-inline-kitten":
            return ["kitty", "+kitten", "ssh", "--kitten=cwd=/placeholder", "yumi"]
        if scenario == "uri-kitten":
            return ["kitty", "+kitten", "ssh", "--kitten=cwd=/placeholder", "ssh://alice@example.com:2222"]
        return None


window = Window()
cmdline = None
if scenario in {"ssh", "inline-kitten", "missing-cwd"}:
    cmdline = ["ssh", "yumi"]
elif scenario in {"kitty-ssh", "kitty-inline-kitten"}:
    cmdline = ["kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "yumi"]
elif scenario == "uri-kitten":
    cmdline = ["kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "ssh://alice@example.com:2222"]
if cmdline is not None:
    window.child.foreground_processes = [{"cmdline": cmdline}]
if scenario in {"ssh", "kitty-ssh", "inline-kitten", "kitty-inline-kitten", "uri-kitten"} and cwd_value is not None:
    window.screen.last_reported_cwd = f"file://{cwd_value.replace(' ', '%20')}"
if scenario == "missing-cwd":
    window.screen.last_reported_cwd = None


class Boss:
    active_window = window
    window_id_map = {42: window}


module.smart_launch(Boss(), "tab", 42)
print(json.dumps({"args": captured["args"], "remaining": captured["remaining"]}))
PY
}

assert_kitty_remote_launch_matches() {
	local output_file="$1" expected_destination="$2"
	python3 - "$output_file" "$expected_destination" <<'PY'
import json
import pathlib
import shlex
import sys

output_path = pathlib.Path(sys.argv[1])
expected_destination = sys.argv[2]
data = json.loads(output_path.read_text())
args = data["args"]
expected_prefix = ["--type=tab", "--source-window=id:42"]
if args[:2] != expected_prefix:
    raise SystemExit(f"Remote args prefix mismatch: {args!r}")
if len(args) < 5:
    raise SystemExit(f"Remote args too short: {args!r}")
if args[-3:-1] != ["zsh", "-c"]:
    raise SystemExit(f"Remote launcher not ['zsh','-c']: {args!r}")

cmd = args[-1]
if "kitten ssh" not in cmd:
    raise SystemExit(f"Remote command missing kitten ssh text: {cmd!r}")
if "fell back to local shell" not in cmd:
    raise SystemExit(f"Missing fallback notice: {cmd!r}")
if "if " not in cmd or " else " not in cmd or not cmd.rstrip().endswith("fi"):
    raise SystemExit(f"Remote command missing failure-path control flow: {cmd!r}")
if cmd.count("exec zsh -i") < 2:
    raise SystemExit(f"Remote command must reach local shell on both paths: {cmd!r}")

tokens = [token.rstrip(";") for token in shlex.split(cmd)]
if "ssh" not in tokens or ("kitten" not in tokens and "+kitten" not in tokens):
    raise SystemExit(f"Remote command missing kitten ssh tokens: {tokens!r}")
if "--kitten" not in tokens:
    raise SystemExit(f"Remote command missing --kitten token: {tokens!r}")
if expected_destination not in tokens:
    raise SystemExit(f"Remote destination mismatch: {tokens!r}")
if "cwd=/srv/my project" not in tokens:
    raise SystemExit(f"Remote cwd token split: {tokens!r}")
for opt in (
    "-oBatchMode=yes",
    "-oConnectTimeout=2",
    "-oConnectionAttempts=1",
    "-oStrictHostKeyChecking=yes",
):
    if opt not in tokens:
        raise SystemExit(f"Missing ssh guard option {opt}: {tokens!r}")
PY
}

test_kitty_smart_launch_uses_last_reported_for_local_windows() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/local-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case local "/Users/local/path" "$output_file"

	python3 - <<PY
import json
import pathlib

data = json.loads(pathlib.Path("$output_file").read_text())
expected_args = ["--type=tab", "--source-window=id:42", "--cwd=last_reported"]
if data["args"] != expected_args:
    raise SystemExit(f"Unexpected local args: {data['args']!r}")
if "kitten" in data["args"] or "ssh" in data["args"]:
    raise SystemExit(f"Unexpected remote markers in local args: {data['args']!r}")
if "/Users/local/path" in data["args"]:
    raise SystemExit("Local cwd leaked into args")
PY
}

test_kitty_smart_launch_clones_remote_context_with_timeout_guard() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/ssh-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case ssh "/srv/my project" "$output_file"
	assert_kitty_remote_launch_matches "$output_file" "yumi"
}

test_kitty_smart_launch_handles_kitty_generated_ssh_cmdline() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/kitty-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case kitty-ssh "/srv/my project" "$output_file"
	assert_kitty_remote_launch_matches "$output_file" "yumi"
}

test_kitty_smart_launch_handles_inline_kitten_cwd_cmdline() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/inline-kitten-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case inline-kitten "/srv/my project" "$output_file"
	python3 - <<PY
import json
import pathlib
import shlex

data = json.loads(pathlib.Path("$output_file").read_text())
tokens = [token.rstrip(";") for token in shlex.split(data["args"][-1])]
if not any("cwd=/srv/my project" in token for token in tokens):
    raise SystemExit(f"Inline kitten cwd was not rewritten: {tokens!r}")
if any("--kitten=cwd=/placeholder" in token for token in tokens):
    raise SystemExit(f"Inline kitten cwd placeholder leaked through: {tokens!r}")
try:
    kitten_idx = tokens.index("kitten")
except ValueError as exc:
    raise SystemExit(f"Inline kitten prefix missing: {tokens!r}") from exc
if tokens[kitten_idx:kitten_idx + 2] != ["kitten", "ssh"]:
    raise SystemExit(f"Inline kitten prefix changed unexpectedly: {tokens!r}")
PY
}

test_kitty_smart_launch_handles_kitty_plus_kitten_ssh_cmdline() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/kitty-plus-kitten-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case kitty-inline-kitten "/srv/my project" "$output_file"
	python3 - <<PY
import json
import pathlib
import shlex

data = json.loads(pathlib.Path("$output_file").read_text())
tokens = [token.rstrip(";") for token in shlex.split(data["args"][-1])]
try:
    kitty_idx = tokens.index("kitty")
except ValueError as exc:
    raise SystemExit(f"kitty +kitten ssh prefix missing: {tokens!r}") from exc
if tokens[kitty_idx:kitty_idx + 3] != ["kitty", "+kitten", "ssh"]:
    raise SystemExit(f"kitty +kitten ssh prefix changed unexpectedly: {tokens!r}")
if not any("cwd=/srv/my project" in token for token in tokens):
    raise SystemExit(f"kitty +kitten ssh cwd was not rewritten: {tokens!r}")
if any("--kitten=cwd=/placeholder" in token for token in tokens):
    raise SystemExit(f"kitty +kitten ssh placeholder leaked through: {tokens!r}")
PY
}

test_kitty_smart_launch_inserts_guard_options_before_uri_destinations() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/uri-kitten-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case uri-kitten "/srv/my project" "$output_file"
	python3 - <<PY
import json
import pathlib
import shlex

data = json.loads(pathlib.Path("$output_file").read_text())
tokens = [token.rstrip(";") for token in shlex.split(data["args"][-1])]
destination = "ssh://alice@example.com:2222"
dest_idx = tokens.index(destination)
for opt in (
    "-oBatchMode=yes",
    "-oConnectTimeout=2",
    "-oConnectionAttempts=1",
    "-oStrictHostKeyChecking=yes",
):
    if tokens.index(opt) > dest_idx:
        raise SystemExit(f"SSH guard option appears after URI destination: {tokens!r}")
PY
}

test_kitty_smart_launch_falls_back_to_local_when_remote_cwd_is_missing() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/missing-cwd-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case missing-cwd "" "$output_file"

	python3 - <<PY
import json
import pathlib

data = json.loads(pathlib.Path("$output_file").read_text())
expected_args = ["--type=tab", "--source-window=id:42", "--cwd=last_reported"]
if data["args"] != expected_args:
    raise SystemExit(f"Unexpected fallback args: {data['args']!r}")
if any("kitten" in token or "ssh" in token for token in data["args"]):
    raise SystemExit(f"Remote markers present in fallback args: {data['args']!r}")
PY
}

run_test "Dotfiles manifest and SSH include block" test_dotfiles_manifest_and_ssh_block
run_test "Dotfiles deploys bb-browser shell plugin" test_dotfiles_deploys_bb_browser_shell_plugin
run_test "bb-browser install uses latest and deploys wrapper" test_bb_browser_install_uses_latest_and_deploys_wrapper
run_test "bb-browser install patches managed mcp dist only" test_bb_browser_install_patches_managed_mcp_dist_file_only
run_test "bb-browser dist patch supports mcp cdpArgs variant without cli.js" test_bb_browser_dist_patch_supports_mcp_spawn_with_cdp_args_without_cli_js
run_test "managed xiaohongshu template corrects stale search context" test_managed_xiaohongshu_search_template_corrects_stale_search_context
run_test "bb-browser fresh install marker drives managed uninstall" test_bb_browser_fresh_install_marker_drives_managed_uninstall
run_test "bb-browser install discovers browser and launches CDP" test_bb_browser_install_discovers_browser_and_launches_cdp
run_test "bb-browser install keeps token private when chmod fails" test_bb_browser_install_keeps_token_private_when_chmod_fails
run_test "bb-browser install writes Edge Default config and verifies MCP bootstrap" test_bb_browser_install_writes_edge_default_config_and_verifies_mcp
run_test "bb-browser wrapper uses overridden loopback and daemon endpoint" test_bb_browser_wrapper_uses_overridden_loopback_and_daemon_endpoint
run_test "bb-browser wrapper defaults to Edge Default profile" test_bb_browser_wrapper_defaults_to_edge_default_profile
run_test "kitty ssh utils rewrites inline kitten cwd" test_kitty_smart_launch_handles_inline_kitten_cwd_cmdline
run_test "kitty ssh utils rewrites kitty plus kitten ssh" test_kitty_smart_launch_handles_kitty_plus_kitten_ssh_cmdline
run_test "kitty ssh utils keeps guard options before URI destinations" test_kitty_smart_launch_inserts_guard_options_before_uri_destinations
run_test "bb-browser wrapper doctor is side-effect free" test_bb_browser_wrapper_doctor_is_side_effect_free
run_test "bb-browser wrapper restarts ordinary Edge when CDP is absent" test_bb_browser_wrapper_restarts_edge_when_running_without_cdp
run_test "bb-browser wrapper restarts Edge when live CDP belongs to another profile" test_bb_browser_wrapper_restarts_edge_when_cdp_profile_mismatches
run_test "bb-browser restarts daemon when CDP target changes" test_bb_browser_restarts_daemon_when_cdp_target_changes
run_test "bb-browser doctor finds daemon from recorded real path when npm root drifts" test_bb_browser_doctor_finds_daemon_from_recorded_real_path_when_npm_root_drifts
run_test "bb-browser install fails without supported browser" test_bb_browser_install_fails_without_supported_browser
run_test "bb-browser install preserves preexisting managed package on failure" test_bb_browser_install_preserves_preexisting_managed_prefix_artifact_on_failure
run_test "bb-browser wrapper uses managed path over preexisting path" test_bb_browser_wrapper_uses_managed_path_over_preexisting_path
run_test "bb-browser uninstall preserves preexisting global install" test_bb_browser_uninstall_preserves_preexisting_global_install
run_test "bb-browser uninstall restores preexisting command shim" test_bb_browser_uninstall_restores_preexisting_command_shim
run_test "bb-browser install/uninstall restores preexisting wrapper" test_bb_browser_install_and_uninstall_restore_preexisting_wrapper
run_test "bb-browser reinstall preserves managed ownership" test_bb_browser_reinstall_preserves_managed_ownership
run_test "bb-browser uninstall removes managed global install" test_bb_browser_uninstall_removes_managed_global_install
run_test "bb-browser uninstall restores escaped backup path without python" test_bb_browser_uninstall_restores_wrapper_backup_with_escaped_path_without_python
run_test "bb-browser uninstall skips missing or empty preexisting marker" test_bb_browser_uninstall_skips_missing_or_empty_preexisting_marker
run_test "bb-browser uninstall targets recorded prefix on drift" test_bb_browser_uninstall_targets_recorded_prefix_on_drift
run_test "Dotfiles uninstall preserves modified files" test_dotfiles_uninstall_preserves_modified_files
run_test "Claude runtime config preserves existing state" test_claude_runtime_config_preserves_existing_state
run_test "Git config identity migrates to local include" test_gitconfig_identity_migrates_to_local
run_test "Dotfiles hook-free fallback" test_dotfiles_hook_free_fallback
run_test "Codex config preserves subprojects" test_codex_config_preserves_projects_and_keeps_home_subprojects
run_test "Codex config includes bb-browser when wrapper exists" test_codex_config_includes_bb_browser_when_wrapper_exists
run_test "file-deps includes codex deploy for bb-browser install" test_file_deps_include_codex_deploy_for_bb_browser_install
run_test "Pixi prefers managed install" test_pixi_prefers_managed_install_over_system_binary
run_test "Claude optional on macOS" test_claude_optional_on_macos_when_missing
run_test "Claude optional on Linux" test_claude_optional_on_linux_when_install_fails
run_test "Claude installs bb-browser MCP" test_claude_installs_bb_browser_mcp
run_test "Claude skips bb-browser MCP without wrapper" test_claude_skips_bb_browser_mcp_without_wrapper
run_test "Claude removes managed bb-browser MCP without wrapper" test_claude_removes_managed_bb_browser_mcp_without_wrapper
run_test "Claude uninstall removes bb-browser MCP" test_uninstall_claude_removes_bb_browser_mcp
run_test "Claude uninstall preserves user-owned bb-browser MCP" test_uninstall_claude_preserves_user_owned_bb_browser_mcp
run_test "Claude uninstall removes study-master vendor repo" test_uninstall_claude_removes_study_master_vendor_repo
run_test "Dotfiles uninstall removes wrapper integrations" test_dotfiles_uninstall_removes_wrapper_integrations
run_test "Dotfiles uninstall preserves user-owned bb-browser MCP" test_dotfiles_uninstall_preserves_user_owned_bb_browser_mcp
run_test "Claude known_hosts preserves symlink" test_claude_known_hosts_preserves_symlink
run_test "Claude installs study-master from new repo" test_claude_installs_study_master_from_new_repo
run_test "Claude updates marketplaces and plugins" test_claude_updates_marketplaces_and_plugins
run_test "Claude refreshes study-master on rerun" test_claude_refreshes_study_master_on_rerun
run_test "macOS brew maintenance LaunchAgent" test_macos_brew_maintenance_launchagent_created
run_test "kitty smart launch uses last_reported for local windows" test_kitty_smart_launch_uses_last_reported_for_local_windows
run_test "kitty smart launch clones remote context with timeout guard" test_kitty_smart_launch_clones_remote_context_with_timeout_guard
run_test "kitty smart launch handles Kitty-generated ssh command line" test_kitty_smart_launch_handles_kitty_generated_ssh_cmdline
run_test "kitty smart launch falls back to local when remote cwd is missing" test_kitty_smart_launch_falls_back_to_local_when_remote_cwd_is_missing

section "Done"
pass "Smoke checks completed"
