# Codex Last Prompt Footer

[![npm version](https://img.shields.io/npm/v/codex-last-prompt-footer)](https://www.npmjs.com/package/codex-last-prompt-footer)
[![npm downloads](https://img.shields.io/npm/dm/codex-last-prompt-footer)](https://www.npmjs.com/package/codex-last-prompt-footer)
[![GitHub stars](https://img.shields.io/github/stars/bic98/codex-last-prompt-footer?style=social)](https://github.com/bic98/codex-last-prompt-footer)
[![license](https://img.shields.io/github/license/bic98/codex-last-prompt-footer)](./LICENSE)

`Codex Last Prompt Footer` keeps your latest prompt visible in the OpenAI Codex CLI footer with a live `Q: ...` preview next to the usual model and usage stats.

![Codex Last Prompt Footer Demo](./assets/demo.svg)

## Why This Is Useful

Codex CLI already shows useful footer information, but it does not remind you what your last prompt was. Once the session gets busy, that becomes annoying fast.

This project patches the official Codex CLI footer so the latest submitted prompt stays visible while you work.

Before:

```text
gpt-5.4 · gpt-5.4 high · 5h 99% · weekly 68%
```

After:

```text
gpt-5.4 · gpt-5.4 high · 5h 99% · weekly 68% · Q: fix the footer layout bug
```

## Why People Install It

- You stop reopening the conversation just to remember your last question.
- The patch is small and focused instead of replacing the whole CLI.
- Linux and macOS can install it with one `npx` command.
- Matching GitHub Release binaries can skip the local Rust build entirely.
- The official npm launcher is no longer overwritten.
- The installed shim survives `npm i -g @openai/codex@latest`.
- It targets the official `openai/codex` Rust release tag.

## Install

### Recommended: GitHub Source

Until the npm package is republished with the latest installer flow, prefer running directly from GitHub:

```bash
npx --yes github:bic98/codex-last-prompt-footer
```

If Linux or macOS build dependencies are missing:

```bash
npx --yes github:bic98/codex-last-prompt-footer --install-deps
```

### Fastest: GitHub Releases

This repository now publishes a native installer binary and cargo-dist installers in GitHub Releases. That gives you a direct native install path without depending on Node.js just to start the installer.

Release artifacts include:

- platform-specific installer binaries like `codex-last-prompt-footer-x86_64-unknown-linux-gnu.tar.xz`
- cargo-dist shell and PowerShell installers
- patched Codex release assets that the installer can download before falling back to a local Rust build

If you prefer a release download flow, use the latest assets from:

```text
https://github.com/bic98/codex-last-prompt-footer/releases
```

### Linux / macOS

If the npm package is already up to date, this also works:

```bash
npx codex-last-prompt-footer
```

The installer automatically downloads a pre-built binary when available, so you can skip the Rust build entirely. If no pre-built binary exists for your platform, it falls back to building from source.

The install now creates a persistent user shim instead of replacing npm's global `codex` launcher, so updating `@openai/codex` does not remove the footer patch.

If Linux or macOS build dependencies are missing, you can let the installer attempt to install them:

```bash
npx codex-last-prompt-footer --install-deps
```

GitHub source alternative:

```bash
npx --yes github:bic98/codex-last-prompt-footer
```

```bash
git clone https://github.com/bic98/codex-last-prompt-footer.git
cd codex-last-prompt-footer
bash ./scripts/install.sh
```

### Windows PowerShell

```powershell
git clone https://github.com/bic98/codex-last-prompt-footer.git
cd codex-last-prompt-footer
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

If Visual Studio Build Tools are missing, let the installer attempt to install them:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -InstallDeps
```

Manual alternative:

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --source winget --accept-source-agreements --accept-package-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

The Windows install also creates a persistent user shim instead of replacing npm's global `codex.cmd` / `codex.ps1` launchers.

## Linux / macOS Troubleshooting

Codex CLI is a Rust binary. This installer tries a matching GitHub Release binary first. If none exists for your OS and CPU, it falls back to a local Rust build, and that build may fail on Linux if native development headers are missing (`openssl`, `libcap`, `pkg-config`).

Ubuntu / Debian:

```bash
sudo apt-get update && sudo apt-get install -y libssl-dev libcap-dev pkg-config build-essential
```

Fedora / RHEL:

```bash
sudo dnf install -y openssl-devel libcap-devel pkgconf-pkg-config gcc gcc-c++ make
```

Arch Linux:

```bash
sudo pacman -S --needed openssl libcap pkgconf base-devel
```

macOS:

```bash
brew install openssl@3 pkg-config
```

If you hit `openssl-sys`, `libcap`, `pkg-config`, or native header errors, install the packages above and rerun the command.

## Distribution Model

This project now ships in two layers:

1. A native installer binary released with cargo-dist.
2. Patched Codex binaries released as GitHub assets for fast installs.

The goal is to keep Rust compilation on end-user machines as a fallback, not the default path, while keeping the installed `codex` shim outside npm-managed files.

## Commands

Restore the original Codex launcher:

```bash
npx codex-last-prompt-footer restore
```

This removes the persistent shim and restores normal PATH resolution back to the official `codex` installation.

Build only:

```bash
npx codex-last-prompt-footer build
```

GitHub source alternative:

```bash
npx --yes github:bic98/codex-last-prompt-footer restore
npx --yes github:bic98/codex-last-prompt-footer build
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

## What It Changes

1. Prepares a patched `codex` installation in your user state directory.
2. Tries to download a matching prebuilt patched binary from GitHub Releases.
3. If no prebuilt binary exists, installs Rust automatically if needed.
4. Checks native build dependencies on Linux/macOS or Visual Studio Build Tools on Windows.
5. Shallow-clones `openai/codex` at `rust-v0.114.0`.
6. Applies the footer patch.
7. Builds a patched `codex` binary.
8. Installs a persistent user-level `codex` shim outside npm-managed files.
9. Adds that shim directory to your shell PATH.

## Compatibility

Current target:

- `@openai/codex` `0.114.0`
- source tag `rust-v0.114.0`

Pre-built binaries are available for:

| Platform | Architecture |
|----------|-------------|
| Linux | x86_64 |
| macOS | x86_64 (Intel), aarch64 (Apple Silicon) |
| Windows | x86_64 |

If no pre-built binary is available for your platform, the installer falls back to building from source automatically.

If OpenAI changes the footer implementation in a newer release, the patch may need to be refreshed.

## Cache Locations

Linux/macOS defaults:

```text
~/.codex-last-prompt-footer/openai-codex
~/.codex-last-prompt-footer/dist/posix/codex
```

Optional environment variables:

- `CODEX_TAG`
- `PATCH_FILE`
- `STATE_DIR`
- `SOURCE_DIR`
- `OUTPUT_DIR`
- `RELEASE_REPOSITORY`
- `RELEASE_TAG`
- `SKIP_PREBUILT_DOWNLOAD=1`
- `AUTO_INSTALL_DEPS=1`

## Faster Installs For Other People

For public distribution, the reasonable path is to publish prebuilt binaries in GitHub Releases and let the installer fall back to Rust only when needed.

The installer looks for asset names like these:

```text
codex-last-prompt-footer-0.114.0-linux-x86_64.tar.gz
codex-last-prompt-footer-0.114.0-macos-x86_64.tar.gz
codex-last-prompt-footer-0.114.0-macos-aarch64.tar.gz
codex-last-prompt-footer-0.114.0-windows-x86_64.zip
```

By default it downloads from:

```text
https://github.com/bic98/codex-last-prompt-footer/releases/download/v0.114.0/
```

If you target a different upstream Codex tag, add a matching patch file in `patches/`:

```text
patches/codex-v0.115.0-last-prompt-footer.patch
```

Or override it directly:

```bash
PATCH_FILE=/absolute/path/to/codex-v0.115.0-last-prompt-footer.patch npx codex-last-prompt-footer build
```

## Manual Patch Workflow

```bash
git clone https://github.com/openai/codex.git
cd codex
git checkout rust-v0.114.0
git apply /path/to/codex-v0.114.0-last-prompt-footer.patch
cd codex-rs
cargo +stable build -p codex-cli --release
```

## Search Terms

People usually find this repository while searching for things like:

- `openai codex cli footer`
- `codex cli prompt history`
- `codex latest prompt in status line`
- `codex footer patch`
- `codex cli npx install`
- `openssl-sys codex cli`
- `libssl-dev codex cli`
- `pkg-config codex cli`
