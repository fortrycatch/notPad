use crossterm::event::{KeyCode, KeyEvent};

use super::{App, Modal};
use crate::api::dto::{TodoItem, TodoList};

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

impl App {
    pub(super) fn fetch_todo_lists(&mut self) {
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

    pub(super) fn handle_todo_key(&mut self, key: KeyEvent) {
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
}
