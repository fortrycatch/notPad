use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph, Wrap};

use crate::app::{App, NoteDetail};

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    let Some(detail) = &app.notes.detail else {
        return;
    };
    match detail {
        NoteDetail::Loading(id) => {
            let block = Block::default().borders(Borders::ALL).title(" 加载中… ");
            let para = Paragraph::new(format!("正在加载笔记 {id} …")).block(block);
            f.render_widget(para, area);
        }
        NoteDetail::View { note, tags } => render_view(f, area, note, tags),
        NoteDetail::Edit {
            id,
            title,
            title_focus,
            textarea,
            ..
        } => render_edit(f, area, id.as_deref(), title, *title_focus, textarea),
    }
}

fn render_view(
    f: &mut Frame,
    area: Rect,
    note: &crate::api::dto::Note,
    tags: &[crate::api::dto::NoteTag],
) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(4), Constraint::Min(0)])
        .split(area);

    let mut head_lines: Vec<Line> = vec![Line::from(vec![Span::styled(
        note.title.clone(),
        Style::default()
            .add_modifier(Modifier::BOLD)
            .fg(Color::White),
    )])];
    head_lines.push(Line::from(vec![
        Span::styled(
            format!(
                "更新于 {}",
                &note.updated_at[..note.updated_at.len().min(19)]
            ),
            Style::default().fg(Color::DarkGray),
        ),
        Span::raw("   "),
        Span::styled(
            format!("ID {}", note.id),
            Style::default().fg(Color::DarkGray),
        ),
    ]));
    let mut tag_spans: Vec<Span> =
        vec![Span::styled("标签: ", Style::default().fg(Color::DarkGray))];
    if tags.is_empty() {
        tag_spans.push(Span::styled("(无)", Style::default().fg(Color::DarkGray)));
    } else {
        for t in tags {
            tag_spans.push(Span::styled(
                format!(" {} ", t.name),
                Style::default().bg(Color::DarkGray).fg(Color::White),
            ));
            tag_spans.push(Span::raw(" "));
        }
    }
    head_lines.push(Line::from(tag_spans));
    let head = Paragraph::new(head_lines).block(
        Block::default()
            .borders(Borders::ALL)
            .title(" 笔记详情 (e 编辑  t 标签  q 返回) "),
    );
    f.render_widget(head, chunks[0]);

    let body = Paragraph::new(note.content.clone())
        .wrap(Wrap { trim: false })
        .block(Block::default().borders(Borders::ALL).title(" 内容 "));
    f.render_widget(body, chunks[1]);
}

fn render_edit(
    f: &mut Frame,
    area: Rect,
    id: Option<&str>,
    title: &str,
    title_focus: bool,
    textarea: &ratatui_textarea::TextArea<'static>,
) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(0)])
        .split(area);

    let title_block = Block::default()
        .borders(Borders::ALL)
        .border_style(if title_focus {
            Style::default().fg(Color::LightMagenta)
        } else {
            Style::default().fg(Color::DarkGray)
        })
        .title(format!(
            " 标题 ({}) ",
            if id.is_some() { "编辑" } else { "新建" }
        ));
    let title_para = Paragraph::new(title.to_string())
        .style(if title_focus {
            Style::default().add_modifier(Modifier::BOLD)
        } else {
            Style::default()
        })
        .block(title_block);
    f.render_widget(title_para, chunks[0]);

    let body_block = Block::default()
        .borders(Borders::ALL)
        .border_style(if !title_focus {
            Style::default().fg(Color::LightMagenta)
        } else {
            Style::default().fg(Color::DarkGray)
        })
        .title(" 正文 (Tab 切换焦点  Ctrl+S 保存  Esc 取消) ");
    f.render_widget(body_block, chunks[1]);
    let inner_area = inner_rect(chunks[1]);
    f.render_widget(textarea, inner_area);
}

fn inner_rect(area: Rect) -> Rect {
    if area.width <= 2 || area.height <= 2 {
        return area;
    }
    Rect {
        x: area.x + 1,
        y: area.y + 1,
        width: area.width - 2,
        height: area.height - 2,
    }
}
