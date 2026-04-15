#!/usr/bin/env node
/*
 * statusline.js — manage Claude Code statusLine integration for the 🎒
 * roam indicator. Three modes:
 *
 *   check    → print "integrated" | "absent" | "other" | "ours-minimal"
 *              (exit 0 always)
 *   new      → create a minimal statusLine pointing at `roam-cli indicator`
 *   wrap     → preserve the user's existing statusLine by writing a wrapper
 *              script that calls both their command AND our indicator, and
 *              updating settings.json to point at the wrapper
 *   unwrap   → reverse `wrap`: restore the user's original statusLine
 *              (reads the embedded original command from the wrapper file)
 *
 * All JSON manipulation happens in Node so the user's settings.json is
 * preserved byte-for-byte aside from the single field we touch.
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const SETTINGS = path.join(os.homedir(), '.claude', 'settings.json');
const WRAPPER_DIR = path.join(os.homedir(), '.claude', 'bin');
const WRAPPER_PATH = path.join(WRAPPER_DIR, 'roam-wrapped-statusline.sh');
const INDICATOR_CMD = 'bash "$HOME/.claude/roam/bin/roam-cli" indicator';
const ROAM_MARKER = '# roam-wrapped-statusline';

function readSettings() {
  try { return JSON.parse(fs.readFileSync(SETTINGS, 'utf8')); }
  catch { return {}; }
}

function writeSettings(obj) {
  fs.mkdirSync(path.dirname(SETTINGS), { recursive: true });
  fs.writeFileSync(SETTINGS, JSON.stringify(obj, null, 2) + '\n');
}

function statusLineIsOurs(s) {
  if (!s || typeof s.command !== 'string') return false;
  return /roam-cli["'\s]+indicator|roam-indicator\.sh|roam-wrapped-statusline/.test(s.command);
}

function statusLineIsOurMinimal(s) {
  if (!s || typeof s.command !== 'string') return false;
  return /roam-cli["'\s]+indicator/.test(s.command) && !/roam-wrapped-statusline/.test(s.command);
}

function main() {
  const mode = process.argv[2];

  switch (mode) {
    case 'check': {
      const s = readSettings().statusLine;
      if (!s || !s.command) { process.stdout.write('absent\n'); return; }
      if (statusLineIsOurMinimal(s)) { process.stdout.write('ours-minimal\n'); return; }
      if (statusLineIsOurs(s)) { process.stdout.write('integrated\n'); return; }
      process.stdout.write('other\n');
      return;
    }

    case 'new': {
      const settings = readSettings();
      if (settings.statusLine && statusLineIsOurs(settings.statusLine)) {
        process.stdout.write('already integrated\n');
        return;
      }
      settings.statusLine = {
        type: 'command',
        command: INDICATOR_CMD,
        refreshInterval: 30,
      };
      writeSettings(settings);
      process.stdout.write('installed minimal statusLine\n');
      return;
    }

    case 'wrap': {
      const settings = readSettings();
      const existing = settings.statusLine;
      if (!existing || !existing.command) {
        process.stderr.write('no existing statusLine — use `new` instead\n');
        process.exit(1);
      }
      if (statusLineIsOurs(existing)) {
        process.stdout.write('already integrated\n');
        return;
      }

      fs.mkdirSync(WRAPPER_DIR, { recursive: true });
      const wrapper = [
        '#!/bin/bash',
        ROAM_MARKER,
        '# Composite Claude Code statusLine: calls your original command, then',
        '# appends the 🎒 indicator when roam is active. Managed by claude-code-roam.',
        '# To revert, run /roam:uninstall (or delete this file and restore your',
        '# previous statusLine in ~/.claude/settings.json).',
        '',
        '# --- original user statusLine begins ---',
        `ORIG_OUT="$(${existing.command})"`,
        '# --- original user statusLine ends ---',
        '',
        'INDICATOR="$(bash "$HOME/.claude/roam/bin/roam-cli" indicator 2>/dev/null)"',
        'if [ -n "$INDICATOR" ]; then',
        '  printf \'%s %s\' "$ORIG_OUT" "$INDICATOR"',
        'else',
        '  printf \'%s\' "$ORIG_OUT"',
        'fi',
        '',
      ].join('\n');
      fs.writeFileSync(WRAPPER_PATH, wrapper);
      fs.chmodSync(WRAPPER_PATH, 0o755);

      settings.statusLine = {
        type: 'command',
        command: WRAPPER_PATH,
        refreshInterval: existing.refreshInterval || 30,
        padding: existing.padding,
      };
      // Drop undefined padding so we don't serialize it.
      if (settings.statusLine.padding === undefined) delete settings.statusLine.padding;
      writeSettings(settings);
      process.stdout.write(`wrapped — wrapper at ${WRAPPER_PATH}\n`);
      return;
    }

    case 'unwrap': {
      const settings = readSettings();
      const existing = settings.statusLine;
      if (!existing || !fs.existsSync(WRAPPER_PATH)) {
        process.stdout.write('nothing to unwrap\n');
        return;
      }
      // Parse the ORIG_OUT line out of the wrapper to restore the user's command.
      const wrapperContent = fs.readFileSync(WRAPPER_PATH, 'utf8');
      const m = wrapperContent.match(/^ORIG_OUT="\$\((.+)\)"$/m);
      if (!m) {
        process.stderr.write('wrapper file is malformed — cannot unwrap automatically\n');
        process.exit(1);
      }
      settings.statusLine = {
        type: 'command',
        command: m[1],
        refreshInterval: existing.refreshInterval || 30,
      };
      writeSettings(settings);
      fs.unlinkSync(WRAPPER_PATH);
      process.stdout.write('unwrapped — original statusLine restored\n');
      return;
    }

    default:
      process.stderr.write('usage: statusline.js {check|new|wrap|unwrap}\n');
      process.exit(2);
  }
}

try { main(); }
catch (e) {
  process.stderr.write(`statusline integration error: ${e && e.message ? e.message : String(e)}\n`);
  process.exit(1);
}
