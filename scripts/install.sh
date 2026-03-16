#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-$HOME/.codex-last-prompt-footer}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="$REPO_ROOT/scripts/build.sh"
OUTPUT_DIR="${OUTPUT_DIR:-$STATE_DIR/dist/posix}"
BUILT_BIN="$OUTPUT_DIR/codex"
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

ensure_profile_source_line() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  remove_managed_block "$file"
  cat >> "$file" <<EOF
$MARKER_BEGIN
if [ -f "$PROFILE_SNIPPET" ]; then
  . "$PROFILE_SNIPPET"
fi
$MARKER_END
EOF
}

log "Preparing patched codex binary"
bash "$BUILD_SCRIPT" "$@"

if [[ ! -x "$BUILT_BIN" ]]; then
  printf 'Built binary not found: %s\n' "$BUILT_BIN" >&2
  exit 1
fi

mkdir -p "$WRAPPER_DIR"
mkdir -p "$(dirname "$PROFILE_SNIPPET")"

cat > "$PROFILE_SNIPPET" <<EOF
export PATH="$WRAPPER_DIR:\$PATH"
EOF

cat > "$WRAPPER_DIR/codex" <<EOF
#!/usr/bin/env bash
exec "$BUILT_BIN" "\$@"
EOF
chmod +x "$WRAPPER_DIR/codex"

for rc_file in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
  ensure_profile_source_line "$rc_file"
done

log "Installed persistent Codex shim at $WRAPPER_DIR/codex"
log "The official npm launcher is no longer modified."
log "Open a new shell or run: export PATH=\"$WRAPPER_DIR:\$PATH\""
