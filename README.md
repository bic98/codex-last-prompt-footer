# Codex Last Prompt Footer

Show your latest prompt directly in the OpenAI Codex CLI footer and status line.

`Codex Last Prompt Footer` is a patch and installer for `OpenAI Codex CLI` that adds a `Q: ...` preview of your latest submitted prompt to the bottom footer, next to status items like model, reasoning level, `5h` usage, and `weekly` usage.

It is intended for developers looking for an easy way to add `latest prompt`, `prompt history preview`, `footer text`, or `status line customization` to the official OpenAI Codex CLI on Windows, Linux, and macOS.

This repository is for people searching for:

- `OpenAI Codex CLI footer`
- `Codex CLI prompt history`
- `Codex latest prompt in status line`
- `Codex status line patch`
- `Codex CLI Windows installer`
- `Codex CLI Linux patch`
- `Codex CLI macOS patch`

Korean summary: `OpenAI Codex CLI` 하단 footer/status line 에 마지막 질문을 `Q: ...` 형태로 보여주는 패치와 설치 스크립트입니다. Windows PowerShell 뿐 아니라 Linux/macOS 같은 POSIX shell 환경도 같이 지원합니다.

Example:

```text
gpt-5.4 · gpt-5.4 high · 5h 99% · weekly 68% · Q: fix the footer layout bug
```

## Why This Exists

OpenAI Codex CLI supports session resume, but it does not clearly surface the latest prompt in the live footer. This project adds a small but useful quality-of-life feature:

- shows the latest submitted prompt in the Codex CLI footer
- keeps the existing Codex status line behavior
- normalizes multiline prompts into a single-line preview
- truncates long prompts so terminal layout stays stable
- supports Windows and POSIX-style environments
- installs as `codex`, so you keep using your normal command

## Features

- Latest prompt preview in the footer as `Q: ...`
- Patch file for the official `openai/codex` source
- Windows installer and restore scripts
- Linux/macOS installer and restore scripts
- Local build scripts for patched Codex binaries
- Backups of original launchers before replacement

## Supported Version

This repository currently targets:

- `@openai/codex` `0.114.0`
- source tag `rust-v0.114.0`

If OpenAI changes the footer implementation or internal struct layout in a future release, the patch may need to be refreshed.

## Quick Install

### Windows PowerShell

```powershell
git clone https://github.com/bic98/codex-last-prompt-footer.git
cd codex-last-prompt-footer
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

### Linux / macOS

```bash
git clone https://github.com/bic98/codex-last-prompt-footer.git
cd codex-last-prompt-footer
bash ./scripts/install.sh
```

## What The Installer Does

The installer will:

1. locate your current `codex` launcher
2. install Rust automatically if it is missing
3. clone the official `openai/codex` source for `rust-v0.114.0`
4. apply the patch from this repository
5. build a patched `codex` binary
6. back up your original launchers
7. repoint `codex` to the patched binary

## Requirements

### Windows

- Windows
- PowerShell 5.1 or PowerShell 7+
- `git`
- an existing `codex` command already installed
- internet access for downloading the official Codex source and Rust toolchain

### Linux / macOS

- `bash`
- `git`
- `curl`
- an existing `codex` command already installed
- internet access for downloading the official Codex source and Rust toolchain

## Usage

After installation, run:

```bash
codex
```

Submit prompts normally. The footer will append a `Q: ...` preview based on your latest submitted prompt.

## Uninstall / Restore Original Codex

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore.ps1
```

### Linux / macOS

```bash
bash ./scripts/restore.sh
```

This restores the original OpenAI Codex launchers from backup and removes the custom binary folder.

## Build Without Installing

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Output:

```text
dist/windows/codex.exe
```

### Linux / macOS

```bash
bash ./scripts/build.sh
```

Output:

```text
dist/posix/codex
```

## Manual Patch Workflow

If you want to apply the patch manually:

```bash
git clone https://github.com/openai/codex.git
cd codex
git checkout rust-v0.114.0
git apply /path/to/codex-v0.114.0-last-prompt-footer.patch
cd codex-rs
cargo +stable build -p codex-cli --release
```

## Repository Layout

```text
patches/
  codex-v0.114.0-last-prompt-footer.patch
scripts/
  build.ps1
  build.sh
  install.ps1
  install.sh
  restore.ps1
  restore.sh
README.md
GITHUB_METADATA.md
```

## Search Terms

Useful search phrases for GitHub search and AI indexing:

- `codex cli prompt history`
- `openai codex footer`
- `codex last prompt`
- `codex status line prompt`
- `codex cli windows installer`
- `codex cli linux installer`
- `codex cli macos installer`
- `openai codex prompt preview`
- `codex footer patch`
- `codex cli latest prompt`
- `how to show latest question in codex cli`
- `openai codex cli prompt shown in footer`

## Notes

- This repository does not replace the official Codex source tree. It applies a focused patch on top of the official release tag.
- The installer rewires the existing launcher to a patched native binary.
- Original launchers are backed up with the `.openai-backup` suffix before replacement.
- On Linux/macOS, if your Codex launcher directory is not writable, run the installer with the permissions required for your install method or copy the built binary manually.

## SEO / Discoverability Notes

To make this repository easier to discover on GitHub and by AI tools, the README intentionally includes natural references to:

- OpenAI Codex CLI
- Codex CLI footer
- Codex CLI prompt history
- Codex status line patch
- latest prompt in footer
- Windows, Linux, and macOS Codex installation
- OpenAI Codex CLI latest prompt
- OpenAI Codex CLI footer customization

