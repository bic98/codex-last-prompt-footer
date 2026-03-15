#!/usr/bin/env bash
set -euo pipefail

CODEX_TAG="${CODEX_TAG:-rust-v0.114.0}"
STATE_DIR="${STATE_DIR:-$HOME/.codex-last-prompt-footer}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-$STATE_DIR/openai-codex}"
OUTPUT_DIR="${OUTPUT_DIR:-$STATE_DIR/dist/posix}"
PATCH_FILE="${PATCH_FILE:-}"
RELEASE_REPOSITORY="${RELEASE_REPOSITORY:-bic98/codex-last-prompt-footer}"
RELEASE_TAG="${RELEASE_TAG:-v${CODEX_TAG#rust-v}}"
SKIP_PREBUILT_DOWNLOAD="${SKIP_PREBUILT_DOWNLOAD:-0}"
BUILD_INFO_FILE="$OUTPUT_DIR/.build-info"

log() {
  printf '[codex-last-prompt-footer] %s\n' "$1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  }
}

patch_name_for_tag() {
  local tag="$1"
  local normalized="${tag#rust-}"
  printf 'codex-%s-last-prompt-footer.patch' "$normalized"
}

resolve_patch_file() {
  if [[ -n "$PATCH_FILE" ]]; then
    [[ -f "$PATCH_FILE" ]] || {
      printf 'Patch file not found: %s\n' "$PATCH_FILE" >&2
      exit 1
    }
    printf '%s\n' "$PATCH_FILE"
    return
  fi

  local candidate="$REPO_ROOT/patches/$(patch_name_for_tag "$CODEX_TAG")"
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return
  fi

  printf 'Patch file not found for %s. Expected: %s\n' "$CODEX_TAG" "$candidate" >&2
  printf 'Set PATCH_FILE=/absolute/path/to/your.patch if you are targeting a different Codex tag.\n' >&2
  exit 1
}

detect_platform() {
  case "$(uname -s)" in
    Linux) printf 'linux\n' ;;
    Darwin) printf 'macos\n' ;;
    *) printf 'unsupported\n' ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'x86_64\n' ;;
    arm64|aarch64) printf 'aarch64\n' ;;
    *) printf 'unsupported\n' ;;
  esac
}

compute_patch_sha() {
  local patch_file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$patch_file" | awk '{print $1}'
  else
    sha256sum "$patch_file" | awk '{print $1}'
  fi
}

write_build_info() {
  local source="$1"
  local patch_sha="$2"
  mkdir -p "$OUTPUT_DIR"
  cat > "$BUILD_INFO_FILE" <<EOF
CODEX_TAG=$CODEX_TAG
PATCH_SHA=$patch_sha
SOURCE=$source
EOF
}

has_matching_build() {
  local patch_sha="$1"
  [[ -x "$OUTPUT_DIR/codex" ]] || return 1
  [[ -f "$BUILD_INFO_FILE" ]] || return 1
  grep -qx "CODEX_TAG=$CODEX_TAG" "$BUILD_INFO_FILE" &&
    grep -qx "PATCH_SHA=$patch_sha" "$BUILD_INFO_FILE"
}

download_prebuilt_binary() {
  local platform="$1"
  local arch="$2"
  local version="${CODEX_TAG#rust-v}"
  local asset="codex-last-prompt-footer-${version}-${platform}-${arch}.tar.gz"
  local url="https://github.com/${RELEASE_REPOSITORY}/releases/download/${RELEASE_TAG}/${asset}"
  local archive="$STATE_DIR/$asset"
  local tmp_dir

  tmp_dir="$(mktemp -d)"
  log "Trying prebuilt binary: $url"
  if ! curl -fsSL "$url" -o "$archive"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  tar -xzf "$archive" -C "$tmp_dir"
  if [[ ! -x "$tmp_dir/codex" ]]; then
    printf 'Downloaded prebuilt archive did not contain an executable codex binary.\n' >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  mkdir -p "$OUTPUT_DIR"
  cp "$tmp_dir/codex" "$OUTPUT_DIR/codex"
  chmod +x "$OUTPUT_DIR/codex"
  rm -rf "$tmp_dir"
}

show_linux_native_deps_help() {
  cat >&2 <<'EOF'
Missing native build dependencies for OpenAI Codex CLI.

Install the required development packages for your distro, then rerun the installer.

Ubuntu / Debian:
  sudo apt-get update && sudo apt-get install -y libssl-dev libcap-dev pkg-config build-essential

Fedora / RHEL:
  sudo dnf install -y openssl-devel libcap-devel pkgconf-pkg-config gcc gcc-c++ make

Arch Linux:
  sudo pacman -S --needed openssl libcap pkgconf base-devel
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
      if ! pkg-config --exists libcap; then
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
PATCH_FILE="$(resolve_patch_file)"
PATCH_SHA="$(compute_patch_sha "$PATCH_FILE")"

if has_matching_build "$PATCH_SHA"; then
  log "Using cached patched binary at $OUTPUT_DIR/codex"
  exit 0
fi

mkdir -p "$STATE_DIR"
PLATFORM="$(detect_platform)"
ARCH="$(detect_arch)"

if [[ "$SKIP_PREBUILT_DOWNLOAD" != "1" && "$PLATFORM" != "unsupported" && "$ARCH" != "unsupported" ]]; then
  if download_prebuilt_binary "$PLATFORM" "$ARCH"; then
    write_build_info "release" "$PATCH_SHA"
    log "Downloaded prebuilt patched binary: $OUTPUT_DIR/codex"
    exit 0
  fi
  log "No compatible prebuilt binary found. Falling back to local Rust build."
fi

ensure_rust
export PATH="$HOME/.cargo/bin:$PATH"
ensure_native_build_deps

if [[ ! -d "$SOURCE_DIR" ]]; then
  log "Cloning official openai/codex source (shallow) into $SOURCE_DIR"
  git clone --depth 1 --branch "$CODEX_TAG" https://github.com/openai/codex.git "$SOURCE_DIR"
else
  log "Using existing source cache at $SOURCE_DIR"
  if ! git -C "$SOURCE_DIR" describe --tags --exact-match HEAD 2>/dev/null | grep -qF "$CODEX_TAG"; then
    log "Fetching tag $CODEX_TAG"
    git -C "$SOURCE_DIR" fetch --depth 1 origin tag "$CODEX_TAG" --no-tags
  fi
  git -C "$SOURCE_DIR" checkout --force "$CODEX_TAG"
  git -C "$SOURCE_DIR" reset --hard "$CODEX_TAG"
  git -C "$SOURCE_DIR" clean -fd
fi

log "Applying last-prompt footer patch"
if ! git -C "$SOURCE_DIR" apply --check "$PATCH_FILE" 2>/dev/null; then
  log "Patch already applied or source has diverged; resetting and retrying"
  git -C "$SOURCE_DIR" checkout --force "$CODEX_TAG"
  git -C "$SOURCE_DIR" reset --hard "$CODEX_TAG"
fi
git -C "$SOURCE_DIR" apply "$PATCH_FILE"

log "Building patched codex-cli (this may take a few minutes on first run)"
pushd "$SOURCE_DIR/codex-rs" >/dev/null
cargo +stable build -p codex-cli --release --locked
popd >/dev/null

mkdir -p "$OUTPUT_DIR"
cp "$SOURCE_DIR/codex-rs/target/release/codex" "$OUTPUT_DIR/codex"
chmod +x "$OUTPUT_DIR/codex"
write_build_info "local" "$PATCH_SHA"

log "Patched binary ready: $OUTPUT_DIR/codex"
