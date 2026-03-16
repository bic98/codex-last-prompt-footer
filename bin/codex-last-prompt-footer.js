#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');

const scripts = {
  install: path.join(repoRoot, 'scripts', 'install.sh'),
  build: path.join(repoRoot, 'scripts', 'build.sh'),
  restore: path.join(repoRoot, 'scripts', 'restore.sh'),
};

const args = process.argv.slice(2);
const hasExplicitCommand = args[0] && !args[0].startsWith('-');
const command = hasExplicitCommand ? args[0] : 'install';
const passthroughArgs = hasExplicitCommand ? args.slice(1) : args;

function printHelp() {
  console.log(`codex-last-prompt-footer

Usage:
  npx --yes github:bic98/codex-last-prompt-footer
  npx --yes github:bic98/codex-last-prompt-footer --install-deps
  npx codex-last-prompt-footer
  npx codex-last-prompt-footer --install-deps
  npx codex-last-prompt-footer install
  npx codex-last-prompt-footer build
  npx codex-last-prompt-footer restore

Commands:
  install   Build and install the patched Codex CLI footer on Linux/macOS
  build     Build the patched Codex binary only
  restore   Restore the original Codex launcher backup
  help      Show this help text

Options:
  --install-deps  Attempt to install missing native build dependencies automatically

Environment:
  CODEX_TAG   Override the OpenAI Codex source tag (default: rust-v0.114.0)
  STATE_DIR   Override the cache root (default: ~/.codex-last-prompt-footer)
  SOURCE_DIR  Override the cached source directory for openai/codex
  OUTPUT_DIR  Override the build output directory used by build.sh
  AUTO_INSTALL_DEPS=1  Same as passing --install-deps
`);
}

if (args.includes('--help') || args.includes('-h') || command === 'help') {
  printHelp();
  process.exit(0);
}

if (process.platform === 'win32') {
  console.error('codex-last-prompt-footer npx install is intended for Linux/macOS. On Windows, run scripts\\install.ps1 instead.');
  process.exit(1);
}

if (!(command in scripts)) {
  console.error(`Unknown command: ${command}`);
  printHelp();
  process.exit(1);
}

const scriptPath = scripts[command];
if (!existsSync(scriptPath)) {
  console.error(`Script not found: ${scriptPath}`);
  process.exit(1);
}

const result = spawnSync('bash', [scriptPath, ...passthroughArgs], {
  cwd: repoRoot,
  stdio: 'inherit',
  env: process.env,
});

if (result.error) {
  if (result.error.code === 'ENOENT') {
    console.error('bash is required but was not found in PATH.');
  } else {
    console.error(result.error.message);
  }
  process.exit(1);
}

process.exit(result.status ?? 1);
