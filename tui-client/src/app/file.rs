use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use crossterm::event::{KeyCode, KeyEvent};
use futures::StreamExt;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::mpsc;

use super::{App, Modal, Msg};
use crate::api::dto::{DriveFile, DriveFolder};
use crate::util::{human_bytes, unique_path};

#[derive(Debug, Default, Clone)]
pub struct DriveBreadcrumb {
    pub id: Option<String>,
    pub name: String,
}

#[derive(Debug, Clone)]
pub enum DownloadStatus {
    Active,
    Completed,
    Failed(String),
    Cancelled,
}

/// One download. Lives on `FileState.downloads` for the lifetime of the
/// session; cleared explicitly from the download manager (`c`).
pub struct DownloadTask {
    pub id: u64,
    pub name: String,
    pub save_path: PathBuf,
    pub total: Option<u64>,
    pub downloaded: u64,
    pub status: DownloadStatus,
    /// Smoothed bytes-per-second, updated every chunk via EMA.
    pub speed_bps: u64,
    /// Worker checks this between chunks and bails out when set.
    pub cancel: Arc<AtomicBool>,
}

#[derive(Debug, Clone)]
pub enum UploadStatus {
    Active,
    Completed,
    Failed(String),
    Cancelled,
}

/// One upload. Mirrors `DownloadTask` so the transfer manager can render
/// the two side by side. `total` is the local file size sampled before the
/// PUT begins, so the gauge can show a real denominator from frame 1.
pub struct UploadTask {
    pub id: u64,
    pub name: String,
    pub local_path: PathBuf,
    pub total: u64,
    pub uploaded: u64,
    pub status: UploadStatus,
    pub speed_bps: u64,
    pub cancel: Arc<AtomicBool>,
}

#[derive(Default)]
pub struct FileState {
    pub current_folder: Option<String>,
    pub breadcrumbs: Vec<DriveBreadcrumb>,
    pub folders: Vec<DriveFolder>,
    pub files: Vec<DriveFile>,
    pub cursor: usize, // index across folders+files
    pub search: String,
    pub search_all: bool,
    pub loading: bool,
    pub last_link: Option<String>,
    pub downloads: Vec<DownloadTask>,
    pub next_download_id: u64,
    pub uploads: Vec<UploadTask>,
    pub next_upload_id: u64,
    pub pending_upload_path: Option<PathBuf>,
}

/// View into one transfer for the unified manager + dashboard. Borrowed
/// so the modal can iterate without cloning task buffers each frame.
pub enum TransferRef<'a> {
    Upload(&'a UploadTask),
    Download(&'a DownloadTask),
}

impl App {
    pub(super) fn fetch_drive(&mut self, folder_id: Option<String>) {
        self.file.loading = true;
        let folder_clone = folder_id.clone();
        let search = self.file.search.trim().to_string();
        let search_scope = if self.file.search_all {
            "all".to_string()
        } else {
            "current".to_string()
        };
        self.spawn(move |api| async move {
            let res = api
                .drive_list(folder_clone, 0, "time_desc", &search, &search_scope)
                .await;
            Box::new(move |app: &mut App| {
                app.file.loading = false;
                match res {
                    Ok(r) => {
                        app.file.current_folder = folder_id;
                        let mut bcs: Vec<DriveBreadcrumb> = vec![DriveBreadcrumb {
                            id: None,
                            name: "根目录".to_string(),
                        }];
                        for f in &r.breadcrumbs {
                            bcs.push(DriveBreadcrumb {
                                id: Some(f.id.clone()),
                                name: f.name.clone(),
                            });
                        }
                        app.file.breadcrumbs = bcs;
                        app.file.folders = r.folders;
                        app.file.files = r.files;
                        app.file.cursor = 0;
                    }
                    Err(e) => app.handle_api_err("网盘", e),
                }
            })
        });
    }

    pub(super) fn handle_file_key(&mut self, key: KeyEvent) {
        if self.file.pending_upload_path.is_some() {
            self.handle_upload_target_key(key);
            return;
        }

        let total = self.file.folders.len() + self.file.files.len();
        match key.code {
            KeyCode::Char('q') => self.should_quit = true,
            KeyCode::Char('r') => self.fetch_drive(self.file.current_folder.clone()),
            KeyCode::Char('/') => self.open_drive_search_modal(),
            KeyCode::Char('c') => {
                if !self.file.search.is_empty() {
                    self.file.search.clear();
                    self.fetch_drive(self.file.current_folder.clone());
                    self.set_status("已清除网盘搜索", false);
                }
            }
            KeyCode::Char('s') => {
                self.file.search_all = !self.file.search_all;
                self.fetch_drive(self.file.current_folder.clone());
                let label = if self.file.search_all {
                    "所有文件"
                } else {
                    "当前目录"
                };
                self.set_status(format!("网盘搜索范围: {label}"), false);
            }
            KeyCode::Up | KeyCode::Char('k') => {
                if self.file.cursor > 0 {
                    self.file.cursor -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.file.cursor + 1 < total {
                    self.file.cursor += 1;
                }
            }
            KeyCode::Backspace => {
                if self.file.breadcrumbs.len() >= 2 {
                    let parent = self
                        .file
                        .breadcrumbs
                        .get(self.file.breadcrumbs.len() - 2)
                        .and_then(|b| b.id.clone());
                    self.fetch_drive(parent);
                }
            }
            KeyCode::Enter => {
                if self.file.cursor < self.file.folders.len() {
                    let folder = self.file.folders[self.file.cursor].clone();
                    self.fetch_drive(Some(folder.id));
                } else {
                    let i = self.file.cursor - self.file.folders.len();
                    if let Some(file) = self.file.files.get(i).cloned() {
                        self.open_download_dest_modal(file);
                    }
                }
            }
            KeyCode::Char('y') => {
                if self.file.cursor >= self.file.folders.len() {
                    let i = self.file.cursor - self.file.folders.len();
                    if let Some(file) = self.file.files.get(i) {
                        let url = file
                            .public_url
                            .clone()
                            .unwrap_or_else(|| file.oss_key.clone());
                        self.file.last_link = Some(url.clone());
                        self.set_status(format!("链接: {url}"), false);
                    }
                }
            }
            KeyCode::Char('d') => {
                if self.file.cursor >= self.file.folders.len() {
                    let i = self.file.cursor - self.file.folders.len();
                    if let Some(file) = self.file.files.get(i).cloned() {
                        self.open_download_dest_modal(file);
                    }
                }
            }
            KeyCode::Char('u') => self.open_upload_input_modal(),
            KeyCode::Char('e') | KeyCode::Char('R') => {
                if self.file.cursor < self.file.folders.len() {
                    let folder = self.file.folders[self.file.cursor].clone();
                    let id = folder.id.clone();
                    let cur_folder = self.file.current_folder.clone();
                    self.modal = Some(Modal::Input {
                        title: "重命名文件夹".into(),
                        prompt: "新名称".into(),
                        value: folder.name,
                        on_submit: Box::new(move |app: &mut App, val: String| {
                            if val.trim().is_empty() {
                                return;
                            }
                            let cf = cur_folder.clone();
                            app.spawn(move |api| async move {
                                let r = api.rename_folder(&id, val.trim()).await;
                                Box::new(move |app: &mut App| match r {
                                    Ok(_) => {
                                        app.set_status("已重命名", false);
                                        app.fetch_drive(cf);
                                    }
                                    Err(e) => app.handle_api_err("重命名文件夹", e),
                                })
                            });
                        }),
                    });
                } else {
                    let i = self.file.cursor - self.file.folders.len();
                    if let Some(file) = self.file.files.get(i).cloned() {
                        let id = file.id;
                        let cur_folder = self.file.current_folder.clone();
                        self.modal = Some(Modal::Input {
                            title: "重命名文件".into(),
                            prompt: "新名称".into(),
                            value: file.name,
                            on_submit: Box::new(move |app: &mut App, val: String| {
                                if val.trim().is_empty() {
                                    return;
                                }
                                let cf = cur_folder.clone();
                                app.spawn(move |api| async move {
                                    let r = api.rename_file(id, val.trim()).await;
                                    Box::new(move |app: &mut App| match r {
                                        Ok(_) => {
                                            app.set_status("已重命名", false);
                                            app.fetch_drive(cf);
                                        }
                                        Err(e) => app.handle_api_err("重命名文件", e),
                                    })
                                });
                            }),
                        });
                    }
                }
            }
            _ => {}
        }
    }

    fn open_drive_search_modal(&mut self) {
        let cur = self.file.search.clone();
        self.modal = Some(Modal::Input {
            title: "搜索网盘".into(),
            prompt: "关键词（留空清除）".into(),
            value: cur,
            on_submit: Box::new(|app: &mut App, val: String| {
                app.file.search = val.trim().to_string();
                app.fetch_drive(app.file.current_folder.clone());
            }),
        });
    }

    /// Pop the destination picker for `file`. The picker offers two
    /// directories — the user-configured download dir (or OS Downloads
    /// fallback) and the current working directory — both are resolved
    /// up-front so the modal can show their absolute paths.
    fn open_download_dest_modal(&mut self, file: DriveFile) {
        let cfg_path = if self
            .config
            .download_dir
            .as_deref()
            .map(|s| !s.trim().is_empty())
            .unwrap_or(false)
        {
            Some(PathBuf::from(
                self.config.download_dir.as_deref().unwrap().trim(),
            ))
        } else {
            directories::UserDirs::new().and_then(|u| u.download_dir().map(|p| p.to_path_buf()))
        };
        let cwd_path = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        self.modal = Some(Modal::DownloadDest {
            file,
            cfg_path,
            cwd_path,
        });
    }

    fn open_upload_input_modal(&mut self) {
        self.modal = Some(Modal::Input {
            title: "上传文件".into(),
            prompt: "输入本地文件路径（可拖拽路径到终端后粘贴）".into(),
            value: String::new(),
            on_submit: Box::new(|app: &mut App, value: String| {
                app.handle_upload_input_submit(value);
            }),
        });
    }

    pub(super) fn handle_upload_input_submit(&mut self, value: String) {
        let Some(canonical) = self.resolve_upload_input(value) else {
            return;
        };
        let file_name = canonical
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("(unknown)")
            .to_string();
        let file_size = std::fs::metadata(&canonical).map(|m| m.len()).unwrap_or(0);
        let target_folder = self
            .file
            .breadcrumbs
            .last()
            .map(|b| b.name.clone())
            .unwrap_or_else(|| "根目录".to_string());
        let prompt = format!(
            "确认上传?\n\n文件: {file_name}\n路径: {}\n大小: {}\n目标目录: {target_folder}",
            canonical.display(),
            human_bytes(file_size)
        );
        self.modal = Some(Modal::Confirm {
            prompt,
            on_yes: Box::new(move |app: &mut App| {
                app.start_upload_local_file(canonical.clone());
            }),
        });
    }

    pub(super) fn begin_startup_upload_target_selection(&mut self, value: String) {
        let Some(path) = self.resolve_upload_input(value) else {
            return;
        };
        let name = path
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("(unknown)")
            .to_string();
        self.file.pending_upload_path = Some(path);
        self.file.current_folder = None;
        self.fetch_drive(None);
        self.set_status(
            format!("选择 {name} 的上传目录：Enter 进入文件夹，Backspace 返回，u/Space 上传到当前目录，Esc 取消"),
            false,
        );
    }

    fn handle_upload_target_key(&mut self, key: KeyEvent) {
        let total = self.file.folders.len() + self.file.files.len();
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') => {
                self.file.pending_upload_path = None;
                self.set_status("已取消命令行上传", false);
            }
            KeyCode::Char('r') => self.fetch_drive(self.file.current_folder.clone()),
            KeyCode::Up | KeyCode::Char('k') => {
                if self.file.cursor > 0 {
                    self.file.cursor -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.file.cursor + 1 < total {
                    self.file.cursor += 1;
                }
            }
            KeyCode::Backspace => {
                if self.file.breadcrumbs.len() >= 2 {
                    let parent = self
                        .file
                        .breadcrumbs
                        .get(self.file.breadcrumbs.len() - 2)
                        .and_then(|b| b.id.clone());
                    self.fetch_drive(parent);
                }
            }
            KeyCode::Enter => {
                if self.file.cursor < self.file.folders.len() {
                    let folder = self.file.folders[self.file.cursor].clone();
                    self.fetch_drive(Some(folder.id));
                }
            }
            KeyCode::Char('u') | KeyCode::Char(' ') => {
                self.confirm_pending_upload_to_current_folder()
            }
            _ => {}
        }
    }

    fn confirm_pending_upload_to_current_folder(&mut self) {
        let Some(canonical) = self.file.pending_upload_path.clone() else {
            return;
        };
        let file_name = canonical
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("(unknown)")
            .to_string();
        let file_size = std::fs::metadata(&canonical).map(|m| m.len()).unwrap_or(0);
        let target_folder = self
            .file
            .breadcrumbs
            .last()
            .map(|b| b.name.clone())
            .unwrap_or_else(|| "根目录".to_string());
        let prompt = format!(
            "确认上传到当前目录?\n\n文件: {file_name}\n路径: {}\n大小: {}\n目标目录: {target_folder}",
            canonical.display(),
            human_bytes(file_size)
        );
        self.modal = Some(Modal::Confirm {
            prompt,
            on_yes: Box::new(move |app: &mut App| {
                app.file.pending_upload_path = None;
                app.start_upload_local_file(canonical.clone());
            }),
        });
    }

    pub(super) fn start_upload_local_file(&mut self, local_path: PathBuf) {
        let Some(file_name) = local_path
            .file_name()
            .and_then(|s| s.to_str())
            .map(|s| s.to_string())
        else {
            self.set_status("无法解析文件名", true);
            return;
        };
        // OSS PUT needs an accurate Content-Length. If we can't read the
        // file size up-front we abort early instead of silently sending a
        // chunked body that some object stores reject.
        let file_size = match std::fs::metadata(&local_path) {
            Ok(m) => m.len(),
            Err(e) => {
                self.set_status(format!("读取文件信息失败: {e}"), true);
                return;
            }
        };
        let mime_type = infer_content_type(&local_path).to_string();
        let folder_id = self.file.current_folder.clone();
        let refresh_folder = folder_id.clone();

        let id = self.file.next_upload_id;
        self.file.next_upload_id = self.file.next_upload_id.wrapping_add(1);
        let cancel = Arc::new(AtomicBool::new(false));
        self.file.uploads.push(UploadTask {
            id,
            name: file_name.clone(),
            local_path: local_path.clone(),
            total: file_size,
            uploaded: 0,
            status: UploadStatus::Active,
            speed_bps: 0,
            cancel: cancel.clone(),
        });
        self.set_status(format!("开始上传 {file_name} ..."), false);

        let tx = self.tx.clone();
        let api = self.api.clone();
        let display_name = file_name.clone();
        let cancel_for_task = cancel.clone();
        tokio::spawn(async move {
            let res: anyhow::Result<String> = async {
                let upload = api
                    .drive_get_upload_url(&file_name, &mime_type, folder_id.clone())
                    .await?;
                stream_upload(
                    &api.transfer_http_client(),
                    &upload.url,
                    &local_path,
                    file_size,
                    &mime_type,
                    id,
                    cancel_for_task.clone(),
                    tx.clone(),
                )
                .await?;
                let created = api
                    .drive_add_file(&file_name, &upload.filename, folder_id, &mime_type)
                    .await?;
                Ok(created.name)
            }
            .await;
            let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
                let success = res.is_ok();
                let (status_msg, is_error) = match &res {
                    Ok(name) => (format!("已上传 {name}"), false),
                    Err(e) => {
                        if cancel_for_task.load(Ordering::Relaxed) {
                            (format!("已取消上传 {display_name}"), false)
                        } else {
                            (format!("上传失败 {display_name}: {e}"), true)
                        }
                    }
                };
                if let Some(t) = app.file.uploads.iter_mut().find(|t| t.id == id) {
                    match &res {
                        Ok(_) => {
                            t.status = UploadStatus::Completed;
                            t.uploaded = t.total;
                        }
                        Err(e) => {
                            if cancel_for_task.load(Ordering::Relaxed) {
                                t.status = UploadStatus::Cancelled;
                            } else {
                                t.status = UploadStatus::Failed(e.to_string());
                            }
                        }
                    }
                }
                app.set_status(status_msg, is_error);
                if success {
                    app.fetch_drive(refresh_folder);
                }
            })));
        });
    }

    /// Kick off a new download. Creates the destination folder if missing,
    /// derives a non-clashing filename, pushes a task, and spawns the
    /// streaming worker. The UI updates entirely through `Msg::Apply`
    /// messages sent by the worker.
    pub(super) fn start_download(&mut self, file: DriveFile, save_dir: PathBuf) {
        if let Err(e) = std::fs::create_dir_all(&save_dir) {
            self.set_status(format!("创建下载目录失败: {e}"), true);
            return;
        }
        let save_path = unique_path(&save_dir, &file.name);
        let url = file
            .public_url
            .clone()
            .unwrap_or_else(|| file.oss_key.clone());
        if url.is_empty() {
            self.set_status("该文件没有可下载的链接", true);
            return;
        }

        let id = self.file.next_download_id;
        self.file.next_download_id = self.file.next_download_id.wrapping_add(1);
        let cancel = Arc::new(AtomicBool::new(false));
        self.file.downloads.push(DownloadTask {
            id,
            name: file.name.clone(),
            save_path: save_path.clone(),
            total: None,
            downloaded: 0,
            status: DownloadStatus::Active,
            speed_bps: 0,
            cancel: cancel.clone(),
        });

        let tx = self.tx.clone();
        let http = self.api.transfer_http_client();
        let display_name = file.name.clone();
        tokio::spawn(async move {
            let res =
                stream_download(&http, &url, &save_path, id, cancel.clone(), tx.clone()).await;
            let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
                // Resolve the final status + which user-facing message to
                // surface up-front, so the per-task mutable borrow stays
                // scoped to a tight block and we can call set_status after.
                let (status_msg, is_error) = match &res {
                    Ok(()) => (
                        Some(format!("已下载 {} → {}", display_name, save_path.display())),
                        false,
                    ),
                    Err(e) => {
                        if cancel.load(Ordering::Relaxed) {
                            (Some(format!("已取消下载 {display_name}")), false)
                        } else {
                            (Some(format!("下载失败 {display_name}: {e}")), true)
                        }
                    }
                };
                if let Some(t) = app.file.downloads.iter_mut().find(|t| t.id == id) {
                    match &res {
                        Ok(()) => {
                            t.status = DownloadStatus::Completed;
                            if let Some(total) = t.total {
                                t.downloaded = total;
                            }
                        }
                        Err(e) => {
                            if cancel.load(Ordering::Relaxed) {
                                t.status = DownloadStatus::Cancelled;
                            } else {
                                t.status = DownloadStatus::Failed(e.to_string());
                            }
                        }
                    }
                }
                if let Some(m) = status_msg {
                    app.set_status(m, is_error);
                }
            })));
        });
    }
}

fn resolve_upload_input_path(input: &str) -> anyhow::Result<PathBuf> {
    let Some(raw_path) = parse_upload_path_input(input) else {
        anyhow::bail!("请输入文件路径，例如: C:\\Downloads\\file.zip");
    };
    let mut path = PathBuf::from(raw_path);
    if path.is_relative() {
        let cwd = std::env::current_dir().map_err(|e| anyhow::anyhow!("无法获取当前目录: {e}"))?;
        path = cwd.join(path);
    }
    if !path.exists() {
        anyhow::bail!("文件不存在: {}", path.display());
    }
    if !path.is_file() {
        anyhow::bail!("不是普通文件: {}", path.display());
    }
    Ok(std::fs::canonicalize(&path).unwrap_or(path))
}

impl App {
    fn resolve_upload_input(&mut self, value: String) -> Option<PathBuf> {
        match resolve_upload_input_path(&value) {
            Ok(path) => Some(path),
            Err(e) => {
                self.set_status(e.to_string(), true);
                None
            }
        }
    }

    /// Total transfer rows surfaced by the manager modal, in the same
    /// order it renders them: uploads first, then downloads.
    pub fn transfer_count(&self) -> usize {
        self.file.uploads.len() + self.file.downloads.len()
    }

    pub fn transfer_at(&self, idx: usize) -> Option<TransferRef<'_>> {
        let up = self.file.uploads.len();
        if idx < up {
            self.file.uploads.get(idx).map(TransferRef::Upload)
        } else {
            self.file.downloads.get(idx - up).map(TransferRef::Download)
        }
    }

    /// Trip the cancel flag for the active task at `idx`. Returns the
    /// task name so the caller can flash a "正在取消" status.
    pub fn cancel_transfer_at(&self, idx: usize) -> Option<String> {
        match self.transfer_at(idx)? {
            TransferRef::Upload(t) if matches!(t.status, UploadStatus::Active) => {
                t.cancel.store(true, Ordering::Relaxed);
                Some(t.name.clone())
            }
            TransferRef::Download(t) if matches!(t.status, DownloadStatus::Active) => {
                t.cancel.store(true, Ordering::Relaxed);
                Some(t.name.clone())
            }
            _ => None,
        }
    }

    /// Drop everything that's no longer running from both lists. Returns
    /// the new total so the modal can reposition its cursor.
    pub fn clear_finished_transfers(&mut self) -> usize {
        self.file
            .uploads
            .retain(|t| matches!(t.status, UploadStatus::Active));
        self.file
            .downloads
            .retain(|t| matches!(t.status, DownloadStatus::Active));
        self.transfer_count()
    }

    /// Pair of (path-to-reveal, display-name) for the row at `idx`. Used
    /// by the manager's `o` shortcut.
    pub fn reveal_transfer_at(&self, idx: usize) -> Option<(PathBuf, String)> {
        match self.transfer_at(idx)? {
            TransferRef::Upload(t) => Some((t.local_path.clone(), t.name.clone())),
            TransferRef::Download(t) => Some((t.save_path.clone(), t.name.clone())),
        }
    }
}

fn parse_upload_path_input(input: &str) -> Option<String> {
    let s = input.trim();
    if s.is_empty() {
        return None;
    }
    let path_part = if let Some(rest) = s.strip_prefix("note ") {
        rest.trim()
    } else if let Some(rest) = s.strip_prefix("upload ") {
        rest.trim()
    } else {
        s
    };
    let unquoted = path_part
        .strip_prefix('"')
        .and_then(|x| x.strip_suffix('"'))
        .or_else(|| {
            path_part
                .strip_prefix('\'')
                .and_then(|x| x.strip_suffix('\''))
        })
        .unwrap_or(path_part)
        .trim();
    if unquoted.is_empty() {
        None
    } else {
        Some(unquoted.to_string())
    }
}

fn infer_content_type(path: &Path) -> &'static str {
    match path
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_ascii_lowercase()
        .as_str()
    {
        "zip" => "application/zip",
        "pdf" => "application/pdf",
        "txt" | "md" => "text/plain",
        "json" => "application/json",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "mp4" => "video/mp4",
        "mp3" => "audio/mpeg",
        _ => "application/octet-stream",
    }
}

/// Stream the response body of `url` to `save_path` while reporting
/// progress through `tx`. Writes to a `.part` file alongside `save_path`
/// and renames it on success so partial files never appear at the final
/// location. Honors `cancel` between chunks.
async fn stream_download(
    http: &reqwest::Client,
    url: &str,
    save_path: &std::path::Path,
    id: u64,
    cancel: Arc<AtomicBool>,
    tx: mpsc::UnboundedSender<Msg>,
) -> anyhow::Result<()> {
    use anyhow::Context;

    let resp = http
        .get(url)
        .send()
        .await
        .with_context(|| format!("GET {url}"))?
        .error_for_status()
        .with_context(|| format!("HTTP error for {url}"))?;

    let total = resp.content_length();
    // Surface the total length into the task before the first chunk so
    // the UI knows the denominator immediately.
    let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
        if let Some(t) = app.file.downloads.iter_mut().find(|t| t.id == id) {
            t.total = total;
        }
    })));

    let part_path = save_path.with_extension({
        let mut ext = save_path
            .extension()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_string();
        if !ext.is_empty() {
            ext.push('.');
        }
        ext.push_str("part");
        ext
    });

    let mut file = tokio::fs::File::create(&part_path)
        .await
        .with_context(|| format!("create {}", part_path.display()))?;

    let mut stream = resp.bytes_stream();
    let mut downloaded: u64 = 0;
    let mut last_emit = Instant::now();
    let mut last_emit_bytes: u64 = 0;
    let throttle = Duration::from_millis(100);

    while let Some(chunk) = stream.next().await {
        if cancel.load(Ordering::Relaxed) {
            drop(file);
            let _ = tokio::fs::remove_file(&part_path).await;
            return Err(anyhow::anyhow!("cancelled"));
        }
        let bytes = chunk.with_context(|| "read chunk")?;
        file.write_all(&bytes).await.context("write chunk")?;
        downloaded += bytes.len() as u64;

        let now = Instant::now();
        if now.duration_since(last_emit) >= throttle {
            let delta_bytes = downloaded - last_emit_bytes;
            let delta_secs = now.duration_since(last_emit).as_secs_f64().max(0.001);
            let instant_bps = (delta_bytes as f64 / delta_secs) as u64;
            last_emit = now;
            last_emit_bytes = downloaded;
            let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
                if let Some(t) = app.file.downloads.iter_mut().find(|t| t.id == id) {
                    t.downloaded = downloaded;
                    // EMA: 0.7 * prev + 0.3 * instant (or just instant on the
                    // very first sample so the gauge gets a real number).
                    t.speed_bps = if t.speed_bps == 0 {
                        instant_bps
                    } else {
                        ((t.speed_bps as f64) * 0.7 + (instant_bps as f64) * 0.3) as u64
                    };
                }
            })));
        }
    }

    file.flush().await.context("flush")?;
    drop(file);

    if cancel.load(Ordering::Relaxed) {
        let _ = tokio::fs::remove_file(&part_path).await;
        return Err(anyhow::anyhow!("cancelled"));
    }

    tokio::fs::rename(&part_path, save_path)
        .await
        .with_context(|| format!("rename {} -> {}", part_path.display(), save_path.display()))?;

    let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
        if let Some(t) = app.file.downloads.iter_mut().find(|t| t.id == id) {
            t.downloaded = downloaded;
        }
    })));
    Ok(())
}

/// Stream the local file to `url` via PUT, mirroring `stream_download`'s
/// progress + cancel semantics. The body is sent as a chunk-driven
/// `Stream<Item = Result<Vec<u8>, io::Error>>` so reqwest only buffers a
/// single 64 KiB chunk at a time, and progress messages flow through `tx`.
/// The Content-Length header is set explicitly because OSS-style endpoints
/// reject `Transfer-Encoding: chunked`.
#[allow(clippy::too_many_arguments)]
async fn stream_upload(
    http: &reqwest::Client,
    url: &str,
    local_path: &Path,
    total: u64,
    mime_type: &str,
    id: u64,
    cancel: Arc<AtomicBool>,
    tx: mpsc::UnboundedSender<Msg>,
) -> anyhow::Result<()> {
    use anyhow::Context;

    let file = tokio::fs::File::open(local_path)
        .await
        .with_context(|| format!("open {}", local_path.display()))?;

    let cancel_for_stream = cancel.clone();
    let tx_for_stream = tx.clone();
    let throttle = Duration::from_millis(100);
    let stream = futures::stream::unfold(
        (file, 0u64, Instant::now(), 0u64),
        move |(mut file, mut uploaded, mut last_emit, mut last_emit_bytes)| {
            let cancel = cancel_for_stream.clone();
            let tx = tx_for_stream.clone();
            async move {
                if cancel.load(Ordering::Relaxed) {
                    return Some((
                        Err::<Vec<u8>, std::io::Error>(std::io::Error::other("cancelled")),
                        (file, uploaded, last_emit, last_emit_bytes),
                    ));
                }
                let mut buf = vec![0u8; 64 * 1024];
                match file.read(&mut buf).await {
                    Ok(0) => None,
                    Ok(n) => {
                        buf.truncate(n);
                        uploaded += n as u64;
                        let now = Instant::now();
                        if now.duration_since(last_emit) >= throttle {
                            let delta_bytes = uploaded - last_emit_bytes;
                            let delta_secs = now.duration_since(last_emit).as_secs_f64().max(0.001);
                            let instant_bps = (delta_bytes as f64 / delta_secs) as u64;
                            last_emit = now;
                            last_emit_bytes = uploaded;
                            let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
                                if let Some(t) = app.file.uploads.iter_mut().find(|t| t.id == id) {
                                    t.uploaded = uploaded;
                                    // Match the download EMA so the gauge
                                    // jitter feels the same in both panes.
                                    t.speed_bps = if t.speed_bps == 0 {
                                        instant_bps
                                    } else {
                                        ((t.speed_bps as f64) * 0.7 + (instant_bps as f64) * 0.3)
                                            as u64
                                    };
                                }
                            })));
                        }
                        Some((Ok(buf), (file, uploaded, last_emit, last_emit_bytes)))
                    }
                    Err(e) => Some((Err(e), (file, uploaded, last_emit, last_emit_bytes))),
                }
            }
        },
    );

    let body = reqwest::Body::wrap_stream(stream);
    let resp = http
        .put(url)
        .header("content-type", mime_type)
        .header("content-length", total)
        .body(body)
        .send()
        .await
        .map_err(|e| {
            if cancel.load(Ordering::Relaxed) {
                anyhow::anyhow!("cancelled")
            } else {
                anyhow::anyhow!("上传请求失败: {e}")
            }
        })?;
    if cancel.load(Ordering::Relaxed) {
        return Err(anyhow::anyhow!("cancelled"));
    }
    if !resp.status().is_success() {
        let status = resp.status();
        let text = resp.text().await.unwrap_or_default();
        return Err(anyhow::anyhow!("上传对象存储失败: HTTP {status} {text}"));
    }
    let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
        if let Some(t) = app.file.uploads.iter_mut().find(|t| t.id == id) {
            t.uploaded = t.total;
        }
    })));
    Ok(())
}
