use std::env;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

use tempfile::TempDir;

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

struct EmbeddedFile {
    relative_path: &'static str,
    contents: &'static str,
    executable: bool,
}

const FILES: &[EmbeddedFile] = &[
    EmbeddedFile {
        relative_path: "scripts/build.sh",
        contents: include_str!("../scripts/build.sh"),
        executable: true,
    },
    EmbeddedFile {
        relative_path: "scripts/install.sh",
        contents: include_str!("../scripts/install.sh"),
        executable: true,
    },
    EmbeddedFile {
        relative_path: "scripts/restore.sh",
        contents: include_str!("../scripts/restore.sh"),
        executable: true,
    },
    EmbeddedFile {
        relative_path: "scripts/control.sh",
        contents: include_str!("../scripts/control.sh"),
        executable: true,
    },
    EmbeddedFile {
        relative_path: "scripts/build.ps1",
        contents: include_str!("../scripts/build.ps1"),
        executable: false,
    },
    EmbeddedFile {
        relative_path: "scripts/install.ps1",
        contents: include_str!("../scripts/install.ps1"),
        executable: false,
    },
    EmbeddedFile {
        relative_path: "scripts/restore.ps1",
        contents: include_str!("../scripts/restore.ps1"),
        executable: false,
    },
    EmbeddedFile {
        relative_path: "scripts/control.ps1",
        contents: include_str!("../scripts/control.ps1"),
        executable: false,
    },
    EmbeddedFile {
        relative_path: "patches/codex-v0.114.0-last-prompt-footer.patch",
        contents: include_str!("../patches/codex-v0.114.0-last-prompt-footer.patch"),
        executable: false,
    },
];

fn print_help() {
    println!(
        "codex-last-prompt-footer

Usage:
  codex-last-prompt-footer
  codex-last-prompt-footer --install-deps
  codex-last-prompt-footer install
  codex-last-prompt-footer build
  codex-last-prompt-footer restore
  codex-last-prompt-footer enable
  codex-last-prompt-footer disable
  codex-last-prompt-footer status

Commands:
  install   Build and install the patched Codex CLI footer shim
  build     Build the patched Codex binary only
  restore   Remove the persistent Codex shim
  enable    Enable the footer preview in the installed shim
  disable   Disable the footer preview in the installed shim
  status    Show whether the footer preview is enabled
  help      Show this help text

Options:
  --install-deps  Attempt to install missing native build dependencies automatically

Environment:
  CODEX_TAG          Override the OpenAI Codex source tag (default: rust-v0.114.0)
  STATE_DIR          Override the cache root (default: ~/.codex-last-prompt-footer)
  SOURCE_DIR         Override the cached source directory for openai/codex
  OUTPUT_DIR         Override the build output directory
  PATCH_FILE         Override the patch file path
  RELEASE_REPOSITORY Override the GitHub repository used for prebuilt downloads
  RELEASE_TAG        Override the GitHub release tag used for prebuilt downloads
  AUTO_INSTALL_DEPS=1 Same as passing --install-deps"
    );
}

fn parse_args() -> Result<(String, Vec<String>), String> {
    let args: Vec<String> = env::args().skip(1).collect();
    let has_explicit_command = args.first().is_some_and(|arg| !arg.starts_with('-'));
    let command = if has_explicit_command {
        args[0].clone()
    } else {
        "install".to_string()
    };
    let passthrough = if has_explicit_command {
        args[1..].to_vec()
    } else {
        args.clone()
    };

    if args.iter().any(|arg| arg == "--help" || arg == "-h") || command == "help" {
        print_help();
        return Err(String::new());
    }

    match command.as_str() {
        "install" | "build" | "restore" | "enable" | "disable" | "status" => {
            Ok((command, passthrough))
        }
        _ => Err(format!("Unknown command: {command}")),
    }
}

fn write_bundle(root: &Path) -> io::Result<()> {
    for file in FILES {
        let path = root.join(file.relative_path);
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&path, file.contents)?;

        #[cfg(unix)]
        if file.executable {
            let mut permissions = fs::metadata(&path)?.permissions();
            permissions.set_mode(0o755);
            fs::set_permissions(&path, permissions)?;
        }
    }
    Ok(())
}

fn create_bundle() -> io::Result<TempDir> {
    let temp_dir = TempDir::new()?;
    write_bundle(temp_dir.path())?;
    Ok(temp_dir)
}

#[cfg(target_os = "windows")]
fn script_name(command: &str) -> &'static str {
    match command {
        "install" => "scripts/install.ps1",
        "build" => "scripts/build.ps1",
        "restore" => "scripts/restore.ps1",
        "enable" | "disable" | "status" => "scripts/control.ps1",
        _ => unreachable!(),
    }
}

#[cfg(not(target_os = "windows"))]
fn script_name(command: &str) -> &'static str {
    match command {
        "install" => "scripts/install.sh",
        "build" => "scripts/build.sh",
        "restore" => "scripts/restore.sh",
        "enable" | "disable" | "status" => "scripts/control.sh",
        _ => unreachable!(),
    }
}

fn run_command(root: &Path, command: &str, passthrough: &[String]) -> io::Result<i32> {
    let script_path: PathBuf = root.join(script_name(command));
    let script_args: Vec<String> = match command {
        "enable" | "disable" | "status" => {
            let mut args = vec![command.to_string()];
            args.extend_from_slice(passthrough);
            args
        }
        _ => passthrough.to_vec(),
    };

    #[cfg(target_os = "windows")]
    let status = {
        let mut child = Command::new("powershell");
        child
            .arg("-ExecutionPolicy")
            .arg("Bypass")
            .arg("-File")
            .arg(&script_path)
            .args(&script_args)
            .current_dir(root);
        child.status()?
    };

    #[cfg(not(target_os = "windows"))]
    let status = {
        let mut child = Command::new("bash");
        child.arg(&script_path).args(&script_args).current_dir(root);
        child.status()?
    };

    Ok(status.code().unwrap_or(1))
}

fn main() -> ExitCode {
    let (command, passthrough) = match parse_args() {
        Ok(parsed) => parsed,
        Err(message) if message.is_empty() => return ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{message}");
            print_help();
            return ExitCode::from(1);
        }
    };

    let bundle = match create_bundle() {
        Ok(bundle) => bundle,
        Err(error) => {
            eprintln!("Failed to prepare installer bundle: {error}");
            return ExitCode::from(1);
        }
    };

    match run_command(bundle.path(), &command, &passthrough) {
        Ok(code) => ExitCode::from(code as u8),
        Err(error) => {
            eprintln!("Failed to launch embedded script: {error}");
            ExitCode::from(1)
        }
    }
}
