#!/usr/bin/env bash
set -euo pipefail

CODEX_TAG="${CODEX_TAG:-rust-v0.114.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="$REPO_ROOT/scripts/build.sh"
BUILT_BIN="$REPO_ROOT/dist/posix/codex"

log() {
  printf '[codex-last-prompt-footer] %s\n' "$1"
}

find_codex_launcher() {
  command -v codex 2>/dev/null || true
}

backup_if_needed() {
  local path="$1"
  if [[ -e "$path" && ! -e "$path.openai-backup" ]]; then
    cp "$path" "$path.openai-backup"
  fi
}

launcher="$(find_codex_launcher)"
if [[ -z "$launcher" ]]; then
  printf 'Could not locate the installed codex launcher.\n' >&2
  exit 1
fi

log "Building patched codex binary"
bash "$BUILD_SCRIPT"

if [[ ! -x "$BUILT_BIN" ]]; then
  printf 'Built binary not found: %s\n' "$BUILT_BIN" >&2
  exit 1
fi

shim_dir="$(cd "$(dirname "$launcher")" && pwd)"
custom_dir="$shim_dir/custom-codex"
mkdir -p "$custom_dir"
cp "$BUILT_BIN" "$custom_dir/codex"
chmod +x "$custom_dir/codex"

backup_if_needed "$launcher"

cat > "$launcher" <<'EOF'
#!/usr/bin/env bash
basedir="$(cd "$(dirname "$0")" && pwd)"
exec "$basedir/custom-codex/codex" "$@"
EOF
chmod +x "$launcher"

log "Installed patched Codex launcher into $shim_dir"
log "Original launcher was backed up with the .openai-backup suffix"
log "Run 'codex --version' or launch 'codex' normally to test"
