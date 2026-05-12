use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap};

use crate::app::{App, DownloadStatus, DownloadTask, Modal};
use crate::util::{human_bytes, human_eta_secs, speed_fmt};

pub fn render(f: &mut Frame, app: &App) {
    let Some(modal) = &app.modal else {
        return;
    };
    let area = f.area();
    match modal {
        Modal::Confirm { prompt, .. } => render_confirm(f, area, prompt),
        Modal::Input {
            title,
            prompt,
            value,
            ..
        } => render_input(f, area, title, prompt, value),
        Modal::Message { title, body } => render_message(f, area, title, body),
        Modal::TagPicker {
            all,
            selected,
            cursor,
            new_input,
            new_input_focus,
            ..
        } => render_tag_picker(f, area, all, selected, *cursor, new_input, *new_input_focus),
        Modal::GroupPicker { groups, cursor } => {
            render_group_picker(f, area, groups, *cursor, app.active_group_id.as_deref())
        }
        Modal::DownloadDest {
            file,
            cfg_path,
            cwd_path,
        } => render_download_dest(f, area, &file.name, cfg_path.as_deref(), cwd_path),
        Modal::DownloadManager { cursor } => {
            render_download_manager(f, area, &app.file.downloads, *cursor)
        }
    }
}

fn centered(area: Rect, w: u16, h: u16) -> Rect {
    let w = w.min(area.width);
    let h = h.min(area.height);
    let x = area.x + (area.width.saturating_sub(w)) / 2;
    let y = area.y + (area.height.saturating_sub(h)) / 2;
    Rect {
        x,
        y,
        width: w,
        height: h,
    }
}

fn render_confirm(f: &mut Frame, area: Rect, prompt: &str) {
    let r = centered(area, 60, 7);
    f.render_widget(Clear, r);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Yellow))
        .title(" 确认 (y / n) ");
    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([Constraint::Min(1), Constraint::Length(1)])
        .split(r);
    f.render_widget(block, r);
    let para = Paragraph::new(prompt.to_string()).wrap(Wrap { trim: false });
    f.render_widget(para, inner[0]);
    let hint = Paragraph::new(Line::from(vec![Span::styled(
        "[Y]es / [N]o",
        Style::default().fg(Color::DarkGray),
    )]));
    f.render_widget(hint, inner[1]);
}

fn render_input(f: &mut Frame, area: Rect, title: &str, prompt: &str, value: &str) {
    let r = centered(area, 60, 8);
    f.render_widget(Clear, r);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::LightMagenta))
        .title(format!(" {title} "));
    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(3),
            Constraint::Length(1),
        ])
        .split(r);
    f.render_widget(block, r);
    let label = Paragraph::new(prompt.to_string());
    f.render_widget(label, inner[0]);
    let edit_block = Block::default().borders(Borders::ALL);
    let edit = Paragraph::new(value.to_string())
        .style(Style::default().add_modifier(Modifier::BOLD))
        .block(edit_block);
    f.render_widget(edit, inner[1]);
    let hint = Paragraph::new(Line::from(vec![Span::styled(
        "Enter 提交  Esc 取消",
        Style::default().fg(Color::DarkGray),
    )]));
    f.render_widget(hint, inner[2]);
}

fn render_message(f: &mut Frame, area: Rect, title: &str, body: &str) {
    let r = centered(area, 70, 12);
    f.render_widget(Clear, r);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::White))
        .title(format!(" {title} "));
    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([Constraint::Min(1), Constraint::Length(1)])
        .split(r);
    f.render_widget(block, r);
    let para = Paragraph::new(body.to_string()).wrap(Wrap { trim: false });
    f.render_widget(para, inner[0]);
    let hint = Paragraph::new(Line::from(vec![Span::styled(
        "Enter / Esc 关闭",
        Style::default().fg(Color::DarkGray),
    )]));
    f.render_widget(hint, inner[1]);
}

fn render_tag_picker(
    f: &mut Frame,
    area: Rect,
    all: &[crate::api::dto::NoteTag],
    selected: &std::collections::HashSet<i64>,
    cursor: usize,
    new_input: &str,
    new_input_focus: bool,
) {
    let r = centered(area, 50, (all.len() as u16 + 8).min(area.height));
    f.render_widget(Clear, r);
    let block = Block::default()
        .borders(Borders::ALL)
        .title(" 标签 (Space 切换  a 新建  q 退出) ");
    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([Constraint::Min(1), Constraint::Length(3)])
        .split(r);
    f.render_widget(block, r);

    let items: Vec<ListItem> = all
        .iter()
        .map(|t| {
            let mark = if selected.contains(&t.id) {
                "[x]"
            } else {
                "[ ]"
            };
            ListItem::new(format!("{mark} {}", t.name))
        })
        .collect();
    let mut state = ListState::default();
    state.select(Some(cursor));
    let list = List::new(items)
        .highlight_style(Style::default().bg(Color::DarkGray))
        .highlight_symbol("» ");
    f.render_stateful_widget(list, inner[0], &mut state);

    let new_block = Block::default()
        .borders(Borders::ALL)
        .border_style(if new_input_focus {
            Style::default().fg(Color::LightMagenta)
        } else {
            Style::default().fg(Color::DarkGray)
        })
        .title(" 新建标签 (a 聚焦  Enter 提交  Esc 取消聚焦) ");
    let para = Paragraph::new(new_input.to_string()).block(new_block);
    f.render_widget(para, inner[1]);
}

fn render_download_dest(
    f: &mut Frame,
    area: Rect,
    name: &str,
    cfg_path: Option<&std::path::Path>,
    cwd_path: &std::path::Path,
) {
    let r = centered(area, 80, 10);
    f.render_widget(Clear, r);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::LightMagenta))
        .title(format!(" 下载 {name} 到… "));
    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Min(0),
            Constraint::Length(1),
        ])
        .split(r);
    f.render_widget(block, r);

    let cfg_line = match cfg_path {
        Some(p) => Line::from(vec![
            Span::styled("[1] ", Style::default().fg(Color::Yellow)),
            Span::raw("配置目录: "),
            Span::styled(
                p.display().to_string(),
                Style::default().fg(Color::LightCyan),
            ),
        ]),
        None => Line::from(vec![
            Span::styled("[1] ", Style::default().fg(Color::Yellow)),
            Span::raw("配置目录: "),
            Span::styled(
                "(未配置，将使用系统 Downloads)",
                Style::default().fg(Color::DarkGray),
            ),
        ]),
    };
    let cwd_line = Line::from(vec![
        Span::styled("[2] ", Style::default().fg(Color::Yellow)),
        Span::raw("当前目录: "),
        Span::styled(
            cwd_path.display().to_string(),
            Style::default().fg(Color::LightCyan),
        ),
    ]);
    let link_line = Line::from(vec![
        Span::styled("[3] ", Style::default().fg(Color::Yellow)),
        Span::raw("复制文件链接到剪贴板"),
    ]);
    f.render_widget(Paragraph::new(cfg_line), inner[0]);
    f.render_widget(Paragraph::new(cwd_line), inner[1]);
    f.render_widget(Paragraph::new(link_line), inner[2]);
    f.render_widget(
        Paragraph::new(Line::from(Span::styled(
            "Enter/1=下载到配置目录  2=下载到当前目录  3=复制链接  Esc=取消",
            Style::default().fg(Color::DarkGray),
        ))),
        inner[5],
    );
}

fn render_download_manager(f: &mut Frame, area: Rect, tasks: &[DownloadTask], cursor: usize) {
    // Leave a 2-row margin on every side so the modal feels like a true
    // overlay instead of a full repaint.
    let w = area.width.saturating_sub(4).max(40);
    let h = area.height.saturating_sub(4).max(8);
    let r = centered(area, w, h);
    f.render_widget(Clear, r);

    let mut counts = (0u32, 0u32, 0u32, 0u32); // active, completed, cancelled, failed
    for t in tasks {
        match &t.status {
            DownloadStatus::Active => counts.0 += 1,
            DownloadStatus::Completed => counts.1 += 1,
            DownloadStatus::Cancelled => counts.2 += 1,
            DownloadStatus::Failed(_) => counts.3 += 1,
        }
    }
    let title = format!(
        " 下载管理器  活动 {} · 完成 {} · 取消 {} · 失败 {} ",
        counts.0, counts.1, counts.2, counts.3
    );
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::LightMagenta))
        .title(title);
    f.render_widget(block, r);

    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([Constraint::Min(1), Constraint::Length(1)])
        .split(r);

    if tasks.is_empty() {
        let empty = Paragraph::new(Line::from(Span::styled(
            "(尚无下载任务，去网盘 Tab 按 d 开始一项)",
            Style::default().fg(Color::DarkGray),
        )))
        .alignment(ratatui::layout::Alignment::Center);
        f.render_widget(empty, inner[0]);
    } else {
        render_download_manager_list(f, inner[0], tasks, cursor);
    }

    let hint = Line::from(Span::styled(
        "j/k 移动  x 取消  c 清除完成/取消/失败  o 在文件管理器中显示  Esc 关闭",
        Style::default().fg(Color::DarkGray),
    ));
    f.render_widget(Paragraph::new(hint), inner[1]);
}

fn render_download_manager_list(f: &mut Frame, area: Rect, tasks: &[DownloadTask], cursor: usize) {
    const ROWS_PER_TASK: u16 = 2;
    // Compact layout: no extra gutter row, so the manager can show more tasks.
    let visible = (area.height / ROWS_PER_TASK).max(1) as usize;
    let max = tasks.len();
    // Center the cursor within the visible window when possible.
    let half = visible / 2;
    let start = if max <= visible || cursor < half {
        0
    } else if cursor + (visible - half) > max {
        max - visible
    } else {
        cursor - half
    };
    let end = (start + visible).min(max);

    let mut y = area.y;
    let area_right = area.x + area.width;
    for (idx, t) in tasks[start..end].iter().enumerate() {
        let abs = start + idx;
        let selected = abs == cursor;
        let row1 = Rect {
            x: area.x,
            y,
            width: area.width,
            height: 1,
        };
        let row2 = Rect {
            x: area.x,
            y: y + 1,
            width: area.width,
            height: 1,
        };

        let ratio = match (t.total, &t.status) {
            (Some(total), _) if total > 0 => (t.downloaded as f64 / total as f64).clamp(0.0, 1.0),
            (_, DownloadStatus::Completed) => 1.0,
            _ => 0.0,
        };
        let cursor_prefix = if selected { "» " } else { "  " };
        // Reserve a 2-col prefix column so the progress line starts after the
        // cursor caret.
        let prefix_rect = Rect {
            x: row1.x,
            y: row1.y,
            width: 2.min(row1.width),
            height: 1,
        };
        let line_rect = Rect {
            x: row1.x + 2,
            y: row1.y,
            width: row1.width.saturating_sub(2),
            height: 1,
        };
        let prefix_style = if selected {
            Style::default()
                .fg(Color::LightMagenta)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default()
        };
        f.render_widget(
            Paragraph::new(Line::from(Span::styled(cursor_prefix, prefix_style))),
            prefix_rect,
        );
        let bar_color = match &t.status {
            DownloadStatus::Active => Color::LightGreen,
            DownloadStatus::Completed => Color::Green,
            DownloadStatus::Cancelled => Color::DarkGray,
            DownloadStatus::Failed(_) => Color::Red,
        };
        let (size_part, speed_eta_part) = task_progress_meta(t);
        let bar_width = line_rect.width.saturating_sub(40).clamp(10, 28) as usize;
        let percent = match (t.total, &t.status) {
            (Some(total), _) if total > 0 => format!("{:>3.0}%", ratio * 100.0),
            (_, DownloadStatus::Completed) => "100%".to_string(),
            _ => "  ?%".to_string(),
        };
        let bar = pip_bar(
            ratio,
            bar_width,
            matches!(t.status, DownloadStatus::Completed),
        );
        let name_room = line_rect
            .width
            .saturating_sub(
                (bar.len() + percent.len() + size_part.len() + speed_eta_part.len() + 8) as u16,
            )
            .max(8) as usize;
        let name = summarize(&t.name, name_room);
        let line = format!("{name} {bar} {percent} {size_part}{speed_eta_part}");
        let line_style = if selected {
            Style::default().bg(Color::DarkGray).fg(bar_color)
        } else {
            Style::default().fg(bar_color)
        };
        f.render_widget(Paragraph::new(line).style(line_style), line_rect);

        // Detail row: save path + status. Trim path from the left when
        // longer than the available width, so the file name stays visible.
        let detail_line = task_detail_line(t, (area_right - row2.x) as usize);
        let detail_style = if selected {
            Style::default().bg(Color::DarkGray)
        } else {
            Style::default()
        };
        f.render_widget(Paragraph::new(detail_line).style(detail_style), row2);

        y += ROWS_PER_TASK;
        if y >= area.y + area.height {
            break;
        }
    }
}

fn task_progress_meta(t: &DownloadTask) -> (String, String) {
    match &t.status {
        DownloadStatus::Active => {
            let size_part = match t.total {
                Some(total) => format!("{} / {}", human_bytes(t.downloaded), human_bytes(total)),
                None => format!("{} / ?", human_bytes(t.downloaded)),
            };
            let speed_eta_part = match (t.total, t.speed_bps) {
                (Some(total), s) if s > 0 && total > t.downloaded => {
                    let remaining = total - t.downloaded;
                    format!(
                        "  {}  ETA {}",
                        speed_fmt(t.speed_bps),
                        human_eta_secs(remaining / s)
                    )
                }
                _ if t.speed_bps > 0 => format!("  {}", speed_fmt(t.speed_bps)),
                _ => String::new(),
            };
            (size_part, speed_eta_part)
        }
        DownloadStatus::Completed => {
            let size = t.total.unwrap_or(t.downloaded);
            (human_bytes(size), "  done".to_string())
        }
        DownloadStatus::Cancelled => (human_bytes(t.downloaded), "  cancelled".to_string()),
        DownloadStatus::Failed(e) => (
            human_bytes(t.downloaded),
            format!("  failed: {}", summarize(e, 28)),
        ),
    }
}

fn pip_bar(ratio: f64, width: usize, completed: bool) -> String {
    if width == 0 {
        return "[]".to_string();
    }
    let clamped = ratio.clamp(0.0, 1.0);
    let filled = (clamped * width as f64).round() as usize;
    let mut bar = String::with_capacity(width + 2);
    bar.push('[');
    if completed {
        bar.extend(std::iter::repeat_n('=', width));
    } else {
        for i in 0..width {
            if i < filled {
                bar.push('=');
            } else if i == filled && filled < width && filled > 0 {
                bar.push('>');
            } else {
                bar.push('-');
            }
        }
    }
    bar.push(']');
    bar
}

fn task_detail_line(t: &DownloadTask, max_width: usize) -> Line<'static> {
    let path_text = clip_left(
        &t.save_path.display().to_string(),
        max_width.saturating_sub(2),
    );
    let style = match &t.status {
        DownloadStatus::Failed(_) => Style::default().fg(Color::LightRed),
        DownloadStatus::Cancelled => Style::default().fg(Color::DarkGray),
        DownloadStatus::Completed => Style::default().fg(Color::Green),
        DownloadStatus::Active => Style::default().fg(Color::DarkGray),
    };
    Line::from(vec![Span::raw("  "), Span::styled(path_text, style)])
}

/// Trim from the left and prepend `…` so long absolute paths still show
/// their meaningful suffix (the file name). Counts chars, not bytes —
/// good enough for paths which don't include CJK glyphs typically.
fn clip_left(s: &str, max: usize) -> String {
    if max == 0 {
        return String::new();
    }
    let chars: Vec<char> = s.chars().collect();
    if chars.len() <= max {
        return s.to_string();
    }
    let keep = max.saturating_sub(1);
    let start = chars.len() - keep;
    let mut out = String::with_capacity(keep + 1);
    out.push('…');
    out.extend(chars[start..].iter());
    out
}

fn summarize(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        return s.to_string();
    }
    let mut out: String = s.chars().take(max.saturating_sub(1)).collect();
    out.push('…');
    out
}

fn render_group_picker(
    f: &mut Frame,
    area: Rect,
    groups: &[crate::api::dto::GroupItem],
    cursor: usize,
    active_id: Option<&str>,
) {
    let total = groups.len() as u16 + 1; // +1 for personal
    let h = (total + 4).clamp(7, area.height);
    let r = centered(area, 60, h);
    f.render_widget(Clear, r);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::LightMagenta))
        .title(" 切换群组 (j/k Enter Esc) ");
    f.render_widget(block, r);
    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([Constraint::Min(1)])
        .split(r);

    let mut items: Vec<ListItem> = Vec::with_capacity(groups.len() + 1);
    let personal_active = active_id.is_none();
    items.push(ListItem::new(Line::from(vec![
        Span::styled(
            if personal_active { "● " } else { "  " },
            Style::default().fg(Color::LightMagenta),
        ),
        Span::styled("个人", Style::default().add_modifier(Modifier::BOLD)),
        Span::raw("  "),
        Span::styled("(私有空间)", Style::default().fg(Color::DarkGray)),
    ])));
    for g in groups {
        let active = active_id == Some(g.id.as_str());
        items.push(ListItem::new(Line::from(vec![
            Span::styled(
                if active { "● " } else { "  " },
                Style::default().fg(Color::LightMagenta),
            ),
            Span::styled(
                g.name.clone(),
                Style::default().add_modifier(Modifier::BOLD),
            ),
            Span::raw("  "),
            Span::styled(
                format!("[{}]", g.role),
                Style::default().fg(Color::DarkGray),
            ),
        ])));
    }
    let mut state = ListState::default();
    state.select(Some(cursor));
    let list = List::new(items)
        .highlight_style(
            Style::default()
                .bg(Color::DarkGray)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("» ");
    f.render_stateful_widget(list, inner[0], &mut state);
}
