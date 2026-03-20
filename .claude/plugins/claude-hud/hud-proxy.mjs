#!/usr/bin/env node
// Proxy: reads stdin from Claude Code, runs HUD as subprocess, outputs result.
// Fixes multi-line rendering issue where direct exec only shows 1 line.
import { execSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { homedir } from 'node:os';

const chunks = [];
process.stdin.setEncoding('utf8');
for await (const chunk of process.stdin) {
  chunks.push(chunk);
}
const input = chunks.join('');

const base = `${process.env.CLAUDE_CONFIG_DIR || (homedir() + '/.claude')}/plugins/cache/claude-hud/claude-hud`;
try {
  const versions = readdirSync(base).filter(d => /^\d/.test(d)).sort((a, b) => {
    const pa = a.split('.').map(Number), pb = b.split('.').map(Number);
    for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
      if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) - (pb[i] || 0);
    }
    return 0;
  });
  const latest = versions[versions.length - 1];
  const output = execSync(`"${process.execPath}" "${base}/${latest}/dist/index.js"`, {
    input,
    encoding: 'utf8',
    timeout: 5000,
  });
  process.stdout.write(output);
} catch (e) {
  console.log(`[claude-hud] Error: ${e.message}`);
}
