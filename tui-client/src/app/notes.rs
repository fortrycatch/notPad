use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui_textarea::{Input, Key as TaKey, TextArea};

use super::{App, Modal};
use crate::api::dto::{Note, NoteListItem, NoteTag};

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

impl App {
    pub(super) fn fetch_notes(&mut self, page: u32) {
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

    pub(super) fn fetch_note_tags(&mut self) {
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

    pub(super) fn handle_notes_key(&mut self, key: KeyEvent) {
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
                            KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
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
