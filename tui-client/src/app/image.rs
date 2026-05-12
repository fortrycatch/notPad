use crossterm::event::{KeyCode, KeyEvent};

use super::{App, Modal};
use crate::api::dto::ImageItem;

#[derive(Debug, Default)]
pub struct ImageState {
    pub items: Vec<ImageItem>,
    pub cursor: usize,
    pub page: u32,
    pub search: String,
    pub loading: bool,
    pub end: bool,
}

impl App {
    pub(super) fn fetch_images(&mut self, page: u32) {
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

    pub(super) fn handle_image_key(&mut self, key: KeyEvent) {
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
}
