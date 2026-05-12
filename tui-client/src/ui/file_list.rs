use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Gauge, List, ListItem, ListState, Paragraph};

use crate::app::{App, DownloadStatus, DownloadTask, UploadStatus, UploadTask};
use crate::util::{human_bytes, speed_fmt};

/// Compact bottom dashboard caps at this many gauges to leave room for
/// the file listing. The full picture lives in the transfer manager.
const DASH_MAX_ROWS: usize = 3;

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    let active_up = app
        .file
        .uploads
        .iter()
        .filter(|t| matches!(t.status, UploadStatus::Active))
        .count();
    let active_down = app
        .file
        .downloads
        .iter()
        .filter(|t| matches!(t.status, DownloadStatus::Active))
        .count();
    let active = active_up + active_down;
    let dash_h: u16 = if active == 0 {
        0
    } else {
        active.min(DASH_MAX_ROWS) as u16 + 2 // +2 for the block borders
    };

    let constraints: Vec<Constraint> = if dash_h == 0 {
        vec![
            Constraint::Length(3),
            Constraint::Length(3),
            Constraint::Min(0),
        ]
    } else {
        vec![
            Constraint::Length(3),
            Constraint::Length(3),
            Constraint::Min(0),
            Constraint::Length(dash_h),
        ]
    };
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints(constraints)
        .split(area);

    render_breadcrumbs(f, app, chunks[0]);
    render_search(f, app, chunks[1]);
    render_listing(f, app, chunks[2]);
    if dash_h > 0 {
        render_transfers_dashboard(f, app, chunks[3], active_up, active_down);
    }
}

fn render_breadcrumbs(f: &mut Frame, app: &App, area: Rect) {
    let mut spans: Vec<Span> = vec![];
    for (i, b) in app.file.breadcrumbs.iter().enumerate() {
        if i > 0 {
            spans.push(Span::styled(" / ", Style::default().fg(Color::DarkGray)));
        }
        spans.push(Span::raw(b.name.clone()));
    }
    let block = Block::default().borders(Borders::ALL).title(" 路径 ");
    let para = Paragraph::new(Line::from(spans)).block(block);
    f.render_widget(para, area);
}

fn render_search(f: &mut Frame, app: &App, area: Rect) {
    let scope = if app.file.search_all {
        "所有文件"
    } else {
        "当前目录"
    };
    let text = if app.file.search.is_empty() {
        format!("{scope} · (空)")
    } else {
        format!("{scope} · {}", app.file.search)
    };
    let block = Block::default()
        .borders(Borders::ALL)
        .title(" 搜索 (按 / 修改，c 清除，s 范围) ");
    let para = Paragraph::new(text).block(block);
    f.render_widget(para, area);
}

fn render_listing(f: &mut Frame, app: &App, area: Rect) {
    let title = if let Some(path) = &app.file.pending_upload_path {
        let name = path
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("(unknown)");
        format!(
            " 选择上传目录: {}  ({} 文件夹 / {} 文件) ",
            name,
            app.file.folders.len(),
            app.file.files.len()
        )
    } else {
        format!(
            " 网盘 ({} 文件夹 / {} 文件) ",
            app.file.folders.len(),
            app.file.files.len()
        )
    };
    let block = Block::default().borders(Borders::ALL).title(title);
    let mut items: Vec<ListItem> = vec![];
    for f in &app.file.folders {
        items.push(ListItem::new(Line::from(vec![
            Span::styled("📁 ", Style::default().fg(Color::LightYellow)),
            Span::styled(
                f.name.clone(),
                Style::default().add_modifier(Modifier::BOLD),
            ),
            Span::raw("/"),
        ])));
    }
    for file in &app.file.files {
        let url = file
            .public_url
            .clone()
            .unwrap_or_else(|| file.oss_key.clone());
        items.push(ListItem::new(Line::from(vec![
            Span::styled("📄 ", Style::default().fg(Color::LightCyan)),
            Span::styled(
                file.name.clone(),
                Style::default().add_modifier(Modifier::BOLD),
            ),
            Span::raw("  "),
            Span::styled(
                format!("{:>9}", human_size(file.size)),
                Style::default().fg(Color::DarkGray),
            ),
            Span::raw("  "),
            Span::styled(url, Style::default().fg(Color::DarkGray)),
        ])));
    }
    let mut state = ListState::default();
    state.select(Some(app.file.cursor));
    let list = List::new(items)
        .block(block)
        .highlight_style(super::selected_row_style(app))
        .highlight_symbol("» ");
    f.render_stateful_widget(list, area, &mut state);
}

fn render_transfers_dashboard(
    f: &mut Frame,
    app: &App,
    area: Rect,
    active_up: usize,
    active_down: usize,
) {
    let total = app.file.uploads.len() + app.file.downloads.len();
    let active = active_up + active_down;
    let title = format!(
        " 传输中 {}/{}  ↑{} ↓{}  Ctrl+D 打开管理器 ",
        active, total, active_up, active_down
    );
    let block = Block::default().borders(Borders::ALL).title(title);
    let inner = block.inner(area);
    f.render_widget(block, area);

    // Build a unified list of dashboard rows. Uploads are listed first so
    // they don't get pushed off when both directions are running heavy.
    enum Row<'a> {
        Up(&'a UploadTask),
        Down(&'a DownloadTask),
    }
    let mut rows: Vec<Row<'_>> = Vec::new();
    for t in app
        .file
        .uploads
        .iter()
        .filter(|t| matches!(t.status, UploadStatus::Active))
    {
        rows.push(Row::Up(t));
        if rows.len() >= DASH_MAX_ROWS {
            break;
        }
    }
    if rows.len() < DASH_MAX_ROWS {
        for t in app
            .file
            .downloads
            .iter()
            .filter(|t| matches!(t.status, DownloadStatus::Active))
        {
            rows.push(Row::Down(t));
            if rows.len() >= DASH_MAX_ROWS {
                break;
            }
        }
    }

    let mut y = inner.y;
    for row in rows {
        let area_row = Rect {
            x: inner.x,
            y,
            width: inner.width,
            height: 1,
        };
        let (direction, gauge_color, name, ratio, transferred, total_opt, speed) = match row {
            Row::Up(t) => {
                let ratio = if t.total > 0 {
                    (t.uploaded as f64 / t.total as f64).clamp(0.0, 1.0)
                } else {
                    0.0
                };
                (
                    '↑',
                    Color::LightCyan,
                    t.name.as_str(),
                    ratio,
                    t.uploaded,
                    Some(t.total),
                    t.speed_bps,
                )
            }
            Row::Down(t) => {
                let ratio = match t.total {
                    Some(total) if total > 0 => {
                        (t.downloaded as f64 / total as f64).clamp(0.0, 1.0)
                    }
                    _ => 0.0,
                };
                (
                    '↓',
                    Color::LightGreen,
                    t.name.as_str(),
                    ratio,
                    t.downloaded,
                    t.total,
                    t.speed_bps,
                )
            }
        };
        let percent = (ratio * 100.0) as u8;
        let total_part = match total_opt {
            Some(total) => format!("{} / {}", human_bytes(transferred), human_bytes(total)),
            None => format!("{} / ?", human_bytes(transferred)),
        };
        let label = format!(
            "{} {}  {}%  {}  {}",
            direction,
            name,
            percent,
            total_part,
            speed_fmt(speed)
        );
        let gauge = Gauge::default()
            .gauge_style(Style::default().fg(gauge_color))
            .ratio(ratio)
            .label(label);
        f.render_widget(gauge, area_row);
        y += 1;
        if y >= inner.y + inner.height {
            break;
        }
    }
}

fn human_size(bytes: u64) -> String {
    const UNITS: [&str; 5] = ["B", "K", "M", "G", "T"];
    let mut size = bytes as f64;
    let mut i = 0;
    while size >= 1024.0 && i + 1 < UNITS.len() {
        size /= 1024.0;
        i += 1;
    }
    if i == 0 {
        format!("{} {}", bytes, UNITS[0])
    } else {
        format!("{:.1} {}", size, UNITS[i])
    }
}
