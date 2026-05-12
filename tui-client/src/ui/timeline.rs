use ratatui::Frame;
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, List, ListItem, ListState};

use crate::app::App;

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    let block = Block::default()
        .borders(Borders::ALL)
        .title(format!(" 时间线  ({} 条) ", app.timeline.items.len()));
    let items: Vec<ListItem> = app
        .timeline
        .items
        .iter()
        .map(|it| {
            let icon = match it.kind.as_str() {
                "note" => ("笔记", Color::LightCyan),
                "image" => ("图片", Color::LightMagenta),
                "file" => ("文件", Color::LightYellow),
                "bookmark" => ("书签", Color::LightGreen),
                _ => ("?", Color::Gray),
            };
            let when = short_date(&it.created_at);
            let summary = it.summary.replace('\n', " ");
            let summary = if summary.is_empty() {
                String::new()
            } else {
                format!("  · {}", trunc(&summary, 60))
            };
            ListItem::new(Line::from(vec![
                Span::styled(format!("[{}]", icon.0), Style::default().fg(icon.1)),
                Span::raw(" "),
                Span::styled(when, Style::default().fg(Color::DarkGray)),
                Span::raw("  "),
                Span::styled(it.name.clone(), Style::default().add_modifier(Modifier::BOLD)),
                Span::styled(summary, Style::default().fg(Color::Gray)),
            ]))
        })
        .collect();
    let mut state = ListState::default();
    state.select(Some(app.timeline.cursor));
    let list = List::new(items)
        .block(block)
        .highlight_style(
            Style::default()
                .bg(Color::DarkGray)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("» ");
    f.render_stateful_widget(list, area, &mut state);
}

fn short_date(s: &str) -> String {
    if s.len() >= 19 {
        s[..19].to_string()
    } else {
        s.to_string()
    }
}

fn trunc(s: &str, max: usize) -> String {
    let collected: String = s.chars().take(max).collect();
    if s.chars().count() > max {
        format!("{collected}…")
    } else {
        collected
    }
}
