pub mod file_list;
pub mod image_list;
pub mod login;
pub mod modal;
pub mod note_view;
pub mod notes_list;
pub mod settings;
pub mod timeline;
pub mod todo;

use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph, Tabs};

use crate::app::{App, Tab};

pub fn render(f: &mut Frame, app: &App) {
    if !app.authenticated {
        login::render(f, app);
        if app.modal.is_some() {
            modal::render(f, app);
        }
        return;
    }
    let area = f.area();
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(0),
            Constraint::Length(1),
        ])
        .split(area);
    render_top_bar(f, app, chunks[0]);
    render_main_body(f, app, chunks[1]);
    render_bottom_bar(f, app, chunks[2]);
    if app.modal.is_some() {
        modal::render(f, app);
    }
}

fn render_top_bar(f: &mut Frame, app: &App, area: Rect) {
    let titles: Vec<Line> = Tab::ALL
        .iter()
        .map(|t| {
            Line::from(vec![
                Span::styled(format!("{}", t.shortcut()), Style::default().fg(Color::Yellow)),
                Span::raw(" "),
                Span::raw(t.label()),
            ])
        })
        .collect();
    let selected = Tab::ALL.iter().position(|t| *t == app.tab).unwrap_or(0);
    let user = app
        .username
        .clone()
        .unwrap_or_else(|| "(未命名)".to_string());
    let scope = scope_palette(app);
    let spinner = if app.loading() {
        spinner_glyph(app.spinner_phase)
    } else {
        ""
    };
    let title_line = Line::from(vec![
        Span::raw(" notpad-tui  ·  "),
        Span::raw(app.api.base_url().to_string()),
        Span::raw("  ·  "),
        Span::raw(user),
        Span::raw("  ·  "),
        Span::styled(
            format!(" {} ", scope.label),
            Style::default()
                .fg(scope.chip_fg)
                .bg(scope.chip_bg)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(format!(" {spinner}")),
    ]);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(scope.bar_bg))
        .title(title_line);
    let tabs = Tabs::new(titles)
        .block(block)
        .select(selected)
        .highlight_style(
            // bar_fg is the auto-picked contrast color (black/white) for
            // bar_bg — using chip_fg here would equal bar_bg and make the
            // selected tab invisible.
            Style::default()
                .fg(scope.bar_fg)
                .bg(scope.bar_bg)
                .add_modifier(Modifier::BOLD),
        )
        .divider(" │ ");
    f.render_widget(tabs, area);
}

fn render_main_body(f: &mut Frame, app: &App, area: Rect) {
    match app.tab {
        Tab::Timeline => timeline::render(f, app, area),
        Tab::Notes => {
            if app.notes.detail.is_some() {
                note_view::render(f, app, area);
            } else {
                notes_list::render(f, app, area);
            }
        }
        Tab::Todo => todo::render(f, app, area),
        Tab::Image => image_list::render(f, app, area),
        Tab::File => file_list::render(f, app, area),
        Tab::Settings => settings::render(f, app, area),
    }
}

fn render_bottom_bar(f: &mut Frame, app: &App, area: Rect) {
    let hint = match (app.tab, app.notes.detail.is_some()) {
        (Tab::Timeline, _) => {
            "1-6 切换  g 群组  j/k 上下  r 刷新  Ctrl+D 下载管理器  Ctrl+C 退出"
        }
        (Tab::Notes, false) => {
            "1-6 切换  g 群组  j/k  Enter 查看  n 新建  d 删除  t 标签  r 刷新  Ctrl+D 下载管理器  q 退出"
        }
        (Tab::Notes, true) => {
            "Esc/q 返回  e 编辑  t 标签  Tab 切焦点(标题/正文)  Ctrl+S 保存"
        }
        (Tab::Todo, _) => {
            "1-6 切换  g 群组  Tab 切焦点  j/k  Enter 切换完成/进入  n 新建  e 改名  d 删除  r 刷新  Ctrl+D 下载管理器"
        }
        (Tab::Image, _) => {
            "1-6 切换  g 群组  j/k  / 搜索  e 重命名  y 显示URL  r 刷新  Ctrl+D 下载管理器"
        }
        (Tab::File, _) => {
            "1-6 切换  g 群组  j/k  Enter 进入/下载菜单  Backspace 上级  u 上传  e 重命名  y 显示链接  r 刷新  Ctrl+D 下载管理器"
        }
        (Tab::Settings, _) => {
            "1-6 切换  Tab/h/l 切焦点  j/k  Enter 选择/编辑  Esc 取消/返回  Ctrl+D 下载管理器  q 退出"
        }
    };

    let scope = scope_palette(app);

    // Status messages temporarily override the body color (red = error,
    // green = success), but the scope chip on the left always reflects the
    // current workspace so the user never loses that visual anchor.
    let (body_bg, body_fg, body_mod) = match app.status_msg {
        Some((_, true)) => (Color::Red, Color::White, Modifier::BOLD),
        Some((_, false)) => (Color::Green, Color::Black, Modifier::BOLD),
        None => (scope.bar_bg, scope.bar_fg, Modifier::BOLD),
    };

    let body = match &app.status_msg {
        Some((m, _)) => m.clone(),
        None => hint.to_string(),
    };

    let chip = Span::styled(
        format!(" {} ", scope.label),
        Style::default()
            .fg(scope.chip_fg)
            .bg(scope.chip_bg)
            .add_modifier(Modifier::BOLD),
    );
    let body_span = Span::styled(
        format!(" {body} "),
        Style::default().fg(body_fg).bg(body_bg).add_modifier(body_mod),
    );
    let line = Line::from(vec![chip, body_span]);

    // Paint the entire row in the scope color so the trailing whitespace also
    // takes on the workspace tint, not just the text portion.
    let para = Paragraph::new(line).style(Style::default().fg(body_fg).bg(body_bg));
    f.render_widget(para, area);
}

struct ScopePalette {
    label: String,
    bar_bg: Color,
    bar_fg: Color,
    chip_bg: Color,
    chip_fg: Color,
}

fn scope_palette(app: &App) -> ScopePalette {
    let label = match (&app.active_group_id, &app.active_group_name) {
        (None, _) => "个人".to_string(),
        (Some(_), Some(name)) => format!("群组·{}", name),
        (Some(_), None) => "群组".to_string(),
    };

    // Prefer the user-configured `meta.primaryColor` from the active scope.
    if let Some((bg_color, bg_rgb)) = app
        .active_primary_color()
        .as_deref()
        .and_then(|hex| parse_hex(hex).map(|rgb| (Color::Rgb(rgb.0, rgb.1, rgb.2), rgb)))
    {
        let fg_color = contrast_color(bg_rgb);
        return ScopePalette {
            label,
            bar_bg: bg_color,
            bar_fg: fg_color,
            chip_bg: fg_color,
            chip_fg: bg_color,
        };
    }

    // Fallbacks when the workspace has no color configured yet.
    if app.active_group_id.is_none() {
        return ScopePalette {
            label,
            bar_bg: Color::Blue,
            bar_fg: Color::White,
            chip_bg: Color::White,
            chip_fg: Color::Blue,
        };
    }

    // Hash the group id so unconfigured groups still get a stable, distinct
    // color across sessions instead of sharing one default.
    const GROUP_PALETTE: &[(Color, Color)] = &[
        (Color::Magenta, Color::White),
        (Color::Cyan, Color::Black),
        (Color::LightGreen, Color::Black),
        (Color::Yellow, Color::Black),
        (Color::LightBlue, Color::Black),
        (Color::LightMagenta, Color::Black),
        (Color::LightRed, Color::Black),
        (Color::LightCyan, Color::Black),
    ];
    let id = app.active_group_id.as_deref().unwrap_or("");
    let h = id
        .bytes()
        .fold(0u32, |acc, b| acc.wrapping_mul(131).wrapping_add(b as u32));
    let (bar_bg, bar_fg) = GROUP_PALETTE[(h as usize) % GROUP_PALETTE.len()];
    ScopePalette {
        label,
        bar_bg,
        bar_fg,
        chip_bg: bar_fg,
        chip_fg: bar_bg,
    }
}

/// Parse `#rgb` / `#rrggbb` style hex colors. Whitespace and casing are
/// ignored; returns `None` if the string isn't a valid color.
fn parse_hex(input: &str) -> Option<(u8, u8, u8)> {
    let s = input.trim();
    let s = s.strip_prefix('#').unwrap_or(s);
    match s.len() {
        3 => {
            let r = u8::from_str_radix(&s[0..1], 16).ok()?;
            let g = u8::from_str_radix(&s[1..2], 16).ok()?;
            let b = u8::from_str_radix(&s[2..3], 16).ok()?;
            Some((r * 17, g * 17, b * 17))
        }
        6 => {
            let r = u8::from_str_radix(&s[0..2], 16).ok()?;
            let g = u8::from_str_radix(&s[2..4], 16).ok()?;
            let b = u8::from_str_radix(&s[4..6], 16).ok()?;
            Some((r, g, b))
        }
        _ => None,
    }
}

/// Pick black or white as a foreground for the given background using the
/// W3C relative-luminance formula, so text always stays readable regardless
/// of which color the user picked for their workspace.
fn contrast_color((r, g, b): (u8, u8, u8)) -> Color {
    fn channel(v: u8) -> f32 {
        let v = v as f32 / 255.0;
        if v <= 0.03928 {
            v / 12.92
        } else {
            ((v + 0.055) / 1.055).powf(2.4)
        }
    }
    let l = 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
    if l > 0.5 {
        Color::Black
    } else {
        Color::White
    }
}

fn spinner_glyph(phase: u8) -> &'static str {
    match phase % 4 {
        0 => "-",
        1 => "\\",
        2 => "|",
        _ => "/",
    }
}
