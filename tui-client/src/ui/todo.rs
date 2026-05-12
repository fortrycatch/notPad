use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Wrap};

use crate::api::dto::TodoItem;
use crate::app::App;

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Length(26),
            Constraint::Percentage(40),
            Constraint::Min(0),
        ])
        .split(area);
    render_lists(f, app, chunks[0]);
    render_items(f, app, chunks[1]);
    render_detail(f, app, chunks[2]);
}

fn render_lists(f: &mut Frame, app: &App, area: Rect) {
    let title = " 列表 ";
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(if !app.todo.focus_items {
            Style::default().fg(Color::LightMagenta)
        } else {
            Style::default().fg(Color::DarkGray)
        })
        .title(title);
    let items: Vec<ListItem> = app
        .todo
        .lists
        .iter()
        .map(|l| {
            ListItem::new(Line::from(vec![
                Span::styled(" ● ", Style::default().fg(parse_color(&l.color))),
                Span::raw(l.name.clone()),
            ]))
        })
        .collect();
    let mut state = ListState::default();
    state.select(Some(app.todo.list_cursor));
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

fn render_items(f: &mut Frame, app: &App, area: Rect) {
    let active = app
        .todo
        .lists
        .get(app.todo.list_cursor)
        .map(|l| l.name.clone())
        .unwrap_or_else(|| "(无列表)".to_string());
    let title = format!(" {active} ({} 条) ", app.todo.items.len());
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(if app.todo.focus_items {
            Style::default().fg(Color::LightMagenta)
        } else {
            Style::default().fg(Color::DarkGray)
        })
        .title(title);
    if app.todo.lists.is_empty() {
        let para = Paragraph::new("还没有列表，按 n 新建").block(block);
        f.render_widget(para, area);
        return;
    }
    let items: Vec<ListItem> = app
        .todo
        .items
        .iter()
        .map(|it| {
            let mark = if it.done == 1 { "[x]" } else { "[ ]" };
            let title_style = if it.done == 1 {
                Style::default()
                    .fg(Color::DarkGray)
                    .add_modifier(Modifier::CROSSED_OUT)
            } else {
                Style::default()
            };
            let mut spans = vec![
                Span::styled(format!("{mark} "), Style::default().fg(Color::LightYellow)),
                Span::styled(it.title.clone(), title_style),
            ];
            if !it.refs.is_empty() {
                spans.push(Span::styled(
                    format!("  · {} 引用", it.refs.len()),
                    Style::default().fg(Color::DarkGray),
                ));
            }
            ListItem::new(Line::from(spans))
        })
        .collect();
    let mut state = ListState::default();
    state.select(Some(app.todo.item_cursor));
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

fn render_detail(f: &mut Frame, app: &App, area: Rect) {
    let block = Block::default().borders(Borders::ALL).title(" 详情 ");
    let item = app.todo.items.get(app.todo.item_cursor);
    let Some(item) = item else {
        let para = Paragraph::new("(未选中)")
            .style(Style::default().fg(Color::DarkGray))
            .block(block);
        f.render_widget(para, area);
        return;
    };

    let inner = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(1), // title
            Constraint::Length(1), // status row
            Constraint::Length(1), // timestamps
            Constraint::Length(1), // separator / blank
            Constraint::Length(1), // description label
            Constraint::Min(3),    // description
            Constraint::Length(1), // refs label
            Constraint::Min(0),    // refs list
        ])
        .split(area);
    f.render_widget(block, area);

    let title = Paragraph::new(Line::from(vec![Span::styled(
        item.title.clone(),
        Style::default()
            .add_modifier(Modifier::BOLD)
            .fg(Color::White),
    )]));
    f.render_widget(title, inner[0]);

    let status_span = if item.done == 1 {
        Span::styled("✓ 已完成", Style::default().fg(Color::Green))
    } else {
        Span::styled("○ 待办", Style::default().fg(Color::LightYellow))
    };
    let mut status_spans = vec![status_span, Span::raw("   ")];
    if let Some(c) = item.color.as_deref().filter(|s| !s.is_empty()) {
        status_spans.push(Span::styled("●", Style::default().fg(parse_color(c))));
        status_spans.push(Span::styled(
            format!(" {c}"),
            Style::default().fg(Color::DarkGray),
        ));
    }
    f.render_widget(Paragraph::new(Line::from(status_spans)), inner[1]);

    let created = short_dt(&item.created_at);
    let updated = short_dt(&item.updated_at);
    let ts = Paragraph::new(Line::from(vec![Span::styled(
        format!("创建 {created}   ·   更新 {updated}"),
        Style::default().fg(Color::DarkGray),
    )]));
    f.render_widget(ts, inner[2]);

    f.render_widget(Paragraph::new(""), inner[3]);

    f.render_widget(
        Paragraph::new(Line::from(vec![Span::styled(
            "描述",
            Style::default()
                .fg(Color::Gray)
                .add_modifier(Modifier::BOLD),
        )])),
        inner[4],
    );
    let desc_text = if item.description.trim().is_empty() {
        "(无)".to_string()
    } else {
        item.description.clone()
    };
    let desc_style = if item.description.trim().is_empty() {
        Style::default().fg(Color::DarkGray)
    } else {
        Style::default()
    };
    let desc = Paragraph::new(desc_text)
        .style(desc_style)
        .wrap(Wrap { trim: false });
    f.render_widget(desc, inner[5]);

    f.render_widget(
        Paragraph::new(Line::from(vec![Span::styled(
            format!("引用 ({})", item.refs.len()),
            Style::default()
                .fg(Color::Gray)
                .add_modifier(Modifier::BOLD),
        )])),
        inner[6],
    );
    render_refs(f, item, inner[7]);
}

fn render_refs(f: &mut Frame, item: &TodoItem, area: Rect) {
    if item.refs.is_empty() {
        let para = Paragraph::new("(无)").style(Style::default().fg(Color::DarkGray));
        f.render_widget(para, area);
        return;
    }
    let items: Vec<ListItem> = item
        .refs
        .iter()
        .map(|r| {
            let (label, color) = match r.kind.as_str() {
                "note" => ("笔记", Color::LightCyan),
                "image" => ("图片", Color::LightMagenta),
                "file" => ("文件", Color::LightYellow),
                "bookmark" => ("书签", Color::LightGreen),
                _ => (r.kind.as_str(), Color::Gray),
            };
            let title = if r.title.is_empty() {
                r.ref_id.clone()
            } else {
                r.title.clone()
            };
            ListItem::new(Line::from(vec![
                Span::styled(format!("[{label}]"), Style::default().fg(color)),
                Span::raw(" "),
                Span::raw(title),
            ]))
        })
        .collect();
    let list = List::new(items);
    f.render_widget(list, area);
}

fn short_dt(s: &str) -> String {
    if s.len() >= 19 {
        s[..19].replace('T', " ")
    } else {
        s.to_string()
    }
}

fn parse_color(hex: &str) -> Color {
    let s = hex.trim_start_matches('#');
    if s.len() == 6
        && let (Ok(r), Ok(g), Ok(b)) = (
            u8::from_str_radix(&s[0..2], 16),
            u8::from_str_radix(&s[2..4], 16),
            u8::from_str_radix(&s[4..6], 16),
        )
    {
        return Color::Rgb(r, g, b);
    }
    Color::Gray
}
