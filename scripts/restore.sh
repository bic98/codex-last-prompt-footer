#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[codex-last-prompt-footer] %s\n' "$1"
}

launcher="$(command -v codex 2>/dev/null || true)"
if [[ -z "$launcher" ]]; then
  printf 'Could not locate the installed codex launcher.\n' >&2
  exit 1
fi

shim_dir="$(cd "$(dirname "$launcher")" && pwd)"
backup="$launcher.openai-backup"
custom_dir="$shim_dir/custom-codex"

if [[ -e "$backup" ]]; then
  cp "$backup" "$launcher"
  chmod +x "$launcher"
  log "Original Codex launcher restored."
else
  log "No backup launcher was found. Nothing was restored."
fi

if [[ -d "$custom_dir" ]]; then
  rm -rf "$custom_dir"
fi
