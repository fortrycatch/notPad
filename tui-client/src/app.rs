use anyhow::Result;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui_textarea::{Input, Key as TaKey, TextArea};
use tokio::sync::mpsc;

use crate::api::ApiClient;
use crate::api::dto::*;
use crate::config::AppConfig;

pub type Apply = Box<dyn FnOnce(&mut App) + Send>;

pub enum Msg {
    Key(KeyEvent),
    Tick,
    Resize(#[allow(dead_code)] u16, #[allow(dead_code)] u16),
    Apply(Apply),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tab {
    Timeline,
    Notes,
    Todo,
    Image,
    File,
}

impl Tab {
    pub const ALL: [Tab; 5] = [
        Tab::Timeline,
        Tab::Notes,
        Tab::Todo,
        Tab::Image,
        Tab::File,
    ];

    pub fn label(self) -> &'static str {
        match self {
            Tab::Timeline => "时间线",
            Tab::Notes => "笔记",
            Tab::Todo => "待办",
            Tab::Image => "图床",
            Tab::File => "网盘",
        }
    }

    pub fn shortcut(self) -> char {
        match self {
            Tab::Timeline => '1',
            Tab::Notes => '2',
            Tab::Todo => '3',
            Tab::Image => '4',
            Tab::File => '5',
        }
    }
}

#[derive(Debug, Default)]
pub struct LoginState {
    pub username: String,
    pub password: String,
    pub focus: u8, // 0 = username, 1 = password
    pub submitting: bool,
    pub error: Option<String>,
}

#[derive(Debug, Default)]
pub struct TimelineState {
    pub items: Vec<TimelineItem>,
    pub page: u32,
    pub cursor: usize,
    pub loading: bool,
    pub end: bool,
}

#[derive(Debug, Default)]
pub struct NotesState {
    pub items: Vec<NoteListItem>,
    pub tags: Vec<NoteTag>,
    pub active_tag: Option<i64>,
    pub cursor: usize,
    pub page: u32,
    pub loading: bool,
    pub detail: Option<NoteDetail>,
}

#[derive(Debug)]
pub enum NoteDetail {
    Loading(String),
    View {
        note: Note,
        tags: Vec<NoteTag>,
    },
    Edit {
        id: Option<String>,
        title: String,
        title_focus: bool,
        textarea: TextArea<'static>,
        original_tags: Vec<NoteTag>,
    },
}

#[derive(Debug, Default)]
pub struct TodoState {
    pub lists: Vec<TodoList>,
    pub list_cursor: usize,
    pub items: Vec<TodoItem>,
    pub item_cursor: usize,
    pub focus_items: bool, // false = lists, true = items
    pub loading_lists: bool,
    pub loading_items: bool,
}

#[derive(Debug, Default)]
pub struct ImageState {
    pub items: Vec<ImageItem>,
    pub cursor: usize,
    pub page: u32,
    pub search: String,
    pub loading: bool,
    pub end: bool,
}

#[derive(Debug, Default, Clone)]
pub struct DriveBreadcrumb {
    pub id: Option<String>,
    pub name: String,
}

#[derive(Debug, Default)]
pub struct FileState {
    pub current_folder: Option<String>,
    pub breadcrumbs: Vec<DriveBreadcrumb>,
    pub folders: Vec<DriveFolder>,
    pub files: Vec<DriveFile>,
    pub cursor: usize, // index across folders+files
    pub loading: bool,
    pub last_link: Option<String>,
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
}

pub struct App {
    pub api: ApiClient,
    pub config: AppConfig,
    pub tx: mpsc::UnboundedSender<Msg>,

    pub authenticated: bool,
    pub auth_checking: bool,
    pub username: Option<String>,

    pub groups: Vec<GroupItem>,
    pub active_group_id: Option<String>,
    pub active_group_name: Option<String>,

    pub tab: Tab,
    pub login: LoginState,
    pub timeline: TimelineState,
    pub notes: NotesState,
    pub todo: TodoState,
    pub image: ImageState,
    pub file: FileState,

    pub modal: Option<Modal>,

    pub status_msg: Option<(String, bool)>, // (message, is_error)
    pub status_tick_remaining: u8,
    pub spinner_phase: u8,
    pub pending_requests: u32,

    pub should_quit: bool,
}

impl App {
    pub fn new(api: ApiClient, config: AppConfig, tx: mpsc::UnboundedSender<Msg>) -> Self {
        let active_group_id = config.active_group_id.clone();
        Self {
            api,
            config,
            tx,
            authenticated: false,
            auth_checking: false,
            username: None,
            groups: Vec::new(),
            active_group_id,
            active_group_name: None,
            tab: Tab::Timeline,
            login: LoginState::default(),
            timeline: TimelineState::default(),
            notes: NotesState::default(),
            todo: TodoState::default(),
            image: ImageState::default(),
            file: FileState::default(),
            modal: None,
            status_msg: None,
            status_tick_remaining: 0,
            spinner_phase: 0,
            pending_requests: 0,
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

    fn spawn<F, Fut, R>(&mut self, f: F)
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

    fn after_login(&mut self) {
        // Apply persisted group selection to api headers immediately,
        // so initial fetches go to the right scope.
        self.api.set_group(self.active_group_id.clone());
        self.fetch_profile();
        self.fetch_groups();
        self.refresh_current_tab();
    }

    fn fetch_profile(&mut self) {
        self.spawn(|api| async move {
            let res = api.get_profile().await;
            Box::new(move |app: &mut App| match res {
                Ok(p) => app.username = Some(p.name),
                Err(_) => {}
            })
        });
    }

    fn fetch_groups(&mut self) {
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
        }
    }

    fn fetch_timeline(&mut self, page: u32) {
        self.timeline.loading = true;
        self.spawn(move |api| async move {
            let res = api.get_timeline(page).await;
            Box::new(move |app: &mut App| {
                app.timeline.loading = false;
                match res {
                    Ok(items) => {
                        app.timeline.end = items.len() < 30;
                        if page == 0 {
                            app.timeline.items = items;
                            app.timeline.cursor = 0;
                        } else {
                            app.timeline.items.extend(items);
                        }
                        app.timeline.page = page;
                    }
                    Err(e) => app.handle_api_err("时间线", e),
                }
            })
        });
    }

    fn fetch_notes(&mut self, page: u32) {
        self.notes.loading = true;
        let tag_id = self.notes.active_tag;
        self.spawn(move |api| async move {
            let res = api.get_notes(page, tag_id).await;
            Box::new(move |app: &mut App| {
                app.notes.loading = false;
                match res {
                    Ok(items) => {
                        if page == 0 {
                            app.notes.items = items;
                            app.notes.cursor = 0;
                        } else {
                            app.notes.items.extend(items);
                        }
                        app.notes.page = page;
                    }
                    Err(e) => app.handle_api_err("笔记列表", e),
                }
            })
        });
    }

    fn fetch_note_tags(&mut self) {
        self.spawn(|api| async move {
            let res = api.list_note_tags().await;
            Box::new(move |app: &mut App| match res {
                Ok(tags) => app.notes.tags = tags,
                Err(e) => app.handle_api_err("笔记标签", e),
            })
        });
    }

    fn fetch_note_detail(&mut self, id: String) {
        self.notes.detail = Some(NoteDetail::Loading(id.clone()));
        let id_clone = id.clone();
        self.spawn(move |api| async move {
            let note = api.get_note_by_id(&id_clone).await;
            let tags = api.get_note_tags(&id_clone).await;
            Box::new(move |app: &mut App| match (note, tags) {
                (Ok(n), Ok(t)) => {
                    app.notes.detail = Some(NoteDetail::View { note: n, tags: t });
                }
                (Err(e), _) | (_, Err(e)) => {
                    app.notes.detail = None;
                    app.handle_api_err("笔记详情", e);
                }
            })
        });
    }

    fn fetch_todo_lists(&mut self) {
        self.todo.loading_lists = true;
        self.spawn(|api| async move {
            let res = api.list_todo_lists().await;
            Box::new(move |app: &mut App| {
                app.todo.loading_lists = false;
                match res {
                    Ok(lists) => {
                        let prev = app
                            .todo
                            .lists
                            .get(app.todo.list_cursor)
                            .map(|l| l.id.clone());
                        app.todo.lists = lists;
                        if app.todo.list_cursor >= app.todo.lists.len() {
                            app.todo.list_cursor = 0;
                        }
                        if !app.todo.lists.is_empty() {
                            // try to keep same selected list across refresh
                            if let Some(prev_id) = prev
                                && let Some(idx) = app
                                    .todo
                                    .lists
                                    .iter()
                                    .position(|l| l.id == prev_id)
                            {
                                app.todo.list_cursor = idx;
                            }
                            let id = app.todo.lists[app.todo.list_cursor].id.clone();
                            app.fetch_todo_items(id);
                        } else {
                            app.todo.items.clear();
                        }
                    }
                    Err(e) => app.handle_api_err("待办列表", e),
                }
            })
        });
    }

    fn fetch_todo_items(&mut self, list_id: String) {
        self.todo.loading_items = true;
        self.spawn(move |api| async move {
            let res = api.get_todo_list(&list_id).await;
            Box::new(move |app: &mut App| {
                app.todo.loading_items = false;
                match res {
                    Ok(l) => {
                        app.todo.items = l.items;
                        if app.todo.item_cursor >= app.todo.items.len() {
                            app.todo.item_cursor = 0;
                        }
                    }
                    Err(e) => app.handle_api_err("待办项", e),
                }
            })
        });
    }

    fn fetch_images(&mut self, page: u32) {
        self.image.loading = true;
        let search = self.image.search.clone();
        self.spawn(move |api| async move {
            let res = api.list_images(page, "time_desc", &search).await;
            Box::new(move |app: &mut App| {
                app.image.loading = false;
                match res {
                    Ok(items) => {
                        app.image.end = items.len() < 30;
                        if page == 0 {
                            app.image.items = items;
                            app.image.cursor = 0;
                        } else {
                            app.image.items.extend(items);
                        }
                        app.image.page = page;
                    }
                    Err(e) => app.handle_api_err("图床", e),
                }
            })
        });
    }

    fn fetch_drive(&mut self, folder_id: Option<String>) {
        self.file.loading = true;
        let folder_clone = folder_id.clone();
        self.spawn(move |api| async move {
            let res = api
                .drive_list(folder_clone, 0, "time_desc", "", "current")
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

    fn handle_api_err(&mut self, label: &str, e: anyhow::Error) {
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
        // group picker — only outside of the note editor
        if key.code == KeyCode::Char('g')
            && key.modifiers.is_empty()
            && !matches!(self.notes.detail, Some(NoteDetail::Edit { .. }))
        {
            self.open_group_picker();
            return;
        }
        // tab switching via numbers
        if let KeyCode::Char(c) = key.code
            && key.modifiers.is_empty()
            && self.notes.detail.is_none()
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
        }
    }

    // ─── Login ────────────────────────────────────────────────────────

    fn handle_login_key(&mut self, key: KeyEvent) {
        if self.login.submitting {
            return;
        }
        match key.code {
            KeyCode::Esc => {
                self.should_quit = true;
            }
            KeyCode::Tab | KeyCode::Down => self.login.focus = (self.login.focus + 1) % 2,
            KeyCode::BackTab | KeyCode::Up => self.login.focus = (self.login.focus + 1) % 2,
            KeyCode::Enter => {
                if !self.login.username.is_empty() && !self.login.password.is_empty() {
                    self.submit_login();
                } else {
                    self.login.error = Some("请输入用户名和密码".into());
                }
            }
            KeyCode::Backspace => {
                let buf = if self.login.focus == 0 {
                    &mut self.login.username
                } else {
                    &mut self.login.password
                };
                buf.pop();
            }
            KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                let buf = if self.login.focus == 0 {
                    &mut self.login.username
                } else {
                    &mut self.login.password
                };
                buf.push(c);
            }
            _ => {}
        }
    }

    fn submit_login(&mut self) {
        self.login.submitting = true;
        self.login.error = None;
        let user = self.login.username.clone();
        let pass = self.login.password.clone();
        self.spawn(move |api| async move {
            let res = api.login(&user, &pass).await;
            Box::new(move |app: &mut App| {
                app.login.submitting = false;
                match res {
                    Ok(r) if r.success => {
                        if let Some(token) = r.token {
                            app.api.set_token(Some(token.clone()));
                            let _ = app.config.set_token(Some(token));
                        }
                        if let Some(u) = r.user {
                            app.username = Some(u.name);
                        }
                        app.authenticated = true;
                        app.login = LoginState::default();
                        app.after_login();
                    }
                    Ok(r) => {
                        app.login.error =
                            Some(r.message.unwrap_or_else(|| "登录失败".into()));
                    }
                    Err(e) => {
                        app.login.error = Some(format!("网络错误: {e}"));
                    }
                }
            })
        });
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
                                                let _ = api
                                                    .add_tag_to_note(&nid2, tid)
                                                    .await;
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
                        KeyCode::Char(c)
                            if !key.modifiers.contains(KeyModifiers::CONTROL) =>
                        {
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
            None => {}
        }
    }

    // ─── Timeline ─────────────────────────────────────────────────────

    fn handle_timeline_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('q') => self.should_quit = true,
            KeyCode::Char('r') => self.fetch_timeline(0),
            KeyCode::Up | KeyCode::Char('k') => {
                if self.timeline.cursor > 0 {
                    self.timeline.cursor -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.timeline.cursor + 1 < self.timeline.items.len() {
                    self.timeline.cursor += 1;
                }
                if self.timeline.cursor + 5 >= self.timeline.items.len()
                    && !self.timeline.end
                    && !self.timeline.loading
                {
                    let next = self.timeline.page + 1;
                    self.fetch_timeline(next);
                }
            }
            KeyCode::PageDown => {
                self.timeline.cursor =
                    (self.timeline.cursor + 10).min(self.timeline.items.len().saturating_sub(1));
            }
            KeyCode::PageUp => {
                self.timeline.cursor = self.timeline.cursor.saturating_sub(10);
            }
            _ => {}
        }
    }

    // ─── Notes ────────────────────────────────────────────────────────

    fn handle_notes_key(&mut self, key: KeyEvent) {
        // Detail screen handling first
        if self.notes.detail.is_some() {
            self.handle_note_detail_key(key);
            return;
        }
        match key.code {
            KeyCode::Char('q') => self.should_quit = true,
            KeyCode::Char('r') => {
                self.fetch_notes(0);
                self.fetch_note_tags();
            }
            KeyCode::Char('n') => self.start_create_note(),
            KeyCode::Char('t') => self.cycle_tag_filter(),
            KeyCode::Char('d') => {
                if let Some(item) = self.notes.items.get(self.notes.cursor) {
                    let id = item.id.clone();
                    let title = item.title.clone();
                    self.modal = Some(Modal::Confirm {
                        prompt: format!("删除笔记「{title}」？"),
                        on_yes: Box::new(move |app: &mut App| {
                            app.spawn(move |api| async move {
                                let r = api.delete_note(&id).await;
                                Box::new(move |app: &mut App| match r {
                                    Ok(_) => {
                                        app.set_status("已删除", false);
                                        app.fetch_notes(0);
                                    }
                                    Err(e) => app.handle_api_err("删除笔记", e),
                                })
                            });
                        }),
                    });
                }
            }
            KeyCode::Up | KeyCode::Char('k') => {
                if self.notes.cursor > 0 {
                    self.notes.cursor -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.notes.cursor + 1 < self.notes.items.len() {
                    self.notes.cursor += 1;
                }
                if self.notes.cursor + 5 >= self.notes.items.len() && !self.notes.loading {
                    let next = self.notes.page + 1;
                    self.fetch_notes(next);
                }
            }
            KeyCode::Enter => {
                if let Some(item) = self.notes.items.get(self.notes.cursor) {
                    let id = item.id.clone();
                    self.fetch_note_detail(id);
                }
            }
            _ => {}
        }
    }

    fn cycle_tag_filter(&mut self) {
        if self.notes.tags.is_empty() {
            return;
        }
        let next = match self.notes.active_tag {
            None => Some(self.notes.tags[0].id),
            Some(id) => {
                let pos = self.notes.tags.iter().position(|t| t.id == id);
                match pos {
                    Some(i) if i + 1 < self.notes.tags.len() => Some(self.notes.tags[i + 1].id),
                    _ => None,
                }
            }
        };
        self.notes.active_tag = next;
        self.fetch_notes(0);
    }

    fn start_create_note(&mut self) {
        let mut ta = TextArea::default();
        ta.set_cursor_line_style(ratatui::style::Style::default());
        self.notes.detail = Some(NoteDetail::Edit {
            id: None,
            title: String::new(),
            title_focus: true,
            textarea: ta,
            original_tags: vec![],
        });
    }

    fn handle_note_detail_key(&mut self, key: KeyEvent) {
        let detail = self.notes.detail.take();
        match detail {
            Some(NoteDetail::Loading(id)) => {
                if matches!(key.code, KeyCode::Esc | KeyCode::Char('q')) {
                    // cancel loading
                } else {
                    self.notes.detail = Some(NoteDetail::Loading(id));
                }
            }
            Some(NoteDetail::View { note, tags }) => match key.code {
                KeyCode::Esc | KeyCode::Char('q') => {}
                KeyCode::Char('e') => {
                    let mut ta = TextArea::from(note.content.lines());
                    ta.set_cursor_line_style(ratatui::style::Style::default());
                    self.notes.detail = Some(NoteDetail::Edit {
                        id: Some(note.id.clone()),
                        title: note.title.clone(),
                        title_focus: false,
                        textarea: ta,
                        original_tags: tags,
                    });
                }
                KeyCode::Char('t') => {
                    let id = note.id.clone();
                    let selected: std::collections::HashSet<i64> =
                        tags.iter().map(|t| t.id).collect();
                    let all = self.notes.tags.clone();
                    self.modal = Some(Modal::TagPicker {
                        note_id: id,
                        all,
                        selected,
                        cursor: 0,
                        new_input: String::new(),
                        new_input_focus: false,
                    });
                    self.notes.detail = Some(NoteDetail::View { note, tags });
                }
                KeyCode::Up | KeyCode::Char('k') => {
                    self.notes.detail = Some(NoteDetail::View { note, tags });
                }
                KeyCode::Down | KeyCode::Char('j') => {
                    self.notes.detail = Some(NoteDetail::View { note, tags });
                }
                _ => self.notes.detail = Some(NoteDetail::View { note, tags }),
            },
            Some(NoteDetail::Edit {
                id,
                mut title,
                mut title_focus,
                mut textarea,
                original_tags,
            }) => match key.code {
                KeyCode::Esc => {
                    self.modal = Some(Modal::Confirm {
                        prompt: "放弃当前编辑？".to_string(),
                        on_yes: Box::new(|app: &mut App| {
                            app.notes.detail = None;
                        }),
                    });
                    self.notes.detail = Some(NoteDetail::Edit {
                        id,
                        title,
                        title_focus,
                        textarea,
                        original_tags,
                    });
                }
                KeyCode::Char('s') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                    let title_now = title.clone();
                    let content_now = textarea.lines().join("\n");
                    let id_now = id.clone();
                    self.spawn(move |api| async move {
                        let r = match id_now {
                            Some(id) => api.update_note(&id, &title_now, &content_now).await,
                            None => api.create_note(&title_now, &content_now).await,
                        };
                        Box::new(move |app: &mut App| match r {
                            Ok(n) => {
                                app.set_status("已保存", false);
                                app.notes.detail = Some(NoteDetail::View {
                                    note: n,
                                    tags: vec![],
                                });
                                app.fetch_notes(0);
                            }
                            Err(e) => {
                                app.handle_api_err("保存笔记", e);
                            }
                        })
                    });
                    self.notes.detail = Some(NoteDetail::Edit {
                        id,
                        title,
                        title_focus,
                        textarea,
                        original_tags,
                    });
                }
                KeyCode::Tab => {
                    title_focus = !title_focus;
                    self.notes.detail = Some(NoteDetail::Edit {
                        id,
                        title,
                        title_focus,
                        textarea,
                        original_tags,
                    });
                }
                _ => {
                    if title_focus {
                        match key.code {
                            KeyCode::Backspace => {
                                title.pop();
                            }
                            KeyCode::Char(c)
                                if !key.modifiers.contains(KeyModifiers::CONTROL) =>
                            {
                                title.push(c);
                            }
                            KeyCode::Enter => {
                                title_focus = false;
                            }
                            _ => {}
                        }
                    } else {
                        let input: Input = key_to_input(key);
                        textarea.input(input);
                    }
                    self.notes.detail = Some(NoteDetail::Edit {
                        id,
                        title,
                        title_focus,
                        textarea,
                        original_tags,
                    });
                }
            },
            None => {}
        }
    }

    // ─── Todo ─────────────────────────────────────────────────────────

    fn handle_todo_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('q') => self.should_quit = true,
            KeyCode::Char('r') => self.fetch_todo_lists(),
            KeyCode::Tab | KeyCode::Char('h') | KeyCode::Char('l') => {
                self.todo.focus_items = !self.todo.focus_items;
            }
            KeyCode::Up | KeyCode::Char('k') => {
                if self.todo.focus_items {
                    if self.todo.item_cursor > 0 {
                        self.todo.item_cursor -= 1;
                    }
                } else if self.todo.list_cursor > 0 {
                    self.todo.list_cursor -= 1;
                    self.load_active_todo_items();
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.todo.focus_items {
                    if self.todo.item_cursor + 1 < self.todo.items.len() {
                        self.todo.item_cursor += 1;
                    }
                } else if self.todo.list_cursor + 1 < self.todo.lists.len() {
                    self.todo.list_cursor += 1;
                    self.load_active_todo_items();
                }
            }
            KeyCode::Enter => {
                if self.todo.focus_items {
                    if let Some(item) = self.todo.items.get(self.todo.item_cursor) {
                        let id = item.id.clone();
                        let new_done = if item.done == 0 { 1 } else { 0 };
                        let list_id = item.list_id.clone();
                        self.spawn(move |api| async move {
                            let r = api
                                .update_todo_item(&id, None, None, Some(new_done))
                                .await;
                            Box::new(move |app: &mut App| match r {
                                Ok(_) => {
                                    app.fetch_todo_items(list_id);
                                }
                                Err(e) => app.handle_api_err("更新待办", e),
                            })
                        });
                    }
                } else {
                    // open the list (focus right pane)
                    self.todo.focus_items = true;
                }
            }
            KeyCode::Char('n') => {
                if self.todo.focus_items {
                    if let Some(list) = self.todo.lists.get(self.todo.list_cursor) {
                        let lid = list.id.clone();
                        self.modal = Some(Modal::Input {
                            title: "新建待办".into(),
                            prompt: "标题".into(),
                            value: String::new(),
                            on_submit: Box::new(move |app: &mut App, val: String| {
                                if val.trim().is_empty() {
                                    return;
                                }
                                let lid2 = lid.clone();
                                app.spawn(move |api| async move {
                                    let r = api
                                        .create_todo_item(&lid2, val.trim(), "")
                                        .await;
                                    Box::new(move |app: &mut App| match r {
                                        Ok(_) => app.fetch_todo_items(lid2),
                                        Err(e) => app.handle_api_err("新建待办", e),
                                    })
                                });
                            }),
                        });
                    }
                } else {
                    self.modal = Some(Modal::Input {
                        title: "新建列表".into(),
                        prompt: "名称".into(),
                        value: String::new(),
                        on_submit: Box::new(|app: &mut App, val: String| {
                            if val.trim().is_empty() {
                                return;
                            }
                            app.spawn(move |api| async move {
                                let r = api.create_todo_list(val.trim(), "#9e9e9e").await;
                                Box::new(move |app: &mut App| match r {
                                    Ok(_) => app.fetch_todo_lists(),
                                    Err(e) => app.handle_api_err("新建列表", e),
                                })
                            });
                        }),
                    });
                }
            }
            KeyCode::Char('e') => {
                if self.todo.focus_items {
                    if let Some(item) = self.todo.items.get(self.todo.item_cursor).cloned() {
                        let id = item.id.clone();
                        let list_id = item.list_id.clone();
                        self.modal = Some(Modal::Input {
                            title: "编辑待办标题".into(),
                            prompt: "标题".into(),
                            value: item.title,
                            on_submit: Box::new(move |app: &mut App, val: String| {
                                if val.trim().is_empty() {
                                    return;
                                }
                                let lid = list_id.clone();
                                app.spawn(move |api| async move {
                                    let r = api
                                        .update_todo_item(&id, Some(val.trim()), None, None)
                                        .await;
                                    Box::new(move |app: &mut App| match r {
                                        Ok(_) => app.fetch_todo_items(lid),
                                        Err(e) => app.handle_api_err("更新待办", e),
                                    })
                                });
                            }),
                        });
                    }
                } else if let Some(list) = self.todo.lists.get(self.todo.list_cursor).cloned() {
                    let id = list.id.clone();
                    self.modal = Some(Modal::Input {
                        title: "重命名列表".into(),
                        prompt: "名称".into(),
                        value: list.name,
                        on_submit: Box::new(move |app: &mut App, val: String| {
                            if val.trim().is_empty() {
                                return;
                            }
                            app.spawn(move |api| async move {
                                let r = api.update_todo_list(&id, Some(val.trim()), None).await;
                                Box::new(move |app: &mut App| match r {
                                    Ok(_) => app.fetch_todo_lists(),
                                    Err(e) => app.handle_api_err("重命名列表", e),
                                })
                            });
                        }),
                    });
                }
            }
            KeyCode::Char('d') => {
                if self.todo.focus_items {
                    if let Some(item) = self.todo.items.get(self.todo.item_cursor) {
                        let id = item.id.clone();
                        let list_id = item.list_id.clone();
                        let title = item.title.clone();
                        self.modal = Some(Modal::Confirm {
                            prompt: format!("删除待办「{title}」？"),
                            on_yes: Box::new(move |app: &mut App| {
                                let lid = list_id.clone();
                                app.spawn(move |api| async move {
                                    let r = api.delete_todo_item(&id).await;
                                    Box::new(move |app: &mut App| match r {
                                        Ok(_) => app.fetch_todo_items(lid),
                                        Err(e) => app.handle_api_err("删除待办", e),
                                    })
                                });
                            }),
                        });
                    }
                } else if let Some(list) = self.todo.lists.get(self.todo.list_cursor).cloned() {
                    let id = list.id.clone();
                    let name = list.name;
                    self.modal = Some(Modal::Confirm {
                        prompt: format!("删除列表「{name}」（含所有待办）？"),
                        on_yes: Box::new(move |app: &mut App| {
                            app.spawn(move |api| async move {
                                let r = api.delete_todo_list(&id).await;
                                Box::new(move |app: &mut App| match r {
                                    Ok(_) => app.fetch_todo_lists(),
                                    Err(e) => app.handle_api_err("删除列表", e),
                                })
                            });
                        }),
                    });
                }
            }
            _ => {}
        }
    }

    fn load_active_todo_items(&mut self) {
        if let Some(list) = self.todo.lists.get(self.todo.list_cursor) {
            let id = list.id.clone();
            self.fetch_todo_items(id);
        }
    }

    // ─── Image ────────────────────────────────────────────────────────

    fn handle_image_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('q') => self.should_quit = true,
            KeyCode::Char('r') => self.fetch_images(0),
            KeyCode::Up | KeyCode::Char('k') => {
                if self.image.cursor > 0 {
                    self.image.cursor -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.image.cursor + 1 < self.image.items.len() {
                    self.image.cursor += 1;
                }
                if self.image.cursor + 5 >= self.image.items.len()
                    && !self.image.end
                    && !self.image.loading
                {
                    let next = self.image.page + 1;
                    self.fetch_images(next);
                }
            }
            KeyCode::Char('/') => {
                let cur = self.image.search.clone();
                self.modal = Some(Modal::Input {
                    title: "搜索图片".into(),
                    prompt: "关键词".into(),
                    value: cur,
                    on_submit: Box::new(|app: &mut App, val: String| {
                        app.image.search = val;
                        app.fetch_images(0);
                    }),
                });
            }
            KeyCode::Char('y') => {
                if let Some(it) = self.image.items.get(self.image.cursor) {
                    let url = it.url.clone();
                    self.set_status(format!("URL: {url}"), false);
                }
            }
            KeyCode::Char('e') | KeyCode::Char('R') => {
                if let Some(it) = self.image.items.get(self.image.cursor).cloned() {
                    let id = it.id;
                    self.modal = Some(Modal::Input {
                        title: "重命名图片".into(),
                        prompt: "新名称".into(),
                        value: it.name,
                        on_submit: Box::new(move |app: &mut App, val: String| {
                            if val.trim().is_empty() {
                                return;
                            }
                            app.spawn(move |api| async move {
                                let r = api.rename_image(id, val.trim()).await;
                                Box::new(move |app: &mut App| match r {
                                    Ok(_) => {
                                        app.set_status("已重命名", false);
                                        app.fetch_images(0);
                                    }
                                    Err(e) => app.handle_api_err("重命名图片", e),
                                })
                            });
                        }),
                    });
                }
            }
            _ => {}
        }
    }

    // ─── File / drive ─────────────────────────────────────────────────

    fn handle_file_key(&mut self, key: KeyEvent) {
        let total = self.file.folders.len() + self.file.files.len();
        match key.code {
            KeyCode::Char('q') => self.should_quit = true,
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
                } else {
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
}

fn key_to_input(key: KeyEvent) -> Input {
    let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
    let alt = key.modifiers.contains(KeyModifiers::ALT);
    let shift = key.modifiers.contains(KeyModifiers::SHIFT);
    let k = match key.code {
        KeyCode::Char(c) => TaKey::Char(c),
        KeyCode::Backspace => TaKey::Backspace,
        KeyCode::Enter => TaKey::Enter,
        KeyCode::Left => TaKey::Left,
        KeyCode::Right => TaKey::Right,
        KeyCode::Up => TaKey::Up,
        KeyCode::Down => TaKey::Down,
        KeyCode::Tab => TaKey::Tab,
        KeyCode::Delete => TaKey::Delete,
        KeyCode::Home => TaKey::Home,
        KeyCode::End => TaKey::End,
        KeyCode::PageUp => TaKey::PageUp,
        KeyCode::PageDown => TaKey::PageDown,
        KeyCode::Esc => TaKey::Esc,
        _ => TaKey::Null,
    };
    Input {
        key: k,
        ctrl,
        alt,
        shift,
    }
}

pub async fn run(api: ApiClient, config: AppConfig) -> Result<()> {
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
    crate::event::spawn_input_loop(tx.clone());
    crate::event::spawn_tick_loop(tx.clone(), Duration::from_millis(100));

    let mut app = App::new(api, config, tx);
    app.boot();

    let result: Result<()> = loop {
        if let Err(e) = terminal.draw(|f| crate::ui::render(f, &app)) {
            break Err(e.into());
        }
        match rx.recv().await {
            Some(msg) => app.update(msg),
            None => break Ok(()),
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
