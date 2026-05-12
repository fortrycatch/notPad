use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

use crate::api::dto::{AuthTokenRow, UsageStats};

use super::{
    App, FileState, ImageState, LoginState, Modal, NotesState, Tab, TimelineState, TodoState,
};

/// Built-in color presets shown in the settings tab. Mirrors the same set
/// the web client offers under Settings → 主题色 so the two clients feel
/// like the same product.
pub const COLOR_PRESETS: &[(&str, &str)] = &[
    ("猛男粉", "#ff9edd"),
    ("胖次蓝", "#00a1d6"),
    ("早苗绿", "#43a047"),
    ("咸蛋黄", "#ffb300"),
    ("基佬紫", "#7b1fa2"),
    ("姨妈红", "#d32f2f"),
    ("高级黑", "#455a64"),
    ("原谅绿", "#8bc34a"),
    ("土豪金", "#c0a060"),
    ("橙汁儿", "#ff9800"),
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SettingsSection {
    Theme,
    Download,
    Account,
}

impl SettingsSection {
    pub const ALL: [SettingsSection; 3] = [
        SettingsSection::Theme,
        SettingsSection::Download,
        SettingsSection::Account,
    ];

    pub fn label(self) -> &'static str {
        match self {
            SettingsSection::Theme => "主题色",
            SettingsSection::Download => "下载",
            SettingsSection::Account => "账户",
        }
    }
}

#[derive(Debug, Default)]
pub struct SettingsState {
    pub section_cursor: usize,
    pub focus_right: bool,
    pub action_cursor: usize,
    pub custom_input: String,
    pub editing_custom: bool,
    pub saving: bool,
    /// Personal scope only; cleared when switching to a group.
    pub usage: Option<UsageStats>,
    pub usage_loading: bool,
    pub usage_recalculating: bool,
    pub tokens: Vec<AuthTokenRow>,
    pub tokens_loading: bool,
}

impl SettingsState {
    pub fn current_section(&self) -> SettingsSection {
        SettingsSection::ALL[self.section_cursor.min(SettingsSection::ALL.len() - 1)]
    }
}

impl App {
    /// Total interactive rows on the right pane for the given settings
    /// section. Theme = `[N presets] + [custom hex] + [reset]`,
    /// Download = `[编辑下载目录] + [恢复默认]`，
    /// Account (personal) = `[重新统计]` + `[退出登录]` + `[每个登录会话]`，
    /// 群组空间下与网页一致，仅保留退出登录。
    pub fn settings_action_count(&self, section: SettingsSection) -> usize {
        match section {
            SettingsSection::Theme => COLOR_PRESETS.len() + 2,
            SettingsSection::Download => 2,
            SettingsSection::Account => {
                if self.active_group_id.is_some() {
                    1
                } else {
                    1 + self.settings.tokens.len() + 1
                }
            }
        }
    }

    /// Load usage stats + auth tokens for the account pane (personal scope only).
    pub(crate) fn fetch_settings_account_data(&mut self) {
        if self.active_group_id.is_some() {
            self.settings.usage = None;
            self.settings.usage_loading = false;
            self.settings.usage_recalculating = false;
            self.settings.tokens.clear();
            self.settings.tokens_loading = false;
            self.clamp_account_action_cursor();
            return;
        }
        self.settings.usage_loading = true;
        self.settings.tokens_loading = true;
        self.spawn(move |api| async move {
            let u = api.get_usage_stats().await;
            let t = api.get_tokens().await;
            Box::new(move |app: &mut App| {
                app.settings.usage_loading = false;
                app.settings.tokens_loading = false;
                match u {
                    Ok(s) => app.settings.usage = Some(s),
                    Err(e) => app.handle_api_err("用量统计", e),
                }
                match t {
                    Ok(list) => {
                        app.settings.tokens = list;
                        app.clamp_account_action_cursor();
                    }
                    Err(e) => app.handle_api_err("会话列表", e),
                }
            })
        });
    }

    fn refresh_settings_tokens(&mut self) {
        if self.active_group_id.is_some() {
            return;
        }
        self.spawn(move |api| async move {
            let r = api.get_tokens().await;
            Box::new(move |app: &mut App| match r {
                Ok(list) => {
                    app.settings.tokens = list;
                    app.clamp_account_action_cursor();
                }
                Err(e) => app.handle_api_err("会话列表", e),
            })
        });
    }

    fn clamp_account_action_cursor(&mut self) {
        let total = self.settings_action_count(SettingsSection::Account);
        let max = total.saturating_sub(1);
        if self.settings.action_cursor > max {
            self.settings.action_cursor = max;
        }
    }

    /// Cursor row → device index（个人空间：0=重新统计，1=退出登录，2..=设备）。
    fn account_device_index_at_cursor(&self) -> Option<usize> {
        if self.active_group_id.is_some() {
            return None;
        }
        let c = self.settings.action_cursor;
        let n = self.settings.tokens.len();
        if c < 2 || c > n + 1 {
            return None;
        }
        Some(c - 2)
    }

    fn trigger_usage_recalculate(&mut self) {
        if self.settings.usage_recalculating || self.active_group_id.is_some() {
            return;
        }
        self.settings.usage_recalculating = true;
        self.spawn(move |api| async move {
            let r = api.recalculate_usage_stats().await;
            Box::new(move |app: &mut App| {
                app.settings.usage_recalculating = false;
                match r {
                    Ok(s) => {
                        app.settings.usage = Some(s);
                        app.set_status("已重新统计用量", false);
                    }
                    Err(e) => app.handle_api_err("重新统计用量", e),
                }
            })
        });
    }

    fn open_rename_token_dialog(&mut self, token_hash: String, current_alias: String) {
        self.modal = Some(Modal::Input {
            title: "重命名会话".to_string(),
            prompt: "显示名称（留空清除）".to_string(),
            value: current_alias,
            on_submit: Box::new(move |app, name| {
                let trimmed = name.trim().to_string();
                let hash = token_hash.clone();
                app.spawn(move |api| async move {
                    let r = api
                        .set_token_alias(
                            &hash,
                            if trimmed.is_empty() {
                                None
                            } else {
                                Some(trimmed.as_str())
                            },
                        )
                        .await;
                    Box::new(move |app: &mut App| match r {
                        Ok(_) => {
                            app.set_status("会话名称已更新", false);
                            app.refresh_settings_tokens();
                        }
                        Err(e) => app.handle_api_err("重命名会话", e),
                    })
                });
            }),
        });
    }

    fn ask_revoke_token(&mut self, token_hash: String) {
        self.modal = Some(Modal::Confirm {
            prompt: "移除此会话？该设备需重新登录。".to_string(),
            on_yes: Box::new(move |app: &mut App| {
                let hash = token_hash.clone();
                app.spawn(move |api| async move {
                    let r = api.revoke_token(&hash).await;
                    Box::new(move |app: &mut App| match r {
                        Ok(_) => {
                            app.set_status("会话已移除", false);
                            app.refresh_settings_tokens();
                        }
                        Err(e) => app.handle_api_err("移除会话", e),
                    })
                });
            }),
        });
    }

    fn open_logout_confirm(&mut self) {
        self.modal = Some(Modal::Confirm {
            prompt: "退出登录并清除本机 token？".to_string(),
            on_yes: Box::new(|app: &mut App| {
                app.logout();
            }),
        });
    }

    pub(super) fn handle_settings_key(&mut self, key: KeyEvent) {
        // Custom-hex editing eats most keys until Esc / Enter, regardless of
        // which pane is focused.
        if self.settings.editing_custom {
            match key.code {
                KeyCode::Esc => {
                    self.settings.editing_custom = false;
                }
                KeyCode::Enter => {
                    let raw = self.settings.custom_input.trim().to_string();
                    if let Some(hex) = normalize_hex(&raw) {
                        self.settings.editing_custom = false;
                        self.save_primary_color(Some(hex));
                    } else {
                        self.set_status("色值格式无效，应为 #rrggbb 或 #rgb", true);
                    }
                }
                KeyCode::Backspace => {
                    self.settings.custom_input.pop();
                }
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                    if self.settings.custom_input.chars().count() < 7 {
                        self.settings.custom_input.push(c);
                    }
                }
                _ => {}
            }
            return;
        }

        // Global-ish bindings that work in both panes.
        match key.code {
            KeyCode::Char('q') => {
                self.should_quit = true;
                return;
            }
            KeyCode::Char('r') => {
                self.refresh_current_tab();
                return;
            }
            KeyCode::Tab => {
                self.settings.focus_right = !self.settings.focus_right;
                return;
            }
            _ => {}
        }

        if self.settings.focus_right {
            self.handle_settings_right_key(key);
        } else {
            self.handle_settings_left_key(key);
        }
    }

    fn handle_settings_left_key(&mut self, key: KeyEvent) {
        let sections = SettingsSection::ALL.len();
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                if self.settings.section_cursor > 0 {
                    self.settings.section_cursor -= 1;
                    self.settings.action_cursor = 0;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.settings.section_cursor + 1 < sections {
                    self.settings.section_cursor += 1;
                    self.settings.action_cursor = 0;
                }
            }
            // Right / l / Enter all jump focus into the content pane, mimicking
            // how the todo tab moves between lists ↔ items.
            KeyCode::Right
            | KeyCode::Char('l')
            | KeyCode::Enter
            | KeyCode::Char(' ') => {
                self.settings.focus_right = true;
            }
            _ => {}
        }
    }

    fn handle_settings_right_key(&mut self, key: KeyEvent) {
        let section = self.settings.current_section();

        if section == SettingsSection::Account
            && self.active_group_id.is_none()
            && matches!(key.code, KeyCode::Char('d') | KeyCode::Char('D'))
            && key.modifiers.is_empty()
        {
            if let Some(idx) = self.account_device_index_at_cursor() {
                let hash = self.settings.tokens[idx].token.clone();
                self.ask_revoke_token(hash);
            }
            return;
        }

        let total = self.settings_action_count(section);

        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                if self.settings.action_cursor > 0 {
                    self.settings.action_cursor -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.settings.action_cursor + 1 < total {
                    self.settings.action_cursor += 1;
                }
            }
            KeyCode::Left | KeyCode::Char('h') | KeyCode::Esc => {
                self.settings.focus_right = false;
            }
            KeyCode::Enter | KeyCode::Char(' ') => match section {
                SettingsSection::Theme => self.activate_theme_action(),
                SettingsSection::Download => self.activate_download_action(),
                SettingsSection::Account => self.activate_account_action(),
            },
            _ => {}
        }
    }

    fn activate_theme_action(&mut self) {
        let cur = self.settings.action_cursor;
        let presets_end = COLOR_PRESETS.len();
        let custom_idx = presets_end;
        let reset_idx = presets_end + 1;

        if cur < presets_end {
            let hex = COLOR_PRESETS[cur].1.to_string();
            self.save_primary_color(Some(hex));
        } else if cur == custom_idx {
            self.settings.editing_custom = true;
        } else if cur == reset_idx {
            self.save_primary_color(None);
        }
    }

    fn activate_download_action(&mut self) {
        match self.settings.action_cursor {
            0 => {
                let current = self.config.download_dir.clone().unwrap_or_default();
                self.modal = Some(Modal::Input {
                    title: "下载目录".to_string(),
                    prompt: "绝对路径（留空使用系统 Downloads）".to_string(),
                    value: current,
                    on_submit: Box::new(|app: &mut App, val: String| {
                        let trimmed = val.trim().to_string();
                        let value = if trimmed.is_empty() { None } else { Some(trimmed) };
                        match app.config.set_download_dir(value) {
                            Ok(()) => app.set_status(
                                if app.config.download_dir.is_some() {
                                    format!(
                                        "已保存下载目录: {}",
                                        app.config.download_dir.as_deref().unwrap_or("")
                                    )
                                } else {
                                    "已恢复默认下载目录".to_string()
                                },
                                false,
                            ),
                            Err(e) => app.set_status(format!("保存下载目录失败: {e}"), true),
                        }
                    }),
                });
            }
            1 => match self.config.set_download_dir(None) {
                Ok(()) => self.set_status("已恢复默认下载目录", false),
                Err(e) => self.set_status(format!("保存下载目录失败: {e}"), true),
            },
            _ => {}
        }
    }

    fn activate_account_action(&mut self) {
        if self.active_group_id.is_some() {
            if self.settings.action_cursor == 0 {
                self.open_logout_confirm();
            }
            return;
        }

        let c = self.settings.action_cursor;
        if c == 0 {
            self.trigger_usage_recalculate();
            return;
        }
        if c == 1 {
            self.open_logout_confirm();
            return;
        }
        let n = self.settings.tokens.len();
        if (2..=n + 1).contains(&c) {
            let row = &self.settings.tokens[c - 2];
            let hash = row.token.clone();
            let alias = row.alias.clone().unwrap_or_default();
            self.open_rename_token_dialog(hash, alias);
        }
    }

    /// Persist `primaryColor` for the currently active scope. `None` clears
    /// the override and falls back to the default (matches the web client's
    /// "恢复默认" behavior, which sends `primaryColor: ""`).
    fn save_primary_color(&mut self, hex: Option<String>) {
        if self.settings.saving {
            return;
        }
        self.settings.saving = true;
        let value = hex.clone().unwrap_or_default();
        let meta = serde_json::json!({ "primaryColor": value });

        match self.active_group_id.clone() {
            Some(group_id) => {
                self.spawn(move |api| async move {
                    let r = api.update_group_meta(&group_id, &meta).await;
                    Box::new(move |app: &mut App| {
                        app.settings.saving = false;
                        match r {
                            Ok(_) => {
                                let stored = if value.is_empty() { None } else { Some(value) };
                                if let Some(g) = app
                                    .groups
                                    .iter_mut()
                                    .find(|g| g.id == group_id)
                                {
                                    let m = g.meta.get_or_insert_with(Default::default);
                                    m.primary_color = stored.clone();
                                }
                                app.set_status(
                                    if stored.is_some() {
                                        "已保存群组主题色"
                                    } else {
                                        "已恢复默认主题色"
                                    },
                                    false,
                                );
                            }
                            Err(e) => app.handle_api_err("保存主题色", e),
                        }
                    })
                });
            }
            None => {
                self.spawn(move |api| async move {
                    let r = api.update_user_meta(&meta).await;
                    Box::new(move |app: &mut App| {
                        app.settings.saving = false;
                        match r {
                            Ok(_) => {
                                app.user_primary_color =
                                    if value.is_empty() { None } else { Some(value) };
                                app.set_status(
                                    if app.user_primary_color.is_some() {
                                        "已保存个人主题色"
                                    } else {
                                        "已恢复默认主题色"
                                    },
                                    false,
                                );
                            }
                            Err(e) => app.handle_api_err("保存主题色", e),
                        }
                    })
                });
            }
        }
    }

    /// Drop the local session: wipe token + active group from both the
    /// runtime API client and the on-disk config, reset all per-tab caches,
    /// and bounce the user back to the login screen.
    fn logout(&mut self) {
        self.api.set_token(None);
        let _ = self.config.set_token(None);
        self.api.set_group(None);
        let _ = self.config.set_active_group(None);

        self.authenticated = false;
        self.username = None;
        self.active_group_id = None;
        self.active_group_name = None;
        self.user_primary_color = None;
        self.groups.clear();

        self.tab = Tab::Timeline;
        self.timeline = TimelineState::default();
        self.notes = NotesState::default();
        self.todo = TodoState::default();
        self.image = ImageState::default();
        self.file = FileState::default();
        self.settings = SettingsState::default();
        self.login = LoginState::default();
        self.modal = None;

        self.set_status("已退出登录", false);
    }
}

/// Normalize a user-typed hex color: trims whitespace, accepts an optional
/// leading `#`, and expands `#rgb` to `#rrggbb`. Returns `None` for any
/// non-hex input so callers can show a validation error.
fn normalize_hex(input: &str) -> Option<String> {
    let s = input.trim();
    let s = s.strip_prefix('#').unwrap_or(s);
    if !s.chars().all(|c| c.is_ascii_hexdigit()) {
        return None;
    }
    match s.len() {
        3 => {
            let mut out = String::with_capacity(7);
            out.push('#');
            for c in s.chars() {
                out.push(c);
                out.push(c);
            }
            Some(out.to_ascii_lowercase())
        }
        6 => Some(format!("#{}", s.to_ascii_lowercase())),
        _ => None,
    }
}
