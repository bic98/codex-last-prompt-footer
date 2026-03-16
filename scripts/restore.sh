#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-$HOME/.codex-last-prompt-footer}"
WRAPPER_DIR="${WRAPPER_DIR:-$STATE_DIR/shims/posix/bin}"
PROFILE_SNIPPET="$STATE_DIR/shims/posix/env.sh"
MARKER_BEGIN="# >>> codex-last-prompt-footer >>>"
MARKER_END="# <<< codex-last-prompt-footer <<<"

log() {
  printf '[codex-last-prompt-footer] %s\n' "$1"
}

remove_managed_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
    $0 == begin { skipping=1; next }
    $0 == end { skipping=0; next }
    !skipping { print }
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

rm -f "$WRAPPER_DIR/codex"
rm -f "$PROFILE_SNIPPET"

for rc_file in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
  remove_managed_block "$rc_file"
done

log "Removed persistent Codex shim from $WRAPPER_DIR"
log "Open a new shell to pick up the restored PATH."
