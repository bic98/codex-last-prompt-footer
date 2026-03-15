#!/usr/bin/env bash
set -euo pipefail

CODEX_TAG="${CODEX_TAG:-rust-v0.114.0}"
STATE_DIR="${STATE_DIR:-$HOME/.codex-last-prompt-footer}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-$STATE_DIR/openai-codex}"
OUTPUT_DIR="${OUTPUT_DIR:-$STATE_DIR/dist/posix}"
PATCH_FILE="$REPO_ROOT/patches/codex-v0.114.0-last-prompt-footer.patch"

log() {
  printf '[codex-last-prompt-footer] %s\n' "$1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  }
}

show_linux_native_deps_help() {
  cat >&2 <<'EOF'
Missing native build dependencies for OpenAI Codex CLI.

Install the OpenSSL development package and pkg-config for your distro, then rerun the installer.

Ubuntu / Debian:
  sudo apt-get update && sudo apt-get install -y libssl-dev pkg-config build-essential

Fedora / RHEL:
  sudo dnf install -y openssl-devel pkgconf-pkg-config gcc gcc-c++ make

Arch Linux:
  sudo pacman -S --needed openssl pkgconf base-devel
EOF
}

show_macos_native_deps_help() {
  cat >&2 <<'EOF'
Missing native build dependencies for OpenAI Codex CLI.

Install the OpenSSL development package and pkg-config with Homebrew, then rerun the installer.

macOS:
  brew install openssl@3 pkg-config
EOF
}

ensure_native_build_deps() {
  case "$(uname -s)" in
    Linux)
      if ! command -v pkg-config >/dev/null 2>&1; then
        show_linux_native_deps_help
        exit 1
      fi
      if ! pkg-config --exists openssl; then
        show_linux_native_deps_help
        exit 1
      fi
      ;;
    Darwin)
      if ! command -v pkg-config >/dev/null 2>&1; then
        show_macos_native_deps_help
        exit 1
      fi
      if ! pkg-config --exists openssl; then
        show_macos_native_deps_help
        exit 1
      fi
      ;;
  esac
}

ensure_rust() {
  if command -v cargo >/dev/null 2>&1; then
    return
  fi

  log "Rust not found. Installing rustup (stable, minimal profile)."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
}

need_cmd git
need_cmd curl
ensure_rust

export PATH="$HOME/.cargo/bin:$PATH"

ensure_native_build_deps

if [[ ! -f "$PATCH_FILE" ]]; then
  printf 'Patch file not found: %s\n' "$PATCH_FILE" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"

if [[ ! -d "$SOURCE_DIR" ]]; then
  log "Cloning official openai/codex source into $SOURCE_DIR"
  git clone https://github.com/openai/codex.git "$SOURCE_DIR"
else
  log "Using existing source cache at $SOURCE_DIR"
fi

log "Fetching tags"
git -C "$SOURCE_DIR" fetch --tags origin

log "Checking out $CODEX_TAG"
git -C "$SOURCE_DIR" checkout --force "$CODEX_TAG"

git -C "$SOURCE_DIR" reset --hard "$CODEX_TAG"
git -C "$SOURCE_DIR" clean -fd

log "Applying last-prompt footer patch"
git -C "$SOURCE_DIR" apply "$PATCH_FILE"

log "Building patched codex-cli"
pushd "$SOURCE_DIR/codex-rs" >/dev/null
cargo +stable build -p codex-cli --release
popd >/dev/null

mkdir -p "$OUTPUT_DIR"
cp "$SOURCE_DIR/codex-rs/target/release/codex" "$OUTPUT_DIR/codex"
chmod +x "$OUTPUT_DIR/codex"

log "Patched binary ready: $OUTPUT_DIR/codex"
