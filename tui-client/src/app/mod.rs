use anyhow::Result;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui_image::picker::Picker;
use ratatui_image::thread::{ResizeRequest, ResizeResponse};
use tokio::sync::mpsc;

use crate::api::ApiClient;
use crate::api::dto::*;
use crate::config::AppConfig;

pub mod file;
pub mod image;
pub mod login;
pub mod notes;
pub mod settings;
pub mod timeline;
pub mod todo;

pub use file::{DownloadStatus, DownloadTask, FileState, TransferRef, UploadStatus, UploadTask};
pub use image::ImageState;
pub use login::LoginState;
pub use notes::{NoteDetail, NotesState};
pub use settings::{COLOR_PRESETS, SettingsSection, SettingsState};
pub use timeline::TimelineState;
pub use todo::TodoState;

pub type Apply = Box<dyn FnOnce(&mut App) + Send>;

pub enum Msg {
    Key(KeyEvent),
    Tick,
    Resize(#[allow(dead_code)] u16, #[allow(dead_code)] u16),
    Apply(Apply),
    ImagePreviewResized(std::result::Result<ResizeResponse, String>),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tab {
    Timeline,
    Notes,
    Todo,
    Image,
    File,
    Settings,
}

impl Tab {
    pub const ALL: [Tab; 6] = [
        Tab::Timeline,
        Tab::Notes,
        Tab::Todo,
        Tab::Image,
        Tab::File,
        Tab::Settings,
    ];

    pub fn label(self) -> &'static str {
        match self {
            Tab::Timeline => "时间线",
            Tab::Notes => "笔记",
            Tab::Todo => "待办",
            Tab::Image => "图床",
            Tab::File => "网盘",
            Tab::Settings => "设置",
        }
    }

    pub fn shortcut(self) -> char {
        match self {
            Tab::Timeline => '1',
            Tab::Notes => '2',
            Tab::Todo => '3',
            Tab::Image => '4',
            Tab::File => '5',
            Tab::Settings => '6',
        }
    }
}

pub enum Modal {
    Confirm {
        prompt: String,
        on_yes: Apply,
    },
    Input {
        title: String,
        prompt: String,
        value: String,
        on_submit: Box<dyn FnOnce(&mut App, String) + Send>,
    },
    #[allow(dead_code)]
    Message {
        title: String,
        body: String,
    },
    TagPicker {
        note_id: String,
        all: Vec<NoteTag>,
        selected: std::collections::HashSet<i64>,
        cursor: usize,
        new_input: String,
        new_input_focus: bool,
    },
    GroupPicker {
        groups: Vec<GroupItem>,
        cursor: usize,
    },
    /// Asks the user where to save the download. Holds the resolved
    /// option paths so the prompt can render them as absolute strings.
    DownloadDest {
        file: DriveFile,
        cfg_path: Option<std::path::PathBuf>,
        cwd_path: std::path::PathBuf,
    },
    /// Full-screen download manager. The cursor lives on the modal so
    /// closing it forgets the selection.
    DownloadManager {
        cursor: usize,
    },
}

pub struct App {
    pub api: ApiClient,
    pub config: AppConfig,
    pub tx: mpsc::UnboundedSender<Msg>,
    pub image_picker: Picker,
    pub image_resize_tx: mpsc::UnboundedSender<ResizeRequest>,

    pub authenticated: bool,
    pub auth_checking: bool,
    pub username: Option<String>,

    pub groups: Vec<GroupItem>,
    pub active_group_id: Option<String>,
    pub active_group_name: Option<String>,
    pub user_primary_color: Option<String>,

    pub tab: Tab,
    pub login: LoginState,
    pub timeline: TimelineState,
    pub notes: NotesState,
    pub todo: TodoState,
    pub image: ImageState,
    pub file: FileState,
    pub settings: SettingsState,

    pub modal: Option<Modal>,

    pub status_msg: Option<(String, bool)>, // (message, is_error)
    pub status_tick_remaining: u8,
    pub spinner_phase: u8,
    pub pending_requests: u32,
    pub startup_upload_path: Option<String>,

    pub should_quit: bool,
}

impl App {
    pub fn new(
        api: ApiClient,
        config: AppConfig,
        tx: mpsc::UnboundedSender<Msg>,
        image_picker: Picker,
        image_resize_tx: mpsc::UnboundedSender<ResizeRequest>,
        startup_upload_path: Option<String>,
    ) -> Self {
        let active_group_id = config.active_group_id.clone();
        Self {
            api,
            config,
            tx,
            image_picker,
            image_resize_tx,
            authenticated: false,
            auth_checking: false,
            username: None,
            groups: Vec::new(),
            active_group_id,
            active_group_name: None,
            user_primary_color: None,
            tab: Tab::Timeline,
            login: LoginState::default(),
            timeline: TimelineState::default(),
            notes: NotesState::default(),
            todo: TodoState::default(),
            image: ImageState::default(),
            file: FileState::default(),
            settings: SettingsState::default(),
            modal: None,
            status_msg: None,
            status_tick_remaining: 0,
            spinner_phase: 0,
            pending_requests: 0,
            startup_upload_path,
            should_quit: false,
        }
    }

    pub fn loading(&self) -> bool {
        self.pending_requests > 0
    }

    pub fn set_status<S: Into<String>>(&mut self, s: S, is_error: bool) {
        self.status_msg = Some((s.into(), is_error));
        self.status_tick_remaining = 30; // ~3s @ 100ms ticks
    }

    #[allow(dead_code)]
    pub fn clear_status(&mut self) {
        self.status_msg = None;
        self.status_tick_remaining = 0;
    }

    pub(crate) fn spawn<F, Fut, R>(&mut self, f: F)
    where
        F: FnOnce(ApiClient) -> Fut + Send + 'static,
        Fut: std::future::Future<Output = R> + Send + 'static,
        R: FnOnce(&mut App) + Send + 'static,
    {
        let tx = self.tx.clone();
        let api = self.api.clone();
        self.pending_requests = self.pending_requests.saturating_add(1);
        tokio::spawn(async move {
            let apply = f(api).await;
            let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
                app.pending_requests = app.pending_requests.saturating_sub(1);
                apply(app);
            })));
        });
    }

    // ─── Bootstrap ────────────────────────────────────────────────────

    pub fn boot(&mut self) {
        if let Some(token) = self.config.token.clone() {
            self.api.set_token(Some(token.clone()));
            self.auth_checking = true;
            self.spawn(move |api| async move {
                let res = api.verify_token(&token).await;
                Box::new(move |app: &mut App| {
                    app.auth_checking = false;
                    match res {
                        Ok(r) if r.ok => {
                            app.authenticated = true;
                            app.after_login();
                        }
                        Ok(_) => {
                            app.api.set_token(None);
                            let _ = app.config.set_token(None);
                        }
                        Err(e) => {
                            app.set_status(format!("token 校验失败: {e}"), true);
                        }
                    }
                })
            });
        }
    }

    pub(crate) fn after_login(&mut self) {
        // Apply persisted group selection to api headers immediately,
        // so initial fetches go to the right scope.
        self.api.set_group(self.active_group_id.clone());
        self.fetch_profile();
        self.fetch_groups();
        self.refresh_current_tab();
        if let Some(path) = self.startup_upload_path.take() {
            self.tab = Tab::File;
            self.begin_startup_upload_target_selection(path);
        }
    }

    pub(crate) fn fetch_profile(&mut self) {
        self.spawn(|api| async move {
            let res = api.get_profile().await;
            Box::new(move |app: &mut App| match res {
                Ok(p) => {
                    app.username = Some(p.name);
                    app.user_primary_color = p
                        .meta
                        .get("primaryColor")
                        .and_then(|v| v.as_str())
                        .filter(|s| !s.is_empty())
                        .map(|s| s.to_string());
                }
                Err(_) => {}
            })
        });
    }

    /// Hex color (e.g. `#ff9edd`) for the currently active scope, taken from
    /// the group's `meta.primaryColor` or — when in personal scope — the
    /// user's own `meta.primaryColor`. Returns `None` when nothing has been
    /// configured.
    pub fn active_primary_color(&self) -> Option<String> {
        match &self.active_group_id {
            Some(gid) => self
                .groups
                .iter()
                .find(|g| &g.id == gid)
                .and_then(|g| g.meta.as_ref())
                .and_then(|m| m.primary_color.as_ref())
                .filter(|s| !s.is_empty())
                .cloned(),
            None => self.user_primary_color.clone(),
        }
    }

    pub(crate) fn fetch_groups(&mut self) {
        self.spawn(|api| async move {
            let res = api.list_groups().await;
            Box::new(move |app: &mut App| match res {
                Ok(groups) => {
                    // Resolve active group name (or clear if previously selected
                    // group is no longer accessible).
                    if let Some(gid) = app.active_group_id.clone() {
                        match groups.iter().find(|g| g.id == gid) {
                            Some(g) => app.active_group_name = Some(g.name.clone()),
                            None => {
                                app.active_group_id = None;
                                app.active_group_name = None;
                                app.api.set_group(None);
                                let _ = app.config.set_active_group(None);
                            }
                        }
                    } else {
                        app.active_group_name = None;
                    }
                    app.groups = groups;
                }
                Err(e) => app.handle_api_err("群组列表", e),
            })
        });
    }

    fn open_group_picker(&mut self) {
        let groups = self.groups.clone();
        // Cursor defaults to currently active row (0 = personal).
        let cursor = match &self.active_group_id {
            None => 0,
            Some(gid) => groups
                .iter()
                .position(|g| &g.id == gid)
                .map(|i| i + 1)
                .unwrap_or(0),
        };
        self.modal = Some(Modal::GroupPicker { groups, cursor });
    }

    fn switch_group(&mut self, target: Option<String>, target_name: Option<String>) {
        if target == self.active_group_id {
            return;
        }
        self.active_group_id = target.clone();
        self.active_group_name = target_name.clone();
        self.api.set_group(target.clone());
        if let Err(e) = self.config.set_active_group(target.clone()) {
            self.set_status(format!("保存群组配置失败: {e}"), true);
        }
        // Wipe per-tab caches so they don't leak across scopes.
        self.timeline = TimelineState::default();
        self.notes = NotesState::default();
        self.todo = TodoState::default();
        self.image = ImageState::default();
        self.file = FileState::default();
        self.refresh_current_tab();
        let label = target_name.unwrap_or_else(|| "个人".to_string());
        self.set_status(format!("已切到 {label}"), false);
    }

    pub fn refresh_current_tab(&mut self) {
        match self.tab {
            Tab::Timeline => self.fetch_timeline(0),
            Tab::Notes => {
                self.fetch_notes(0);
                self.fetch_note_tags();
            }
            Tab::Todo => self.fetch_todo_lists(),
            Tab::Image => self.fetch_images(0),
            Tab::File => self.fetch_drive(self.file.current_folder.clone()),
            Tab::Settings => {
                // Settings is partly state-driven from data we already have
                // (groups + user_primary_color), but re-fetching keeps it
                // honest if the user changed something on the web client.
                self.fetch_profile();
                self.fetch_groups();
                self.fetch_settings_account_data();
            }
        }
    }

    pub(crate) fn handle_api_err(&mut self, label: &str, e: anyhow::Error) {
        let msg = format!("{label}: {e}");
        let lc = msg.to_ascii_lowercase();
        if lc.contains("unauthorized") || lc.contains("401") || lc.contains("token") {
            self.api.set_token(None);
            let _ = self.config.set_token(None);
            self.api.set_group(None);
            let _ = self.config.set_active_group(None);
            self.active_group_id = None;
            self.active_group_name = None;
            self.authenticated = false;
        }
        self.set_status(msg, true);
    }

    // ─── Update / Event dispatch ──────────────────────────────────────

    pub fn update(&mut self, msg: Msg) {
        match msg {
            Msg::Apply(f) => f(self),
            Msg::ImagePreviewResized(res) => self.handle_image_preview_resized(res),
            Msg::Tick => self.on_tick(),
            Msg::Resize(_, _) => {}
            Msg::Key(key) => self.on_key(key),
        }
    }

    fn on_tick(&mut self) {
        self.spinner_phase = self.spinner_phase.wrapping_add(1);
        if self.status_tick_remaining > 0 {
            self.status_tick_remaining -= 1;
            if self.status_tick_remaining == 0 {
                self.status_msg = None;
            }
        }
    }

    fn on_key(&mut self, key: KeyEvent) {
        if self.modal.is_some() {
            self.handle_modal_key(key);
            return;
        }
        if !self.authenticated {
            self.handle_login_key(key);
            return;
        }
        if key.code == KeyCode::Char('c') && key.modifiers.contains(KeyModifiers::CONTROL) {
            self.should_quit = true;
            return;
        }
        // Download manager — Ctrl+D from any tab, but stay out of the note
        // editor where Ctrl+D could mean something to the textarea.
        if key.code == KeyCode::Char('d')
            && key.modifiers.contains(KeyModifiers::CONTROL)
            && !matches!(self.notes.detail, Some(NoteDetail::Edit { .. }))
            && self.file.pending_upload_path.is_none()
        {
            self.modal = Some(Modal::DownloadManager { cursor: 0 });
            return;
        }
        // group picker — only outside of the note editor
        if key.code == KeyCode::Char('g')
            && key.modifiers.is_empty()
            && !matches!(self.notes.detail, Some(NoteDetail::Edit { .. }))
            && self.file.pending_upload_path.is_none()
        {
            self.open_group_picker();
            return;
        }
        // tab switching via numbers — disabled while typing in any of the
        // text inputs that need to receive raw digits (note detail + custom
        // color hex field on the settings tab).
        let in_text_input = self.notes.detail.is_some()
            || (self.tab == Tab::Settings && self.settings.editing_custom)
            || self.file.pending_upload_path.is_some();
        if let KeyCode::Char(c) = key.code
            && key.modifiers.is_empty()
            && !in_text_input
        {
            for t in Tab::ALL {
                if c == t.shortcut() {
                    if self.tab != t {
                        self.tab = t;
                        self.refresh_current_tab();
                    }
                    return;
                }
            }
        }
        match self.tab {
            Tab::Timeline => self.handle_timeline_key(key),
            Tab::Notes => self.handle_notes_key(key),
            Tab::Todo => self.handle_todo_key(key),
            Tab::Image => self.handle_image_key(key),
            Tab::File => self.handle_file_key(key),
            Tab::Settings => self.handle_settings_key(key),
        }
    }

    // ─── Modal ────────────────────────────────────────────────────────

    fn handle_modal_key(&mut self, key: KeyEvent) {
        let modal = self.modal.take();
        match modal {
            Some(Modal::Confirm { prompt, on_yes }) => match key.code {
                KeyCode::Char('y') | KeyCode::Char('Y') | KeyCode::Enter => on_yes(self),
                KeyCode::Esc | KeyCode::Char('n') | KeyCode::Char('N') => {}
                _ => self.modal = Some(Modal::Confirm { prompt, on_yes }),
            },
            Some(Modal::Input {
                title,
                prompt,
                mut value,
                on_submit,
            }) => match key.code {
                KeyCode::Esc => {}
                KeyCode::Enter => on_submit(self, value),
                KeyCode::Backspace => {
                    value.pop();
                    self.modal = Some(Modal::Input {
                        title,
                        prompt,
                        value,
                        on_submit,
                    });
                }
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                    value.push(c);
                    self.modal = Some(Modal::Input {
                        title,
                        prompt,
                        value,
                        on_submit,
                    });
                }
                _ => {
                    self.modal = Some(Modal::Input {
                        title,
                        prompt,
                        value,
                        on_submit,
                    })
                }
            },
            Some(Modal::Message { title, body }) => match key.code {
                KeyCode::Esc | KeyCode::Enter | KeyCode::Char('q') => {}
                _ => self.modal = Some(Modal::Message { title, body }),
            },
            Some(Modal::TagPicker {
                note_id,
                all,
                mut selected,
                mut cursor,
                mut new_input,
                mut new_input_focus,
            }) => {
                if new_input_focus {
                    match key.code {
                        KeyCode::Esc => new_input_focus = false,
                        KeyCode::Enter => {
                            if !new_input.trim().is_empty() {
                                let name = new_input.trim().to_string();
                                let nid = note_id.clone();
                                self.spawn(move |api| async move {
                                    let r = api.create_note_tag(&name).await;
                                    Box::new(move |app: &mut App| match r {
                                        Ok(t) => {
                                            let tid = t.id;
                                            if !app.notes.tags.iter().any(|x| x.id == tid) {
                                                app.notes.tags.push(t);
                                            }
                                            // Bind new tag to note immediately
                                            let nid2 = nid.clone();
                                            app.spawn(move |api| async move {
                                                let _ = api.add_tag_to_note(&nid2, tid).await;
                                                Box::new(|_app: &mut App| {})
                                            });
                                        }
                                        Err(e) => app.handle_api_err("新建标签", e),
                                    })
                                });
                                new_input.clear();
                                new_input_focus = false;
                            }
                        }
                        KeyCode::Backspace => {
                            new_input.pop();
                        }
                        KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                            new_input.push(c);
                        }
                        _ => {}
                    }
                } else {
                    match key.code {
                        KeyCode::Esc | KeyCode::Char('q') => {
                            self.modal = None;
                            return;
                        }
                        KeyCode::Char('a') => new_input_focus = true,
                        KeyCode::Up | KeyCode::Char('k') => {
                            if !all.is_empty() && cursor > 0 {
                                cursor -= 1;
                            }
                        }
                        KeyCode::Down | KeyCode::Char('j') => {
                            if !all.is_empty() && cursor + 1 < all.len() {
                                cursor += 1;
                            }
                        }
                        KeyCode::Enter | KeyCode::Char(' ') => {
                            if let Some(t) = all.get(cursor) {
                                let tid = t.id;
                                let nid = note_id.clone();
                                if selected.contains(&tid) {
                                    selected.remove(&tid);
                                    self.spawn(move |api| async move {
                                        let _ = api.remove_tag_from_note(&nid, tid).await;
                                        Box::new(|_app: &mut App| {})
                                    });
                                } else {
                                    selected.insert(tid);
                                    self.spawn(move |api| async move {
                                        let _ = api.add_tag_to_note(&nid, tid).await;
                                        Box::new(|_app: &mut App| {})
                                    });
                                }
                            }
                        }
                        _ => {}
                    }
                }
                self.modal = Some(Modal::TagPicker {
                    note_id,
                    all,
                    selected,
                    cursor,
                    new_input,
                    new_input_focus,
                });
            }
            Some(Modal::GroupPicker { groups, mut cursor }) => {
                let total = groups.len() + 1; // +1 for the "personal" virtual row
                match key.code {
                    KeyCode::Esc | KeyCode::Char('q') => {}
                    KeyCode::Up | KeyCode::Char('k') => {
                        if cursor > 0 {
                            cursor -= 1;
                        }
                        self.modal = Some(Modal::GroupPicker { groups, cursor });
                    }
                    KeyCode::Down | KeyCode::Char('j') => {
                        if cursor + 1 < total {
                            cursor += 1;
                        }
                        self.modal = Some(Modal::GroupPicker { groups, cursor });
                    }
                    KeyCode::Enter | KeyCode::Char(' ') => {
                        if cursor == 0 {
                            self.switch_group(None, None);
                        } else if let Some(g) = groups.get(cursor - 1) {
                            self.switch_group(Some(g.id.clone()), Some(g.name.clone()));
                        }
                    }
                    _ => self.modal = Some(Modal::GroupPicker { groups, cursor }),
                }
            }
            Some(Modal::DownloadDest {
                file,
                cfg_path,
                cwd_path,
            }) => match key.code {
                KeyCode::Esc | KeyCode::Char('q') => {}
                KeyCode::Char('1') | KeyCode::Enter => {
                    let dir = cfg_path
                        .unwrap_or_else(|| crate::util::resolve_default_download_dir(&self.config));
                    self.start_download(file, dir);
                }
                KeyCode::Char('2') => {
                    self.start_download(file, cwd_path);
                }
                KeyCode::Char('3') => {
                    let url = file
                        .public_url
                        .clone()
                        .unwrap_or_else(|| file.oss_key.clone());
                    self.file.last_link = Some(url.clone());
                    match crate::util::copy_to_clipboard(&url) {
                        Ok(()) => self.set_status("已复制链接到剪贴板", false),
                        Err(e) => self.set_status(format!("复制失败: {e}"), true),
                    }
                }
                _ => {
                    self.modal = Some(Modal::DownloadDest {
                        file,
                        cfg_path,
                        cwd_path,
                    });
                }
            },
            Some(Modal::DownloadManager { mut cursor }) => {
                let len = self.transfer_count();
                match key.code {
                    KeyCode::Esc | KeyCode::Char('q') => {}
                    KeyCode::Up | KeyCode::Char('k') => {
                        if cursor > 0 {
                            cursor -= 1;
                        }
                        self.modal = Some(Modal::DownloadManager { cursor });
                    }
                    KeyCode::Down | KeyCode::Char('j') => {
                        if cursor + 1 < len {
                            cursor += 1;
                        }
                        self.modal = Some(Modal::DownloadManager { cursor });
                    }
                    KeyCode::Char('x') => {
                        if let Some(name) = self.cancel_transfer_at(cursor) {
                            self.set_status(format!("正在取消 {}", name), false);
                        }
                        self.modal = Some(Modal::DownloadManager { cursor });
                    }
                    KeyCode::Char('c') => {
                        let new_len = self.clear_finished_transfers();
                        let new_cursor = if new_len == 0 {
                            0
                        } else {
                            cursor.min(new_len - 1)
                        };
                        if new_len == 0 {
                            // Auto-close when nothing is left to look at.
                            self.set_status("已清空传输列表", false);
                        } else {
                            self.modal = Some(Modal::DownloadManager { cursor: new_cursor });
                        }
                    }
                    KeyCode::Char('o') => {
                        if let Some((path, name)) = self.reveal_transfer_at(cursor) {
                            if let Err(e) = crate::util::reveal_in_explorer(&path) {
                                self.set_status(format!("打开目录失败: {e}"), true);
                            } else {
                                self.set_status(format!("已在文件管理器中显示 {name}"), false);
                            }
                        }
                        self.modal = Some(Modal::DownloadManager { cursor });
                    }
                    _ => self.modal = Some(Modal::DownloadManager { cursor }),
                }
            }
            None => {}
        }
    }
}

pub async fn run(
    api: ApiClient,
    config: AppConfig,
    startup_upload_path: Option<String>,
) -> Result<()> {
    use std::io;
    use std::time::Duration;

    use crossterm::execute;
    use crossterm::terminal::{
        EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode,
    };
    use ratatui::Terminal;
    use ratatui::backend::CrosstermBackend;

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let (tx, mut rx) = mpsc::unbounded_channel::<Msg>();
    let (image_resize_tx, mut image_resize_rx) = mpsc::unbounded_channel::<ResizeRequest>();
    let image_picker = Picker::from_query_stdio().unwrap_or_else(|_| Picker::halfblocks());
    crate::event::spawn_input_loop(tx.clone());
    crate::event::spawn_tick_loop(tx.clone(), Duration::from_millis(100));

    let mut app = App::new(
        api,
        config,
        tx.clone(),
        image_picker,
        image_resize_tx,
        startup_upload_path,
    );
    app.boot();

    let result: Result<()> = loop {
        if let Err(e) = terminal.draw(|f| crate::ui::render(f, &mut app)) {
            break Err(e.into());
        }
        tokio::select! {
            Some(msg) = rx.recv() => app.update(msg),
            Some(request) = image_resize_rx.recv() => {
                let tx = tx.clone();
                tokio::spawn(async move {
                    let res = tokio::task::spawn_blocking(move || {
                        request.resize_encode().map_err(|e| e.to_string())
                    })
                    .await
                    .map_err(|e| e.to_string())
                    .and_then(|x| x);
                    let _ = tx.send(Msg::ImagePreviewResized(res));
                });
            }
            else => break Ok(()),
        }
        if app.should_quit {
            break Ok(());
        }
    };

    disable_raw_mode().ok();
    execute!(terminal.backend_mut(), LeaveAlternateScreen).ok();
    terminal.show_cursor().ok();
    result
}
