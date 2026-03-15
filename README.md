# Codex Last Prompt Footer

[![npm version](https://img.shields.io/npm/v/codex-last-prompt-footer)](https://www.npmjs.com/package/codex-last-prompt-footer)
[![npm downloads](https://img.shields.io/npm/dm/codex-last-prompt-footer)](https://www.npmjs.com/package/codex-last-prompt-footer)
[![GitHub stars](https://img.shields.io/github/stars/bic98/codex-last-prompt-footer?style=social)](https://github.com/bic98/codex-last-prompt-footer)
[![license](https://img.shields.io/github/license/bic98/codex-last-prompt-footer)](./LICENSE)

Make OpenAI Codex CLI show your latest prompt in the footer.

Instead of only seeing model and usage stats, you also see a live `Q: ...` preview of what you just asked.

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
- Original launchers are backed up before replacement.
- It targets the official `openai/codex` Rust release tag.

## Install

### Linux / macOS

```bash
npx codex-last-prompt-footer
```

Alternative sources:

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

## Linux / macOS Troubleshooting

Codex CLI is a Rust binary. On Linux and sometimes macOS, the build may fail if OpenSSL development headers or `pkg-config` are missing.

Ubuntu / Debian:

```bash
sudo apt-get update && sudo apt-get install -y libssl-dev pkg-config build-essential
```

Fedora / RHEL:

```bash
sudo dnf install -y openssl-devel pkgconf-pkg-config gcc gcc-c++ make
```

Arch Linux:

```bash
sudo pacman -S --needed openssl pkgconf base-devel
```

macOS:

```bash
brew install openssl@3 pkg-config
```

If you hit `openssl-sys`, `pkg-config`, or `OpenSSL development headers` errors, install the packages above and rerun the command.

## Commands

Restore the original Codex launcher:

```bash
npx codex-last-prompt-footer restore
```

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

1. Finds your existing `codex` launcher.
2. Installs Rust automatically if needed.
3. Checks native build dependencies on Linux/macOS.
4. Clones `openai/codex` at `rust-v0.114.0`.
5. Applies the footer patch.
6. Builds a patched `codex` binary.
7. Backs up your original launcher.
8. Repoints `codex` to the patched binary.

## Compatibility

Current target:

- `@openai/codex` `0.114.0`
- source tag `rust-v0.114.0`

If OpenAI changes the footer implementation in a newer release, the patch may need to be refreshed.

## Cache Locations

Linux/macOS defaults:

```text
~/.codex-last-prompt-footer/openai-codex
~/.codex-last-prompt-footer/dist/posix/codex
```

Optional environment variables:

- `CODEX_TAG`
- `STATE_DIR`
- `SOURCE_DIR`
- `OUTPUT_DIR`

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
