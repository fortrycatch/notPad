use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

use super::App;

#[derive(Debug, Default)]
pub struct LoginState {
    pub username: String,
    pub password: String,
    pub focus: u8, // 0 = username, 1 = password
    pub submitting: bool,
    pub error: Option<String>,
}

impl App {
    pub(super) fn handle_login_key(&mut self, key: KeyEvent) {
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
                        app.login.error = Some(r.message.unwrap_or_else(|| "登录失败".into()));
                    }
                    Err(e) => {
                        app.login.error = Some(format!("网络错误: {e}"));
                    }
                }
            })
        });
    }
}
