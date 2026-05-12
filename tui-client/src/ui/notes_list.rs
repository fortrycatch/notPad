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
    render_tag_filter(f, app, chunks[0]);
    render_notes(f, app, chunks[1]);
}

fn render_tag_filter(f: &mut Frame, app: &App, area: Rect) {
    let block = Block::default()
        .borders(Borders::ALL)
        .title(" 标签筛选 (t 切换) ");
    let mut spans: Vec<Span> = vec![];
    let all_active = app.notes.active_tag.is_none();
    spans.push(styled_chip("全部", all_active));
    for t in &app.notes.tags {
        spans.push(Span::raw(" "));
        spans.push(styled_chip(&t.name, app.notes.active_tag == Some(t.id)));
    }
    let para = Paragraph::new(Line::from(spans)).block(block);
    f.render_widget(para, area);
}

fn styled_chip(label: &str, active: bool) -> Span<'_> {
    if active {
        Span::styled(
            format!(" {label} "),
            Style::default()
                .bg(Color::LightMagenta)
                .fg(Color::Black)
                .add_modifier(Modifier::BOLD),
        )
    } else {
        Span::styled(format!(" {label} "), Style::default().fg(Color::Gray))
    }
}

fn render_notes(f: &mut Frame, app: &App, area: Rect) {
    let title = format!(" 笔记 ({} 条) ", app.notes.items.len());
    let block = Block::default().borders(Borders::ALL).title(title);
    let items: Vec<ListItem> = app
        .notes
        .items
        .iter()
        .map(|n| {
            let date = if n.updated_at.len() >= 19 {
                n.updated_at[..19].to_string()
            } else {
                n.updated_at.clone()
            };
            let preview = n.content.replace('\n', " ");
            let preview: String = preview.chars().take(80).collect();
            ListItem::new(Line::from(vec![
                Span::styled(date, Style::default().fg(Color::DarkGray)),
                Span::raw("  "),
                Span::styled(
                    n.title.clone(),
                    Style::default().add_modifier(Modifier::BOLD),
                ),
                Span::raw("  "),
                Span::styled(preview, Style::default().fg(Color::Gray)),
            ]))
        })
        .collect();
    let mut state = ListState::default();
    state.select(Some(app.notes.cursor));
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
