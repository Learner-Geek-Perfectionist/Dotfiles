#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function replaceOnce(text, before, after, label) {
  if (text.includes(after)) {
    return { text, changed: false };
  }
  if (!text.includes(before)) {
    throw new Error(`Expected snippet not found for ${label}`);
  }
  return {
    text: text.replace(before, after),
    changed: true,
  };
}

function replacePattern(text, pattern, after, label) {
  if (text.includes(after)) {
    return { text, changed: false };
  }
  if (!pattern.test(text)) {
    throw new Error(`Expected snippet not found for ${label}`);
  }
  return {
    text: text.replace(pattern, after),
    changed: true,
  };
}

function patchCli(text) {
  // If bb-browser already uses daemon.json config, it has native token/host support.
  if (text.includes("daemon.json")) {
    return { text, changed: false };
  }

  let changed = false;
  let result = text;

  const replacements = [
    {
      label: "cli import",
      before: 'import { spawn } from "child_process";',
      after: 'import { execFile, spawn } from "child_process";',
    },
    {
      label: "cli pid files",
      before: 'var TOKEN_FILE = path.join(DAEMON_DIR, "daemon.token");',
      after: 'var TOKEN_FILE = path.join(DAEMON_DIR, "daemon.token");\nvar PID_FILES = [path.join(DAEMON_DIR, "daemon.pid"), "/tmp/bb-browser.pid"];',
    },
    {
      label: "cli exec helper",
      before: 'var cachedToken = null;\nvar daemonReady = false;',
      after: 'var cachedToken = null;\nvar daemonReady = false;\nfunction execFileText(file, args) {\n  return new Promise((resolve2) => {\n    execFile(file, args, (error, stdout) => {\n      if (error) {\n        resolve2("");\n        return;\n      }\n      resolve2((stdout || "").trim());\n    });\n  });\n}',
    },
    {
      label: "cli spawn host",
      pattern: /(^|\n)\s*const child = spawn\(process\.execPath, \[daemonPath\], \{\n\s*detached: true,\n\s*stdio: "ignore"\n\s*\}\);/,
      after: "\n  const child = spawn(process.execPath, [daemonPath, \"--host\", \"127.0.0.1\"], {\n    detached: true,\n    stdio: \"ignore\"\n  });",
      usePattern: true,
    },
  ];

  for (const replacement of replacements) {
    const patched = replacement.usePattern
      ? replacePattern(result, replacement.pattern, replacement.after, replacement.label)
      : replaceOnce(result, replacement.before, replacement.after, replacement.label);
    result = patched.text;
    changed = changed || patched.changed;
  }

  const readTokenBefore = `async function readToken() {
  try {
    return (await readFile(TOKEN_FILE, "utf8")).trim();
  } catch {
    return null;
  }
}`;
  const readTokenAfter = `async function readToken() {
  try {
    const token = (await readFile(TOKEN_FILE, "utf8")).trim();
    if (token) return token;
  } catch {
  }
  for (const pidFile of PID_FILES) {
    try {
      const pid = (await readFile(pidFile, "utf8")).trim();
      if (!pid) continue;
      const command = await execFileText("ps", ["-ww", "-p", pid, "-o", "command="]);
      const match = command.match(/--token\\s+([a-f0-9]+)/i);
      if (match?.[1]) return match[1];
    } catch {
    }
  }
  return null;
}`;
  const patchedReadToken = replaceOnce(result, readTokenBefore, readTokenAfter, "cli readToken");
  result = patchedReadToken.text;
  changed = changed || patchedReadToken.changed;

  return { text: result, changed };
}

function patchMcp(text) {
  // If bb-browser already uses daemon.json config, it has native token/host support.
  if (text.includes("daemon.json") || text.includes("MCP_DAEMON_BASE_URL =")) {
    return { text, changed: false };
  }

  let changed = false;
  let result = text;

  const replacements = [
    {
      label: "mcp fs/promises import",
      before: 'import { existsSync } from "fs";',
      after: 'import { existsSync } from "fs";\nimport { readFile } from "fs/promises";',
    },
    {
      label: "mcp os import",
      before: 'import { dirname, resolve } from "path";',
      after: 'import { dirname, resolve } from "path";\nimport { homedir } from "os";',
    },
    {
      label: "mcp daemon helpers",
      before: "var sessionOpenedTabs = /* @__PURE__ */ new Set();",
      after: `var sessionOpenedTabs = /* @__PURE__ */ new Set();
var MCP_DAEMON_BASE_URL = DAEMON_BASE_URL.replace("://localhost:", "://127.0.0.1:");
var DAEMON_DIR = resolve(homedir(), ".bb-browser");
var TOKEN_FILE = resolve(DAEMON_DIR, "daemon.token");
var PID_FILES = [resolve(DAEMON_DIR, "daemon.pid"), "/tmp/bb-browser.pid"];
var cachedDaemonToken = null;
function execFileText(file, args) {
  return new Promise((resolve2) => {
    execFile(file, args, (error2, stdout) => {
      if (error2) {
        resolve2("");
        return;
      }
      resolve2((stdout || "").trim());
    });
  });
}
async function readDaemonToken() {
  if (cachedDaemonToken) return cachedDaemonToken;
  try {
    const token = (await readFile(TOKEN_FILE, "utf8")).trim();
    if (token) {
      cachedDaemonToken = token;
      return token;
    }
  } catch {}
  for (const pidFile of PID_FILES) {
    try {
      const pid = (await readFile(pidFile, "utf8")).trim();
      if (!pid) continue;
      const command = await execFileText("ps", ["-ww", "-p", pid, "-o", "command="]);
      const match = command.match(/--token\\s+([a-f0-9]+)/i);
      if (match?.[1]) {
        cachedDaemonToken = match[1];
        return cachedDaemonToken;
      }
    } catch {}
  }
  return null;
}
async function daemonFetch(url, init = {}, retrying = false) {
  const token = await readDaemonToken();
  const headers = {
    ...(init.headers || {}),
    ...(token ? { Authorization: \`Bearer \${token}\` } : {}),
  };
  const res = await fetch(url, { ...init, headers });
  if (res.status === 401 && cachedDaemonToken && !retrying) {
    cachedDaemonToken = null;
    const refreshedToken = await readDaemonToken();
    if (refreshedToken && refreshedToken !== token) {
      return daemonFetch(url, init, true);
    }
  }
  return res;
}`,
    },
    {
      label: "mcp status fetch",
      pattern: /(\s*const res = await )fetch\(`\$\{DAEMON_BASE_URL\}\/status`, \{ signal: controller\.signal \}\);/,
      after: "    const res = await daemonFetch(`${MCP_DAEMON_BASE_URL}/status`, { signal: controller.signal });",
      usePattern: true,
    },
    {
      label: "mcp spawn host",
      pattern: /(^|\n)\s*const child = spawn\(process\.execPath,\s*\[getDaemonPath\(\)\],\s*\{\s*detached: true,\s*stdio: "ignore",\s*env: \{ \.\.\.process\.env \}\s*,?\s*\}\);/,
      after: "\n  const child = spawn(process.execPath, [getDaemonPath(), \"--host\", \"127.0.0.1\"], {\n    detached: true, stdio: \"ignore\", env: { ...process.env },\n  });",
      usePattern: true,
    },
    {
      label: "mcp command fetch",
      pattern: /(\s*const response = await )fetch\(`\$\{DAEMON_BASE_URL\}\/command`, \{\n\s*method: "POST",\n\s*headers: \{ "Content-Type": "application\/json" \},\n\s*body: JSON\.stringify\(request\),\n(?:\s*signal: controller\.signal\s*,?\n)?\s*\}\);/,
      after: "    const response = await daemonFetch(`${MCP_DAEMON_BASE_URL}/command`, {\n      method: \"POST\",\n      headers: { \"Content-Type\": \"application/json\" },\n      body: JSON.stringify(request),\n    });",
      usePattern: true,
    },
  ];

  for (const replacement of replacements) {
    const patched = replacement.usePattern
      ? replacePattern(result, replacement.pattern, replacement.after, replacement.label)
      : replaceOnce(result, replacement.before, replacement.after, replacement.label);
    result = patched.text;
    changed = changed || patched.changed;
  }

  return { text: result, changed };
}

function patchFile(filePath, patcher) {
  const original = fs.readFileSync(filePath, "utf8");
  const patched = patcher(original);
  if (patched.changed) {
    fs.writeFileSync(filePath, patched.text, "utf8");
  }
  return patched.changed;
}

function main() {
  const distDir = process.argv[2];
  if (!distDir) {
    throw new Error("Usage: patch_bb_browser_dist.mjs <dist-dir>");
  }

  const cliPath = path.join(distDir, "cli.js");
  const mcpPath = path.join(distDir, "mcp.js");

  if (!fs.existsSync(cliPath)) {
    throw new Error(`cli.js not found: ${cliPath}`);
  }
  if (!fs.existsSync(mcpPath)) {
    throw new Error(`mcp.js not found: ${mcpPath}`);
  }

  const changed = [
    patchFile(cliPath, patchCli),
    patchFile(mcpPath, patchMcp),
  ];

  const total = changed.filter(Boolean).length;
  process.stdout.write(`patched ${total} file(s)\n`);
}

main();
