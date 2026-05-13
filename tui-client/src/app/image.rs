use crossterm::event::{KeyCode, KeyEvent};
use ratatui_image::thread::{ResizeResponse, ThreadProtocol};

use super::{App, Modal, Msg};
use crate::api::dto::ImageItem;

const IMAGE_HOST: &str = "https://monika.jkloli.net/";
const IMAGE_THUMBNAIL_PROCESS: &str = "x-oss-process=image/resize,w_200";

pub(crate) fn full_image_url(url: &str) -> String {
    if url.starts_with("http") {
        url.to_string()
    } else {
        format!("{IMAGE_HOST}{url}")
    }
}

pub(crate) fn thumbnail_image_url(url: &str) -> String {
    let full = full_image_url(url);
    let sep = if full.contains('?') { '&' } else { '?' };
    format!("{full}{sep}{IMAGE_THUMBNAIL_PROCESS}")
}

#[derive(Default)]
pub struct ImageState {
    pub items: Vec<ImageItem>,
    pub cursor: usize,
    pub page: u32,
    pub search: String,
    pub loading: bool,
    pub end: bool,
    pub preview_url: Option<String>,
    pub preview_title: Option<String>,
    pub preview_loading: bool,
    pub preview_error: Option<String>,
    pub preview_generation: u64,
    pub preview_protocol: Option<ThreadProtocol>,
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
                        app.sync_image_preview();
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
                    self.sync_image_preview();
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.image.cursor + 1 < self.image.items.len() {
                    self.image.cursor += 1;
                    self.sync_image_preview();
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
                    let url = full_image_url(&it.url);
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

    pub(crate) fn sync_image_preview(&mut self) {
        let Some(item) = self.image.items.get(self.image.cursor).cloned() else {
            self.image.preview_url = None;
            self.image.preview_title = None;
            self.image.preview_loading = false;
            self.image.preview_error = None;
            self.image.preview_protocol = None;
            return;
        };
        let thumbnail_url = thumbnail_image_url(&item.url);
        if self.image.preview_url.as_deref() == Some(thumbnail_url.as_str())
            && (self.image.preview_loading
                || self.image.preview_protocol.is_some()
                || self.image.preview_error.is_some())
        {
            return;
        }

        self.image.preview_generation = self.image.preview_generation.wrapping_add(1);
        let generation = self.image.preview_generation;
        self.image.preview_url = Some(thumbnail_url.clone());
        self.image.preview_title = Some(item.name.clone());
        self.image.preview_loading = true;
        self.image.preview_error = None;
        self.image.preview_protocol = None;

        let url = thumbnail_url;
        let http = self.api.transfer_http_client();
        let picker = self.image_picker.clone();
        let resize_tx = self.image_resize_tx.clone();
        let tx = self.tx.clone();
        tokio::spawn(async move {
            let res = async {
                let bytes = http
                    .get(&url)
                    .send()
                    .await?
                    .error_for_status()?
                    .bytes()
                    .await?;
                tokio::task::spawn_blocking(move || -> anyhow::Result<ThreadProtocol> {
                    let img = image::ImageReader::new(std::io::Cursor::new(bytes.to_vec()))
                        .with_guessed_format()?
                        .decode()?;
                    let protocol = picker.new_resize_protocol(img);
                    Ok(ThreadProtocol::new(resize_tx, Some(protocol)))
                })
                .await?
            }
            .await;
            let _ = tx.send(Msg::Apply(Box::new(move |app: &mut App| {
                if app.image.preview_generation != generation {
                    return;
                }
                app.image.preview_loading = false;
                match res {
                    Ok(protocol) => {
                        app.image.preview_error = None;
                        app.image.preview_protocol = Some(protocol);
                    }
                    Err(e) => {
                        app.image.preview_protocol = None;
                        app.image.preview_error = Some(e.to_string());
                    }
                }
            })));
        });
    }

    pub(crate) fn handle_image_preview_resized(
        &mut self,
        res: std::result::Result<ResizeResponse, String>,
    ) {
        match res {
            Ok(response) => {
                if let Some(protocol) = self.image.preview_protocol.as_mut() {
                    protocol.update_resized_protocol(response);
                }
            }
            Err(e) => {
                self.image.preview_error = Some(format!("图片预览缩放失败: {e}"));
            }
        }
    }
}
