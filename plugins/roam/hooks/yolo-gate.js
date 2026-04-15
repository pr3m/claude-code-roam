#!/usr/bin/env node
/*
 * yolo-gate.js — PreToolUse hook for Bash when roam is active + yolo enabled.
 *
 * Decision order, in priority:
 *   1. If roam is OFF or yolo is OFF → fall through (no output, exit 0).
 *   2. Universal security hard-deny → ask (eval, sudo, bash -c, rm -rf /, …).
 *   3. User-defined deniedPatterns (roam config regex list) → ask.
 *   4. User's own Claude Code allow rules (~/.claude/settings.json +
 *      project .claude/settings*.json), if honorClaudeAllowList: true → allow.
 *   5. Roam's built-in safe set (git/ls/cat/grep/node/npm/…) → allow.
 *   6. Everything else → ask.
 *
 * The hook never overrides the user's settings.json `deny` rules — Claude
 * Code enforces those independently. Hard-deny patterns can't be bypassed
 * even if the user has the binary in their allow list: lid-closed unattended
 * yolo + a rogue `sudo` in their allowlist is not a shape the plugin will
 * silently enable.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

function emit(decision, reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: decision,
      permissionDecisionReason: reason,
    },
  }));
  process.exit(0);
}
const ask = (r) => emit('ask', r);
const allow = (r) => emit('allow', r);
const deny = (r) => emit('deny', r);

function fallthrough() { process.exit(0); }

function dataDir() {
  return process.env.CLAUDE_PLUGIN_DATA || path.join(os.homedir(), '.claude', 'roam');
}
function stateFile() { return path.join(dataDir(), 'state.json'); }

function readJson(p) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); }
  catch (_) { return null; }
}

// Universal hard-deny patterns — never auto-approved in yolo mode, regardless
// of domain. Keep this list UNIVERSAL (security, not opinion about tools):
// anything tool-specific (aws, stripe, kubectl, etc.) belongs in the user's
// own `deniedPatterns` config, not baked into a community plugin.
const HARD_DENY_RE = [
  // Shell interpreters with inline code
  /(^|\s)(bash|sh|zsh|ksh|dash|fish)\s+-c\b/,
  /(^|\s)sudo\b/,
  /(^|\s)doas\b/,
  /(^|\s)eval\b/,
  /(^|\s)(source|\.)\s+/,
  // Pipe into shell (classic one-liner attack vector)
  /\|\s*(bash|sh|zsh|ksh|dash|fish)\b/,
  // Inline-exec flags on interpreters
  /(^|\s)(node|python|python3|python2|py|deno|bun|perl|ruby|php)\s+(-c|-e|--eval|-r)\b/,
  // Recursive filesystem destruction starting from root or HOME
  /\brm\s+(-[rRfF]+\s+)+(\/|~\/?|\$HOME\/?)(\s|$)/,
  // Following redirects — can bypass domain allowlists elsewhere
  /(^|\s)(curl|wget)\s+[^#\n]*(-L\b|--location\b)/,
  // Git force-push / push to protected branches
  /git\s+push\b.*(\s|=)(main|master|production|prod|release)(\s|$)/,
  /git\s+push\b.*--force\b/,
];

// Safe patterns — auto-approved in yolo mode.
const SAFE_BINARIES = new Set([
  'ls', 'cat', 'head', 'tail', 'wc', 'file', 'stat', 'tree', 'find',
  'grep', 'egrep', 'fgrep', 'rg', 'sed', 'awk', 'cut', 'sort', 'uniq', 'tr', 'tee',
  'jq', 'yq',
  'echo', 'printf', 'true', 'false', 'date', 'pwd', 'basename', 'dirname',
  'mkdir', 'touch', 'readlink', 'realpath',
  'cd', 'test',
  'diff', 'patch', 'cmp',
  'git',
  'node', 'npm', 'npx', 'pnpm', 'yarn',
  'make',
]);

function firstBinary(command) {
  // Best-effort extraction of the first invoked binary. We don't have shfmt
  // as a hard dep here, so keep it simple: strip env-var prefixes, take the
  // first bare word.
  let c = String(command).trim();
  // Strip env-var assignments: FOO=bar BAZ=qux cmd ...
  while (/^[A-Z_][A-Z0-9_]*=\S+\s+/.test(c)) {
    c = c.replace(/^[A-Z_][A-Z0-9_]*=\S+\s+/, '');
  }
  const m = c.match(/^"?([^\s"'`|&;<>]+)"?/);
  if (!m) return null;
  let bin = m[1];
  bin = path.basename(bin);
  if (bin.toLowerCase().endsWith('.exe')) bin = bin.slice(0, -4);
  return bin;
}

function normalizedCommand(command) {
  // Strip env-var prefixes so matchers compare against the real invocation.
  let c = String(command).trim();
  while (/^[A-Z_][A-Z0-9_]*=\S+\s+/.test(c)) {
    c = c.replace(/^[A-Z_][A-Z0-9_]*=\S+\s+/, '');
  }
  return c;
}

function loadUserBashAllowRules() {
  // Collect Bash(...) allow-rule bodies from user + project settings files.
  // Same layering semantics as Claude Code: user → project → local, union.
  const sources = [
    path.join(os.homedir(), '.claude', 'settings.json'),
    path.join(process.cwd(), '.claude', 'settings.json'),
    path.join(process.cwd(), '.claude', 'settings.local.json'),
  ];
  const out = [];
  for (const src of sources) {
    const j = readJson(src);
    const list = j && j.permissions && Array.isArray(j.permissions.allow) ? j.permissions.allow : [];
    for (const entry of list) {
      if (typeof entry !== 'string') continue;
      const m = entry.match(/^Bash\((.*)\)$/);
      if (m) out.push(m[1]);
    }
  }
  return out;
}

function matchesBashRule(normalizedCmd, rulePattern) {
  // Claude Code Bash rule conventions:
  //   Bash(git status)      → exact match: command must equal "git status"
  //   Bash(git status:*)    → prefix match: starts with "git status"
  //   Bash(git *)           → glob: any git subcommand
  //   Bash(ls /tmp:*)       → prefix match: starts with "ls /tmp"
  if (rulePattern.endsWith(':*')) {
    const prefix = rulePattern.slice(0, -2);
    return normalizedCmd === prefix || normalizedCmd.startsWith(prefix + ' ') || normalizedCmd.startsWith(prefix + '\t');
  }
  if (rulePattern.includes('*')) {
    const escaped = rulePattern
      .replace(/[.+^${}()|[\]\\]/g, '\\$&')
      .replace(/\\\*/g, '*'); // un-escape our wildcard placeholder (preceding escape also escapes *)
    const re = new RegExp('^' + escaped.replace(/\*/g, '.*') + '$');
    return re.test(normalizedCmd);
  }
  return normalizedCmd === rulePattern;
}

function matchesAnyUserAllow(normalizedCmd, rules) {
  return rules.some((r) => {
    try { return matchesBashRule(normalizedCmd, r); }
    catch (_) { return false; }
  });
}

function main() {
  // Read roam state — if inactive or yolo off, fall through silently.
  const state = readJson(stateFile());
  if (!state || state.active !== true) fallthrough();
  const yolo = !!(state.config_snapshot && state.config_snapshot.yolo_enabled);
  if (!yolo) fallthrough();

  // Read hook input
  let input = '';
  try { input = fs.readFileSync(0, 'utf8'); }
  catch (_) { fallthrough(); }
  let parsed;
  try { parsed = JSON.parse(input); }
  catch (_) { fallthrough(); }
  const command = parsed && parsed.tool_input && parsed.tool_input.command;
  if (typeof command !== 'string' || !command.length) fallthrough();

  // 1. Universal security hard-deny (never bypassable)
  for (const re of HARD_DENY_RE) {
    if (re.test(command)) {
      ask(`roam yolo: security pattern ${re} requires manual approval`);
    }
  }

  // 2. User-defined deniedPatterns (roam config)
  const userDenies = (state.config_snapshot && state.config_snapshot.deniedPatterns) || [];
  for (const pat of userDenies) {
    try {
      if (new RegExp(pat).test(command)) {
        ask(`roam yolo: user-defined deny /${pat}/`);
      }
    } catch (_) { /* ignore malformed user regex */ }
  }

  const normalized = normalizedCommand(command);

  // 3. User's own Claude Code allow rules (opt-out via config)
  const honorUserAllow = !(state.config_snapshot && state.config_snapshot.honorClaudeAllowList === false);
  if (honorUserAllow) {
    const userAllow = loadUserBashAllowRules();
    if (matchesAnyUserAllow(normalized, userAllow)) {
      allow(`roam yolo: matches your Claude Code allow list`);
    }
  }

  // 4. Roam's built-in safe set
  const bin = firstBinary(command);
  if (!bin) ask('roam yolo: could not identify binary');
  if (SAFE_BINARIES.has(bin)) {
    allow(`roam yolo: '${bin}' is in the built-in safe set`);
  }

  // 5. Unknown → prompt
  ask(`roam yolo: '${bin}' not in safe set or user allow list — prompting`);
}

try { main(); } catch (_) { fallthrough(); }
