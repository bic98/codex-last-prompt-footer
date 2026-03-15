#!/usr/bin/env bash
set -euo pipefail

CODEX_TAG="${CODEX_TAG:-rust-v0.114.0}"
CODEX_VERSION="${CODEX_TAG#rust-v}"
STATE_DIR="${STATE_DIR:-$HOME/.codex-last-prompt-footer}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="$REPO_ROOT/scripts/build.sh"
OUTPUT_DIR="${OUTPUT_DIR:-$STATE_DIR/dist/posix}"
BUILT_BIN="$OUTPUT_DIR/codex"
GITHUB_REPO="bic98/codex-last-prompt-footer"

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

detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)  os="linux" ;;
    Darwin) os="darwin" ;;
    *)      printf ''; return ;;
  esac

  case "$arch" in
    x86_64|amd64)   arch="x86_64" ;;
    aarch64|arm64)   arch="aarch64" ;;
    *)               printf ''; return ;;
  esac

  printf '%s-%s' "$os" "$arch"
}

try_download_prebuilt() {
  local platform="$1"
  if [[ -z "$platform" ]]; then
    return 1
  fi

  local asset_name="codex-${platform}.tar.gz"
  local url="https://github.com/${GITHUB_REPO}/releases/download/v${CODEX_VERSION}/${asset_name}"

  log "Attempting to download pre-built binary for $platform"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  if curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$tmpdir/$asset_name" 2>/dev/null; then
    mkdir -p "$OUTPUT_DIR"
    tar -xzf "$tmpdir/$asset_name" -C "$OUTPUT_DIR"
    chmod +x "$OUTPUT_DIR/codex"
    log "Pre-built binary downloaded successfully (no Rust build needed)"
    return 0
  fi

  log "No pre-built binary available for $platform — falling back to source build"
  return 1
}

launcher="$(find_codex_launcher)"
if [[ -z "$launcher" ]]; then
  printf 'Could not locate the installed codex launcher.\n' >&2
  printf 'Install the official Codex CLI first: npm install -g @openai/codex\n' >&2
  exit 1
fi

platform="$(detect_platform)"

if try_download_prebuilt "$platform"; then
  : # binary downloaded, skip build
else
  log "Building patched codex binary from source"
  bash "$BUILD_SCRIPT"
fi

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
