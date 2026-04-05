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
    basename0 = os.path.basename(argv[0]) if argv else ""
    return (basename0 == "kitten" and argv[1:2] == ["ssh"]) or argv[:3] == ["kitty", "+kitten", "ssh"]


def fake_get_connection_data(argv, extra_args=()):
    if not fake_is_kitten_cmdline(argv):
        return None

    for token in reversed(argv):
        if token in {"kitty", "kitten", "+kitten", "ssh"} or os.path.basename(token) == "kitten":
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
kitty_constants_mod = types.ModuleType("kitty.constants")
kitty_launch_mod = types.ModuleType("kitty.launch")
kitty_kittens_mod = types.ModuleType("kittens")
kitty_kittens_mod.__path__ = []
kitty_kittens_ssh_mod = types.ModuleType("kittens.ssh")
kitty_kittens_ssh_mod.__path__ = []
kitty_kittens_ssh_utils_mod = types.ModuleType("kittens.ssh.utils")
kitty_launch_mod.launch = fake_launch
kitty_launch_mod.parse_launch_args = fake_parse_launch_args
kitty_constants_mod.kitten_exe = lambda: "/opt/kitty/bin/kitten"
kitty_kittens_ssh_utils_mod.set_cwd_in_cmdline = fake_set_cwd_in_cmdline
kitty_kittens_ssh_utils_mod.is_kitten_cmdline = fake_is_kitten_cmdline
kitty_kittens_ssh_utils_mod.get_connection_data = fake_get_connection_data
sys.modules["kitty"] = kitty_pkg
sys.modules["kitty.constants"] = kitty_constants_mod
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
    at_prompt = False
    screen = Screen()
    user_vars = {}

    def ssh_kitten_cmdline(self):
        if scenario in {"ssh", "ssh-connecting", "ssh-same-cwd", "ssh-connecting-realpath", "burst-ssh"}:
            return ["kitten", "ssh", "--kitten", "cwd=/placeholder", "yumi"]
        if scenario == "ssh-prompt-before-cwd":
            return ["kitten", "ssh", "--kitten", "cwd=/placeholder", "orb"]
        if scenario == "ssh-helper-before-prompt-or-cwd":
            return ["kitten", "ssh", "--kitten", "cwd=/placeholder", "orb"]
        if scenario == "shared-control-kitten":
            return [
                "kitten",
                "ssh",
                "-o",
                "ControlMaster=auto",
                "-oControlPath=/tmp/kssh-rdir-501/kssh-8459-%C",
                "-o",
                "ControlPersist=yes",
                "--kitten",
                "cwd=/placeholder",
                "yumi",
            ]
        if scenario == "kitty-ssh":
            return ["kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "yumi"]
        if scenario == "inline-kitten":
            return ["kitten", "ssh", "--kitten=cwd=/placeholder", "yumi"]
        if scenario == "kitty-inline-kitten":
            return ["kitty", "+kitten", "ssh", "--kitten=cwd=/placeholder", "yumi"]
        if scenario == "uri-kitten":
            return ["kitty", "+kitten", "ssh", "--kitten=cwd=/placeholder", "ssh://alice@example.com:2222"]
        if scenario == "wrapped-kitty-ssh":
            return ["kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "yumi"]
        if scenario == "combined-short-flags":
            return ["kitty", "+kitten", "ssh", "-vp", "2222", "--kitten=cwd=/placeholder", "yumi"]
        return None


window = Window()
active_window = window
window_id_map = {42: window}
target_window_id = 42
cmdline = None
if scenario in {"ssh", "ssh-connecting", "ssh-same-cwd", "inline-kitten", "missing-cwd", "missing-all-cwd", "ssh-connecting-realpath"}:
    cmdline = ["ssh", "yumi"]
elif scenario in {"ssh-prompt-before-cwd", "ssh-helper-before-prompt-or-cwd"}:
    cmdline = ["ssh", "orb"]
elif scenario in {"kitty-ssh", "kitty-inline-kitten"}:
    cmdline = ["kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "yumi"]
elif scenario == "uri-kitten":
    cmdline = ["kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "ssh://alice@example.com:2222"]
elif scenario == "wrapped-kitty-ssh":
    cmdline = ["kitten", "run-shell", "kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "yumi"]
elif scenario == "kitty-uri-no-helper":
    cmdline = ["kitty", "+kitten", "ssh", "--kitten", "cwd=/placeholder", "ssh://alice@example.com:2222"]
elif scenario == "combined-short-flags":
    cmdline = ["kitty", "+kitten", "ssh", "-vp", "2222", "--kitten", "cwd=/placeholder", "yumi"]
if cmdline is not None:
    window.child.foreground_processes = [{"cmdline": cmdline}]
if scenario == "ssh-same-cwd" and cwd_value is not None:
    window.screen.last_reported_cwd = f"kitty-shell-cwd://yumi{cwd_value.replace(' ', '%20')}"
elif scenario in {"ssh", "ssh-connecting", "shared-control-kitten", "kitty-ssh", "inline-kitten", "kitty-inline-kitten", "uri-kitten", "wrapped-kitty-ssh", "kitty-uri-no-helper", "combined-short-flags", "ssh-prompt-before-cwd", "ssh-connecting-realpath"} and cwd_value is not None:
    window.screen.last_reported_cwd = f"file://{cwd_value.replace(' ', '%20')}"
if scenario == "missing-cwd":
    window.screen.last_reported_cwd = None
if scenario == "missing-all-cwd":
    window.screen.last_reported_cwd = None
if scenario == "ssh-helper-before-prompt-or-cwd":
    window.screen.last_reported_cwd = None
if scenario == "ssh-prompt-before-cwd":
    window.at_prompt = True
if scenario == "ssh-connecting-realpath":
    window.cwd_of_child = "/private/tmp"
if scenario == "missing-all-cwd":
    window.cwd_of_child = None

if scenario == "burst-local":
    source_window = Window()
    source_window.id = 42
    source_window.cwd_of_child = "/tmp"
    source_window.screen = type("Screen", (), {"last_reported_cwd": "file:///tmp"})()
    source_window.child = Child()
    source_window.child.foreground_processes = []
    source_window.user_vars = {}

    active_window = Window()
    active_window.id = 43
    active_window.cwd_of_child = str(pathlib.Path.home())
    active_window.screen = type("Screen", (), {"last_reported_cwd": None})()
    active_window.child = Child()
    active_window.child.foreground_processes = []
    active_window.user_vars = {"smart_launch_source_window_id": "42"}
    window_id_map = {42: source_window, 43: active_window}
    target_window_id = 43

if scenario == "burst-ssh":
    source_window = Window()
    source_window.id = 42
    source_window.cwd_of_child = "/private/tmp"
    source_window.screen = type("Screen", (), {"last_reported_cwd": "kitty-shell-cwd://orb/tmp"})()
    source_window.child = Child()
    source_window.child.foreground_processes = [{"cmdline": ["ssh", "orb"]}]
    source_window.user_vars = {}
    source_window.ssh_kitten_cmdline = lambda: ["kitten", "ssh", "--kitten", "cwd=/placeholder", "orb"]

    active_window = Window()
    active_window.id = 43
    active_window.cwd_of_child = str(pathlib.Path.home())
    active_window.screen = type("Screen", (), {"last_reported_cwd": None})()
    active_window.child = Child()
    active_window.child.foreground_processes = []
    active_window.user_vars = {"smart_launch_source_window_id": "42"}
    active_window.ssh_kitten_cmdline = lambda: None
    window_id_map = {42: source_window, 43: active_window}
    target_window_id = 43


class Boss:
    active_window = active_window
    window_id_map = window_id_map


module.smart_launch(Boss(), "tab", target_window_id)
print(json.dumps({"args": captured["args"], "remaining": captured["remaining"]}))
PY
}

assert_kitty_remote_launch_matches() {
	local output_file="$1"
	python3 - "$output_file" <<'PY'
import json
import pathlib
import sys

output_path = pathlib.Path(sys.argv[1])
data = json.loads(output_path.read_text())
args = data["args"]
expected_args = [
    "--type=tab",
    "--source-window=id:42",
    "--var",
    "smart_launch_source_window_id=42",
    "--cwd=current",
    "--hold-after-ssh",
]
if args != expected_args:
	    raise SystemExit(f"Expected native Kitty SSH launch args: {args!r}")
PY
}

assert_kitty_local_fallback_matches() {
	local output_file="$1" expected_cwd="$2"
	python3 - "$output_file" "$expected_cwd" <<'PY'
import json
import pathlib
import sys

output_path = pathlib.Path(sys.argv[1])
expected_cwd = sys.argv[2]
data = json.loads(output_path.read_text())
args = data["args"]
expected_args = [
    "--type=tab",
    "--source-window=id:42",
    "--var",
    "smart_launch_source_window_id=42",
    f"--cwd={expected_cwd}",
]
if args != expected_args:
    raise SystemExit(f"Expected local fallback launch args: {args!r}")
if any("kitten" in token or "ssh" in token for token in args):
    raise SystemExit(f"Unexpected remote markers in local fallback args: {args!r}")
PY
}

assert_kitty_fail_closed_without_cwd_matches() {
	local output_file="$1"
	python3 - "$output_file" <<'PY'
import json
import pathlib
import sys

output_path = pathlib.Path(sys.argv[1])
data = json.loads(output_path.read_text())
args = data["args"]
expected_args = [
    "--type=tab",
    "--source-window=id:42",
    "--var",
    "smart_launch_source_window_id=42",
]
if args != expected_args:
    raise SystemExit(f"Expected fail-closed launch args without cwd: {args!r}")
if any(token.startswith("--cwd=") for token in args):
    raise SystemExit(f"Unexpected cwd marker in fail-closed args: {args!r}")
if any("kitten" in token or "ssh" in token for token in args):
    raise SystemExit(f"Unexpected remote markers in fail-closed args: {args!r}")
PY
}

test_kitty_conf_enables_native_smart_hotkeys() {
	assert_contains "map cmd+n kitten ./smart_window.py" "$REPO_ROOT/.config/kitty/kitty.conf"
	assert_contains "map cmd+e kitten ./smart_tab.py" "$REPO_ROOT/.config/kitty/kitty.conf"
	assert_not_contains "# map cmd+n kitten ./smart_window.py" "$REPO_ROOT/.config/kitty/kitty.conf"
	assert_not_contains "# map cmd+e kitten ./smart_tab.py" "$REPO_ROOT/.config/kitty/kitty.conf"
}

test_kitty_hammerspoon_does_not_wire_native_smart_hotkeys() {
	assert_not_contains "[hs.keycodes.map.n] = './smart_window.py'" "$REPO_ROOT/.hammerspoon/modules/kittyHotkeys.lua"
	assert_not_contains "[hs.keycodes.map.e] = './smart_tab.py'" "$REPO_ROOT/.hammerspoon/modules/kittyHotkeys.lua"
}

test_kitty_smart_launch_uses_native_current_cwd_for_local_windows() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/local-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case local "/Users/local/path" "$output_file"

	python3 - <<PY
import json
import pathlib

data = json.loads(pathlib.Path("$output_file").read_text())
expected_args = [
    "--type=tab",
    "--source-window=id:42",
    "--var",
    "smart_launch_source_window_id=42",
    "--cwd=current",
]
if data["args"] != expected_args:
    raise SystemExit(f"Unexpected local args: {data['args']!r}")
if "kitten" in data["args"] or "ssh" in data["args"]:
    raise SystemExit(f"Unexpected remote markers in local args: {data['args']!r}")
PY
}

test_kitty_smart_launch_skips_ssh_when_session_not_established() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/ssh-connecting-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	# SSH is still connecting, so smart launch should stay local.
	run_kitty_ssh_utils_case ssh-connecting "/Users/local/path" "$output_file"
	assert_kitty_local_fallback_matches "$output_file" "/Users/local/path"
}

test_kitty_smart_launch_clones_when_remote_cwd_matches_local_path() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/ssh-same-cwd-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	# Remote CWD equals cwd_of_child but URL hostname is "yumi" (remote)
	run_kitty_ssh_utils_case ssh-same-cwd "/Users/local/path" "$output_file"
	assert_kitty_remote_launch_matches "$output_file"
}

test_kitty_smart_launch_uses_native_hold_after_ssh_for_established_sessions() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/ssh-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case ssh "/srv/my project" "$output_file"
	assert_kitty_remote_launch_matches "$output_file"
}

test_kitty_smart_launch_prefers_native_hold_after_ssh_over_helper_rewriting() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/shared-control-kitten-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case shared-control-kitten "/srv/my project" "$output_file"
	assert_kitty_remote_launch_matches "$output_file"
}

test_kitty_smart_launch_falls_back_to_local_when_prompt_visible_session_is_seen() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/ssh-prompt-before-cwd-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	# Prompt-visible SSH should now resolve to the same local fallback path.
	run_kitty_ssh_utils_case ssh-prompt-before-cwd "/Users/local/path" "$output_file"
	assert_kitty_local_fallback_matches "$output_file" "/Users/local/path"
}

test_kitty_smart_launch_falls_back_to_local_when_helper_is_available_before_prompt_or_cwd() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/ssh-helper-before-prompt-or-cwd-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	# Helper availability no longer overrides the local fallback path.
	run_kitty_ssh_utils_case ssh-helper-before-prompt-or-cwd "" "$output_file"
	assert_kitty_local_fallback_matches "$output_file" "/Users/local/path"
}

test_kitty_smart_launch_fails_closed_for_kitty_uri_without_helper_cmdline() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/kitty-uri-no-helper-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case kitty-uri-no-helper "/srv/my project" "$output_file"
	assert_kitty_local_fallback_matches "$output_file" "/Users/local/path"
}

test_kitty_smart_launch_falls_back_to_local_when_remote_cwd_is_missing() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/missing-cwd-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case missing-cwd "" "$output_file"
	assert_kitty_local_fallback_matches "$output_file" "/Users/local/path"
}

test_kitty_smart_launch_fails_closed_without_cwd_when_ssh_metadata_is_missing() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/missing-all-cwd-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case missing-all-cwd "" "$output_file"
	assert_kitty_fail_closed_without_cwd_matches "$output_file"
}

test_kitty_smart_launch_skips_ssh_when_connecting_paths_match_via_realpath() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/ssh-connecting-realpath-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case ssh-connecting-realpath "/tmp" "$output_file"
	assert_kitty_local_fallback_matches "$output_file" "/tmp"
}

test_kitty_smart_launch_reuses_previous_stable_local_source_during_rapid_repeats() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/burst-local-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case burst-local "" "$output_file"

	python3 - <<PY
import json
import pathlib

data = json.loads(pathlib.Path("$output_file").read_text())
expected_args = [
    "--type=tab",
    "--source-window=id:42",
    "--var",
    "smart_launch_source_window_id=42",
    "--cwd=current",
]
if data["args"] != expected_args:
    raise SystemExit(f"Unexpected burst-local args: {data['args']!r}")
PY
}

test_kitty_smart_launch_reuses_previous_stable_ssh_source_during_rapid_repeats() {
	local tmp_dir output_file
	tmp_dir=$(make_temp_dir)
	output_file="$tmp_dir/burst-ssh-launch.json"
	trap 'rm -rf "${tmp_dir:-}"' RETURN

	run_kitty_ssh_utils_case burst-ssh "" "$output_file"
	python3 - <<PY
import json
import pathlib

data = json.loads(pathlib.Path("$output_file").read_text())
expected_args = [
    "--type=tab",
    "--source-window=id:42",
    "--var",
    "smart_launch_source_window_id=42",
    "--cwd=current",
    "--hold-after-ssh",
]
if data["args"] != expected_args:
    raise SystemExit(f"Unexpected burst-ssh args: {data['args']!r}")
PY
}

run_test "Dotfiles manifest and SSH include block" test_dotfiles_manifest_and_ssh_block
run_test "Dotfiles deploys bb-browser shell plugin" test_dotfiles_deploys_bb_browser_shell_plugin
run_test "bb-browser install uses latest and deploys wrapper" test_bb_browser_install_uses_latest_and_deploys_wrapper
run_test "bb-browser install patches managed mcp dist only" test_bb_browser_install_patches_managed_mcp_dist_file_only
run_test "bb-browser dist patch supports mcp cdpArgs variant without cli.js" test_bb_browser_dist_patch_supports_mcp_spawn_with_cdp_args_without_cli_js
run_test "managed xiaohongshu template corrects stale search context" test_managed_xiaohongshu_search_template_corrects_stale_search_context
run_test "kitty conf enables native smart hotkeys" test_kitty_conf_enables_native_smart_hotkeys
run_test "kitty hammerspoon does not wire native smart hotkeys" test_kitty_hammerspoon_does_not_wire_native_smart_hotkeys
run_test "bb-browser install discovers browser and launches CDP" test_bb_browser_install_discovers_browser_and_launches_cdp
run_test "bb-browser install keeps token private when chmod fails" test_bb_browser_install_keeps_token_private_when_chmod_fails
run_test "bb-browser install writes Edge Default config and verifies MCP bootstrap" test_bb_browser_install_writes_edge_default_config_and_verifies_mcp
run_test "bb-browser wrapper uses overridden loopback and daemon endpoint" test_bb_browser_wrapper_uses_overridden_loopback_and_daemon_endpoint
run_test "bb-browser wrapper defaults to Edge Default profile" test_bb_browser_wrapper_defaults_to_edge_default_profile
run_test "kitty ssh utils falls back locally when helper cmdline is unavailable" test_kitty_smart_launch_fails_closed_for_kitty_uri_without_helper_cmdline
run_test "bb-browser wrapper doctor is side-effect free" test_bb_browser_wrapper_doctor_is_side_effect_free
run_test "bb-browser wrapper restarts ordinary Edge when CDP is absent" test_bb_browser_wrapper_restarts_edge_when_running_without_cdp
run_test "bb-browser wrapper restarts Edge when live CDP belongs to another profile" test_bb_browser_wrapper_restarts_edge_when_cdp_profile_mismatches
run_test "bb-browser restarts daemon when CDP target changes" test_bb_browser_restarts_daemon_when_cdp_target_changes
run_test "bb-browser install fails without supported browser" test_bb_browser_install_fails_without_supported_browser
run_test "Dotfiles uninstall preserves modified files" test_dotfiles_uninstall_preserves_modified_files
run_test "Claude runtime config preserves existing state" test_claude_runtime_config_preserves_existing_state
run_test "Git config identity migrates to local include" test_gitconfig_identity_migrates_to_local
run_test "Dotfiles hook-free fallback" test_dotfiles_hook_free_fallback
run_test "Codex config preserves subprojects" test_codex_config_preserves_projects_and_keeps_home_subprojects
run_test "Pixi prefers managed install" test_pixi_prefers_managed_install_over_system_binary
run_test "Claude optional on macOS" test_claude_optional_on_macos_when_missing
run_test "Claude optional on Linux" test_claude_optional_on_linux_when_install_fails
run_test "Dotfiles uninstall removes wrapper integrations" test_dotfiles_uninstall_removes_wrapper_integrations
run_test "Claude known_hosts preserves symlink" test_claude_known_hosts_preserves_symlink
run_test "kitty smart launch uses native current cwd for local windows" test_kitty_smart_launch_uses_native_current_cwd_for_local_windows
run_test "kitty smart launch skips ssh when session not established" test_kitty_smart_launch_skips_ssh_when_session_not_established
run_test "kitty smart launch clones when remote cwd matches local path" test_kitty_smart_launch_clones_when_remote_cwd_matches_local_path
run_test "kitty smart launch uses native hold-after-ssh for established sessions" test_kitty_smart_launch_uses_native_hold_after_ssh_for_established_sessions
run_test "kitty smart launch prefers native hold-after-ssh over helper rewriting" test_kitty_smart_launch_prefers_native_hold_after_ssh_over_helper_rewriting
run_test "kitty smart launch falls back to local when prompt-visible SSH is seen" test_kitty_smart_launch_falls_back_to_local_when_prompt_visible_session_is_seen
run_test "kitty smart launch falls back to local when helper exists before prompt or cwd" test_kitty_smart_launch_falls_back_to_local_when_helper_is_available_before_prompt_or_cwd
run_test "kitty smart launch falls back to local when remote cwd is missing" test_kitty_smart_launch_falls_back_to_local_when_remote_cwd_is_missing
run_test "kitty smart launch fails closed without cwd when ssh metadata is missing" test_kitty_smart_launch_fails_closed_without_cwd_when_ssh_metadata_is_missing
run_test "kitty smart launch realpath-matches local cwd while connecting" test_kitty_smart_launch_skips_ssh_when_connecting_paths_match_via_realpath
run_test "kitty smart launch reuses previous stable local source during rapid repeats" test_kitty_smart_launch_reuses_previous_stable_local_source_during_rapid_repeats
run_test "kitty smart launch reuses previous stable ssh source during rapid repeats" test_kitty_smart_launch_reuses_previous_stable_ssh_source_during_rapid_repeats

section "Done"
pass "Smoke checks completed"
