//! Mapping from parsed CLI arguments to an initial process title.
//!
//! This logic depends on the clap `Args`/`Command` types defined in `cli`, so
//! it lives in the CLI layer. The low-level title-setting primitives it uses
//! (`compact_process_title`, `session_name`, `set_title`) live in the
//! `process_title` core module.

use crate::cli::args::{AmbientCommand, Args, Command};
use crate::process_title::{compact_process_title, session_name, set_title};

pub(crate) fn initial_title(args: &Args) -> String {
    match &args.command {
        Some(Command::Serve { .. }) => "pryx:server".to_string(),
        Some(Command::Acp) => "pryx acp".to_string(),
        Some(Command::Server { .. }) => "pryx server".to_string(),
        Some(Command::Connect) => "pryx:client".to_string(),
        #[cfg(unix)]
        Some(Command::ApiBridge { .. }) => "pryx api-bridge".to_string(),
        Some(Command::Run { .. }) => "pryx run".to_string(),
        Some(Command::Login { .. }) => "pryx login".to_string(),
        Some(Command::Account { .. }) => "pryx account".to_string(),
        Some(Command::Repl) => "pryx repl".to_string(),
        Some(Command::Update) => "pryx update".to_string(),
        Some(Command::Version { .. }) => "pryx version".to_string(),
        Some(Command::Usage { .. }) => "pryx usage".to_string(),
        Some(Command::Telemetry(_)) => "pryx telemetry".to_string(),
        Some(Command::SelfDev { .. }) => "pryx:selfdev".to_string(),
        Some(Command::Debug { .. }) => "pryx debug".to_string(),
        Some(Command::Auth(_)) => "pryx auth".to_string(),
        Some(Command::Provider(_)) => "pryx provider".to_string(),
        Some(Command::Memory(_)) => "pryx memory".to_string(),
        Some(Command::Session(_)) => "pryx session".to_string(),
        Some(Command::Ambient(subcommand)) => match subcommand {
            AmbientCommand::RunVisible => "pryx ambient visible".to_string(),
            _ => "pryx ambient".to_string(),
        },
        Some(Command::Cloud(_)) => "pryx cloud".to_string(),
        Some(Command::Pair { .. }) => "pryx pair".to_string(),
        Some(Command::Permissions) => "pryx permissions".to_string(),
        Some(Command::Transcript { .. }) => "pryx transcript".to_string(),
        Some(Command::Dictate { .. }) => "pryx dictate".to_string(),
        Some(Command::SetupHotkey {
            listen_macos_hotkey,
            notify_cli_launch,
            listen_windows_hotkey,
            uninstall,
        }) => {
            if *listen_macos_hotkey || *listen_windows_hotkey {
                "pryx hotkey listener".to_string()
            } else if notify_cli_launch.is_some() {
                "pryx shortcut reminder".to_string()
            } else if *uninstall {
                "pryx hotkey uninstall".to_string()
            } else {
                "pryx hotkey setup".to_string()
            }
        }
        Some(Command::Browser { .. }) => "pryx browser".to_string(),
        Some(Command::Replay { .. }) => "pryx replay".to_string(),
        Some(Command::Model(_)) => "pryx model".to_string(),
        Some(Command::ProviderTestCoverage { .. }) => "pryx provider-test-coverage".to_string(),
        Some(Command::ProviderDoctor { .. }) => "pryx provider-doctor".to_string(),
        Some(Command::AuthTest { .. }) => "pryx auth-test".to_string(),
        Some(Command::Restart { .. }) => "pryx restart".to_string(),
        Some(Command::Menubar { .. }) => "pryx menubar".to_string(),
        Some(Command::SetupLauncher) => "pryx setup-launcher".to_string(),
        None => {
            if let Some(resume) = args.resume.as_deref().filter(|resume| !resume.is_empty()) {
                let prefix = if crate::cli::selfdev::client_selfdev_requested() {
                    "pryx:d:"
                } else {
                    "pryx:c:"
                };
                compact_process_title(prefix, Some(&session_name(resume)))
            } else if crate::cli::selfdev::client_selfdev_requested() {
                "pryx:selfdev".to_string()
            } else {
                "pryx:client".to_string()
            }
        }
    }
}

pub(crate) fn set_initial_title(args: &Args) {
    set_title(initial_title(args));
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::lock_test_env;
    use clap::Parser;

    const SELFDEV_ENV: &str = pryx_selfdev_types::CLIENT_SELFDEV_ENV;

    fn with_selfdev_env_removed<T>(f: impl FnOnce() -> T) -> T {
        let _guard = lock_test_env();
        let previous = std::env::var_os(SELFDEV_ENV);
        crate::env::remove_var(SELFDEV_ENV);
        let result = f();
        if let Some(value) = previous {
            crate::env::set_var(SELFDEV_ENV, value);
        }
        result
    }

    #[test]
    fn initial_title_labels_server() {
        with_selfdev_env_removed(|| {
            let args = Args::parse_from(["pryx", "serve"]);
            assert_eq!(initial_title(&args), "pryx:server");
        });
    }

    #[test]
    fn initial_title_labels_resume_client_with_short_name() {
        with_selfdev_env_removed(|| {
            let args = Args::parse_from(["pryx", "--resume", "session_fox_123"]);
            assert_eq!(initial_title(&args), "pryx:c:fox");
        });
    }

    #[test]
    fn initial_title_labels_selfdev_command() {
        with_selfdev_env_removed(|| {
            let args = Args::parse_from(["pryx", "self-dev"]);
            assert_eq!(initial_title(&args), "pryx:selfdev");
        });
    }

    #[test]
    fn initial_title_labels_windows_hotkey_listener() {
        let args = Args::parse_from(["pryx", "setup-hotkey", "--listen-windows-hotkey"]);
        assert_eq!(initial_title(&args), "pryx hotkey listener");
    }

    #[test]
    fn initial_title_labels_hotkey_uninstall() {
        let args = Args::parse_from(["pryx", "setup-hotkey", "--uninstall"]);
        assert_eq!(initial_title(&args), "pryx hotkey uninstall");
    }
}
