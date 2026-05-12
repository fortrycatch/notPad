use ratatui::Frame;
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Padding, Paragraph};

use crate::app::App;

pub fn render(f: &mut Frame, app: &App) {
    let area = f.area();

    // Centered 60-wide × 16-tall panel. We pick 16 rows so that after the
    // outer borders + horizontal padding + 7 vertical content rows we still
    // have room for the input fields' inner text rows. Earlier the panel was
    // only 14 rows tall, which forced the constraint solver to compress one
    // of the 3-row input fields down to 2 rows — leaving 0 rows of inner
    // text area and making typed input completely invisible.
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Min(0),
            Constraint::Length(16),
            Constraint::Min(0),
        ])
        .split(area);
    let middle = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Min(0),
            Constraint::Length(60),
            Constraint::Min(0),
        ])
        .split(chunks[1]);
    let panel = middle[1];

    let outer = Block::default()
        .borders(Borders::ALL)
        .padding(Padding::horizontal(2))
        .title(" notpad-tui · 登录 ")
        .border_style(Style::default().fg(Color::LightMagenta));
    let inner_area = outer.inner(panel);
    f.render_widget(outer, panel);

    // Now split the inner content area; constraint sum is 1+1+3+1+3+1+1 = 11
    // rows which fits comfortably inside the 14-row inner area.
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1), // server line
            Constraint::Length(1), // gap
            Constraint::Length(3), // username
            Constraint::Length(1), // gap
            Constraint::Length(3), // password
            Constraint::Length(1), // gap
            Constraint::Length(1), // status / hint
        ])
        .split(inner_area);

    let server_line = Paragraph::new(format!("服务器: {}", app.api.base_url()))
        .style(Style::default().fg(Color::DarkGray));
    f.render_widget(server_line, rows[0]);

    render_field(
        f,
        rows[2],
        "用户ID / 邮箱",
        &app.login.username,
        app.login.focus == 0,
        false,
    );
    render_field(
        f,
        rows[4],
        "密码",
        &app.login.password,
        app.login.focus == 1,
        true,
    );

    let status = if app.login.submitting {
        Span::styled("登录中…", Style::default().fg(Color::Yellow))
    } else if let Some(err) = &app.login.error {
        Span::styled(err.clone(), Style::default().fg(Color::Red))
    } else {
        Span::styled(
            "Tab 切换字段  Enter 提交  Esc 退出",
            Style::default().fg(Color::DarkGray),
        )
    };
    let status = Paragraph::new(Line::from(status)).alignment(Alignment::Center);
    f.render_widget(status, rows[6]);
}

fn render_field(f: &mut Frame, area: Rect, label: &str, value: &str, focus: bool, mask: bool) {
    let display: String = if mask {
        "*".repeat(value.chars().count())
    } else {
        value.to_string()
    };

    let border_style = if focus {
        Style::default()
            .fg(Color::LightMagenta)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(Color::DarkGray)
    };
    let block = Block::default()
        .borders(Borders::ALL)
        .padding(Padding::horizontal(1))
        .title(format!(" {label} "))
        .title_style(if focus {
            Style::default()
                .fg(Color::LightMagenta)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(Color::Gray)
        })
        .border_style(border_style);

    // Render the input text with an explicit, terminal-default-friendly
    // foreground — applying the focus style only to the text Span (not via
    // Paragraph::style, which would also restyle the surrounding block and
    // clobber the title color).
    let text_style = if focus {
        Style::default()
            .fg(Color::White)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(Color::Gray)
    };
    let line = if display.is_empty() && focus {
        // Show a visible cursor caret so the user can tell the field is
        // active even before they type anything.
        Line::from(Span::styled("▏", text_style))
    } else if focus {
        Line::from(vec![
            Span::styled(display, text_style),
            Span::styled("▏", text_style),
        ])
    } else {
        Line::from(Span::styled(display, text_style))
    };
    let para = Paragraph::new(line).block(block);
    f.render_widget(para, area);
}
