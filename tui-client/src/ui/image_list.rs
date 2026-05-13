use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap};
use ratatui_image::{Resize, StatefulImage};

use crate::app::App;
use crate::app::image::full_image_url;

pub fn render(f: &mut Frame, app: &mut App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(0)])
        .split(area);
    let search_block = Block::default()
        .borders(Borders::ALL)
        .title(" 搜索 (按 / 修改) ");
    let search_text = if app.image.search.is_empty() {
        "(空)".to_string()
    } else {
        app.image.search.clone()
    };
    let search = Paragraph::new(search_text).block(search_block);
    f.render_widget(search, chunks[0]);

    let body = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(55), Constraint::Min(24)])
        .split(chunks[1]);

    let title = format!(" 图床 ({} 张) ", app.image.items.len());
    let block = Block::default().borders(Borders::ALL).title(title);
    let items: Vec<ListItem> = app
        .image
        .items
        .iter()
        .map(|it| {
            let date = if it.created_at.len() >= 19 {
                it.created_at[..19].to_string()
            } else {
                it.created_at.clone()
            };
            ListItem::new(Line::from(vec![
                Span::styled(date, Style::default().fg(Color::DarkGray)),
                Span::raw("  "),
                Span::styled(
                    format!("{:>9}", human_size(it.size)),
                    Style::default().fg(Color::DarkGray),
                ),
                Span::raw("  "),
                Span::styled(
                    it.name.clone(),
                    Style::default().add_modifier(Modifier::BOLD),
                ),
                Span::raw("  "),
                Span::styled(full_image_url(&it.url), Style::default().fg(Color::Gray)),
            ]))
        })
        .collect();
    let mut state = ListState::default();
    state.select(Some(app.image.cursor));
    let list = List::new(items)
        .block(block)
        .highlight_style(super::selected_row_style(app))
        .highlight_symbol("» ");
    f.render_stateful_widget(list, body[0], &mut state);
    render_preview(f, app, body[1]);
}

fn render_preview(f: &mut Frame, app: &mut App, area: Rect) {
    let title = app
        .image
        .preview_title
        .as_deref()
        .map(|name| format!(" 预览: {} ", summarize(name, 36)))
        .unwrap_or_else(|| " 预览 ".to_string());
    let block = Block::default().borders(Borders::ALL).title(title);
    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Min(3),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
        ])
        .split(area);
    f.render_widget(block, area);

    if app.image.items.is_empty() {
        render_centered_text(f, "(暂无图片)", inner[0]);
        return;
    }
    if app.image.preview_loading {
        render_centered_text(f, "加载预览中...", inner[0]);
    } else if let Some(err) = &app.image.preview_error {
        let msg = format!("预览失败: {}", summarize(err, 120));
        let para = Paragraph::new(msg)
            .style(Style::default().fg(Color::LightRed))
            .wrap(Wrap { trim: false });
        f.render_widget(para, inner[0]);
    } else if let Some(protocol) = app.image.preview_protocol.as_mut() {
        f.render_widget(Clear, inner[0]);
        let image = StatefulImage::new().resize(Resize::Fit(None));
        f.render_stateful_widget(image, inner[0], protocol);
    } else {
        render_centered_text(f, "(未选择图片)", inner[0]);
    }

    if let Some(item) = app.image.items.get(app.image.cursor) {
        f.render_widget(
            Paragraph::new(Line::from(vec![
                Span::styled("大小 ", Style::default().fg(Color::DarkGray)),
                Span::raw(human_size(item.size)),
                Span::raw("   "),
                Span::styled("时间 ", Style::default().fg(Color::DarkGray)),
                Span::raw(short_dt(&item.created_at)),
            ])),
            inner[1],
        );
        f.render_widget(
            Paragraph::new(Line::from(vec![
                Span::styled("名称 ", Style::default().fg(Color::DarkGray)),
                Span::raw(summarize(&item.name, inner[2].width as usize)),
            ])),
            inner[2],
        );
        f.render_widget(
            Paragraph::new(summarize(
                &full_image_url(&item.url),
                inner[3].width as usize,
            ))
            .style(Style::default().fg(Color::DarkGray)),
            inner[3],
        );
    }
}

fn render_centered_text(f: &mut Frame, text: &str, area: Rect) {
    let para = Paragraph::new(text.to_string())
        .style(Style::default().fg(Color::DarkGray))
        .alignment(ratatui::layout::Alignment::Center);
    f.render_widget(para, area);
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

fn short_dt(s: &str) -> String {
    if s.len() >= 19 {
        s[..19].replace('T', " ")
    } else {
        s.to_string()
    }
}

fn summarize(s: &str, max: usize) -> String {
    if max == 0 {
        return String::new();
    }
    if s.chars().count() <= max {
        return s.to_string();
    }
    let mut out: String = s.chars().take(max.saturating_sub(1)).collect();
    out.push('…');
    out
}
