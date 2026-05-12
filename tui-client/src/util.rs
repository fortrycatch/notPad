use std::path::{Path, PathBuf};

use crate::config::AppConfig;

/// Render a byte count using 1024-based units (B / KB / MB / GB / TB).
pub fn human_bytes(bytes: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    let mut size = bytes as f64;
    let mut i = 0;
    while size >= 1024.0 && i + 1 < UNITS.len() {
        size /= 1024.0;
        i += 1;
    }
    if i == 0 {
        format!("{} {}", bytes, UNITS[0])
    } else {
        format!("{:.1} {}", size, UNITS[i])
    }
}

/// Per-second transfer rate, e.g. `1.2 MB/s` or `<1 KB/s` when stalled.
pub fn speed_fmt(bps: u64) -> String {
    if bps == 0 {
        "0 B/s".to_string()
    } else if bps < 1024 {
        format!("{bps} B/s")
    } else {
        format!("{}/s", human_bytes(bps))
    }
}

/// Human-friendly time-remaining estimate. Falls back to `?` when totals
/// or speed are unknown.
pub fn human_eta_secs(secs: u64) -> String {
    if secs == 0 {
        return "<1s".to_string();
    }
    let h = secs / 3600;
    let m = (secs % 3600) / 60;
    let s = secs % 60;
    if h > 0 {
        format!("{h}h{m:02}m")
    } else if m > 0 {
        format!("{m}m{s:02}s")
    } else {
        format!("{s}s")
    }
}

/// Resolve a free path inside `dir` for `name`. If `dir/name` already
/// exists, append ` (1)`, ` (2)`, … before the extension until a free
/// slot is found. Stops at 1000 attempts to avoid spinning forever.
pub fn unique_path(dir: &Path, name: &str) -> PathBuf {
    let initial = dir.join(name);
    if !initial.exists() {
        return initial;
    }
    let (stem, ext) = split_name(name);
    for i in 1..1000 {
        let candidate = if ext.is_empty() {
            format!("{stem} ({i})")
        } else {
            format!("{stem} ({i}).{ext}")
        };
        let p = dir.join(candidate);
        if !p.exists() {
            return p;
        }
    }
    initial
}

fn split_name(name: &str) -> (&str, &str) {
    if let Some(idx) = name.rfind('.')
        && idx > 0
        && idx + 1 < name.len()
    {
        return (&name[..idx], &name[idx + 1..]);
    }
    (name, "")
}

/// Pick the directory new downloads should land in by default. Order:
/// 1. User-configured `download_dir` (if set and not blank).
/// 2. OS Downloads folder via `directories::UserDirs`.
/// 3. Current working directory.
pub fn resolve_default_download_dir(cfg: &AppConfig) -> PathBuf {
    if let Some(s) = cfg.download_dir.as_deref().map(str::trim)
        && !s.is_empty()
    {
        return PathBuf::from(s);
    }
    if let Some(d) =
        directories::UserDirs::new().and_then(|u| u.download_dir().map(|p| p.to_path_buf()))
    {
        return d;
    }
    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

/// Spawn the platform-native file manager focused on `path`. We only fire
/// and forget — never block the tokio runtime waiting for the explorer to
/// exit.
pub fn reveal_in_explorer(path: &Path) -> std::io::Result<()> {
    use std::process::Command;
    #[cfg(target_os = "windows")]
    {
        // `explorer /select,<path>` highlights the file in the parent
        // folder. The comma must be glued to /select; pass as one arg.
        let mut arg = std::ffi::OsString::from("/select,");
        arg.push(path.as_os_str());
        Command::new("explorer").arg(arg).spawn().map(|_| ())
    }
    #[cfg(target_os = "macos")]
    {
        Command::new("open").arg("-R").arg(path).spawn().map(|_| ())
    }
    #[cfg(all(not(target_os = "windows"), not(target_os = "macos")))]
    {
        let target = path.parent().unwrap_or(path);
        Command::new("xdg-open").arg(target).spawn().map(|_| ())
    }
}

/// Copy plain text into system clipboard.
pub fn copy_to_clipboard(text: &str) -> anyhow::Result<()> {
    let mut clipboard = arboard::Clipboard::new()?;
    clipboard.set_text(text.to_string())?;
    Ok(())
}
