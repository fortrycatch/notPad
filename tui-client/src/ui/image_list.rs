use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, List, ListItem, ListState, Paragraph};

use crate::app::App;

pub fn render(f: &mut Frame, app: &App, area: Rect) {
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
                Span::styled(it.url.clone(), Style::default().fg(Color::Gray)),
            ]))
        })
        .collect();
    let mut state = ListState::default();
    state.select(Some(app.image.cursor));
    let list = List::new(items)
        .block(block)
        .highlight_style(
            Style::default()
                .bg(Color::DarkGray)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("» ");
    f.render_stateful_widget(list, chunks[1], &mut state);
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
