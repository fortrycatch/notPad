use crossterm::event::{KeyCode, KeyEvent};

use super::App;
use crate::api::dto::TimelineItem;

#[derive(Debug, Default)]
pub struct TimelineState {
    pub items: Vec<TimelineItem>,
    pub page: u32,
    pub cursor: usize,
    pub loading: bool,
    pub end: bool,
}

impl App {
    pub(super) fn fetch_timeline(&mut self, page: u32) {
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

    pub(super) fn handle_timeline_key(&mut self, key: KeyEvent) {
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
}
