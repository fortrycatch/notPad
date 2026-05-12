use ratatui::Frame;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, List, ListItem, ListState, Padding, Paragraph};

use crate::app::{App, COLOR_PRESETS, SettingsSection};

pub fn render(f: &mut Frame, app: &App, area: Rect) {
    // Two-column layout, mirroring the todo tab: a narrow section list on
    // the left and the section content on the right.
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Length(22), Constraint::Min(0)])
        .split(area);
    render_sections(f, app, chunks[0]);
    render_section_body(f, app, chunks[1]);
}

fn render_sections(f: &mut Frame, app: &App, area: Rect) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(if !app.settings.focus_right {
            Style::default().fg(Color::LightMagenta)
        } else {
            Style::default().fg(Color::DarkGray)
        })
        .title(" 设置 ");

    let items: Vec<ListItem> = SettingsSection::ALL
        .iter()
        .map(|s| {
            let (glyph, glyph_style) = match s {
                SettingsSection::Theme => (" ● ", Style::default().fg(Color::LightMagenta)),
                SettingsSection::Download => (" ● ", Style::default().fg(Color::LightCyan)),
                SettingsSection::Account => (" ● ", Style::default().fg(Color::LightYellow)),
            };
            ListItem::new(Line::from(vec![
                Span::styled(glyph, glyph_style),
                Span::raw(s.label()),
            ]))
        })
        .collect();

    let mut state = ListState::default();
    state.select(Some(app.settings.section_cursor));
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

fn render_section_body(f: &mut Frame, app: &App, area: Rect) {
    let section = app.settings.current_section();
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(if app.settings.focus_right {
            Style::default().fg(Color::LightMagenta)
        } else {
            Style::default().fg(Color::DarkGray)
        })
        .padding(Padding::horizontal(1))
        .title(format!(" {} ", section.label()));
    let inner = block.inner(area);
    f.render_widget(block, area);

    match section {
        SettingsSection::Theme => render_theme_pane(f, app, inner),
        SettingsSection::Download => render_download_pane(f, app, inner),
        SettingsSection::Account => render_account_pane(f, app, inner),
    }
}

// ─── Download ────────────────────────────────────────────────────────────

fn render_download_pane(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(2), // current value summary
            Constraint::Length(1), // hint
            Constraint::Length(1), // divider
            Constraint::Min(0),    // actions
        ])
        .split(area);

    // Resolve what would happen right now (so the user can see whether
    // they're on the configured value or the OS-default fallback).
    let effective = crate::util::resolve_default_download_dir(&app.config);
    let configured = app
        .config
        .download_dir
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());
    let summary = vec![
        Line::from(vec![
            Span::styled("已配置: ", Style::default().fg(Color::DarkGray)),
            match configured {
                Some(p) => Span::styled(
                    p.to_string(),
                    Style::default()
                        .add_modifier(Modifier::BOLD)
                        .fg(Color::White),
                ),
                None => Span::styled(
                    "(未配置，按 Enter 编辑)",
                    Style::default().fg(Color::DarkGray),
                ),
            },
        ]),
        Line::from(vec![
            Span::styled("生效目录: ", Style::default().fg(Color::DarkGray)),
            Span::styled(
                effective.display().to_string(),
                Style::default().fg(Color::LightCyan),
            ),
        ]),
    ];
    f.render_widget(Paragraph::new(summary), chunks[0]);

    let hint = Paragraph::new(Line::from(Span::styled(
        "提示: 下载时仍可在「配置目录」和「当前工作目录」之间选择。",
        Style::default().fg(Color::DarkGray),
    )));
    f.render_widget(hint, chunks[1]);

    f.render_widget(
        Paragraph::new(Line::from(Span::styled(
            "── 操作 ──",
            Style::default()
                .fg(Color::LightCyan)
                .add_modifier(Modifier::BOLD),
        ))),
        chunks[2],
    );

    let items: Vec<ListItem> = vec![
        ListItem::new(Line::from(vec![
            Span::raw("   "),
            Span::styled(
                "✎ 编辑下载目录",
                Style::default().add_modifier(Modifier::BOLD),
            ),
            Span::styled("  Enter", Style::default().fg(Color::DarkGray)),
        ])),
        ListItem::new(Line::from(vec![
            Span::raw("   "),
            Span::styled(
                "↺ 恢复默认（系统 Downloads）",
                Style::default().fg(Color::LightYellow),
            ),
        ])),
    ];

    let mut state = ListState::default();
    state.select(Some(app.settings.action_cursor));
    let list = List::new(items)
        .highlight_style(highlight_style(app))
        .highlight_symbol(highlight_symbol(app));
    f.render_stateful_widget(list, chunks[3], &mut state);
}

// ─── Theme ───────────────────────────────────────────────────────────────

fn render_theme_pane(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(2), // current scope summary
            Constraint::Length(1), // hint about permissions
            Constraint::Length(1), // section divider
            Constraint::Min(0),    // actions list
        ])
        .split(area);

    render_scope_summary(f, app, chunks[0]);

    let hint = Paragraph::new(Line::from(Span::styled(
        "提示: 群组色需要管理员/所有者权限，个人色仅本人可见。",
        Style::default().fg(Color::DarkGray),
    )));
    f.render_widget(hint, chunks[1]);

    f.render_widget(
        Paragraph::new(Line::from(Span::styled(
            "── 主题色 ──",
            Style::default()
                .fg(Color::LightMagenta)
                .add_modifier(Modifier::BOLD),
        ))),
        chunks[2],
    );

    render_theme_actions(f, app, chunks[3]);
}

fn render_scope_summary(f: &mut Frame, app: &App, area: Rect) {
    let scope_label = match (&app.active_group_id, &app.active_group_name) {
        (None, _) => "个人空间".to_string(),
        (Some(_), Some(name)) => format!("群组 · {name}"),
        (Some(_), None) => "群组".to_string(),
    };
    let cur_color = app
        .active_primary_color()
        .unwrap_or_else(|| "(未设置)".to_string());

    let lines = vec![
        Line::from(vec![
            Span::styled("当前空间: ", Style::default().fg(Color::DarkGray)),
            Span::styled(
                scope_label,
                Style::default()
                    .add_modifier(Modifier::BOLD)
                    .fg(Color::White),
            ),
        ]),
        Line::from(vec![
            Span::styled("当前主题色: ", Style::default().fg(Color::DarkGray)),
            color_swatch(&cur_color),
            Span::raw(" "),
            Span::styled(cur_color, Style::default().fg(Color::Gray)),
        ]),
    ];
    f.render_widget(Paragraph::new(lines), area);
}

fn render_theme_actions(f: &mut Frame, app: &App, area: Rect) {
    let active = app
        .active_primary_color()
        .map(|s| s.to_ascii_lowercase())
        .unwrap_or_default();

    let mut items: Vec<ListItem> = COLOR_PRESETS
        .iter()
        .map(|(name, hex)| {
            let mark = if active == hex.to_ascii_lowercase() {
                Span::styled(" ✓ ", Style::default().fg(Color::LightGreen))
            } else {
                Span::raw("   ")
            };
            ListItem::new(Line::from(vec![
                mark,
                color_swatch(hex),
                Span::raw(" "),
                Span::styled(
                    format!("{name:<6}"),
                    Style::default().add_modifier(Modifier::BOLD),
                ),
                Span::styled(format!(" {hex}"), Style::default().fg(Color::DarkGray)),
            ]))
        })
        .collect();

    // Custom hex input row.
    let editing = app.settings.editing_custom;
    let custom_value = app.settings.custom_input.clone();
    let custom_preview = if editing && custom_value.is_empty() {
        "▏".to_string()
    } else if editing {
        format!("{custom_value}▏")
    } else if custom_value.is_empty() {
        "(按 Enter 编辑)".to_string()
    } else {
        custom_value.clone()
    };
    let custom_style = if editing {
        Style::default()
            .fg(Color::Black)
            .bg(Color::White)
            .add_modifier(Modifier::BOLD)
    } else if custom_value.is_empty() {
        Style::default().fg(Color::DarkGray)
    } else {
        Style::default().fg(Color::White)
    };
    items.push(ListItem::new(Line::from(vec![
        Span::raw("   "),
        Span::styled(
            "✎ 自定义色值: ",
            Style::default().add_modifier(Modifier::BOLD),
        ),
        Span::styled(custom_preview, custom_style),
    ])));

    // Reset row.
    items.push(ListItem::new(Line::from(vec![
        Span::raw("   "),
        Span::styled("↺ 恢复默认主题色", Style::default().fg(Color::LightYellow)),
    ])));

    let mut state = ListState::default();
    state.select(Some(app.settings.action_cursor));
    let list = List::new(items)
        .highlight_style(highlight_style(app))
        .highlight_symbol(highlight_symbol(app));
    f.render_stateful_widget(list, area, &mut state);
}

// ─── Account ─────────────────────────────────────────────────────────────

fn render_account_pane(f: &mut Frame, app: &App, area: Rect) {
    if app.active_group_id.is_some() {
        render_account_in_group(f, app, area);
    } else {
        render_account_personal(f, app, area);
    }
}

/// 群组空间：与网页一致，仅保留资料摘要 + 退出登录。
fn render_account_in_group(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(4),
            Constraint::Length(1),
            Constraint::Min(0),
        ])
        .split(area);

    render_account_user_header(f, app, chunks[0]);

    f.render_widget(
        Paragraph::new(Line::from(Span::styled(
            "── 账户 ──",
            Style::default()
                .fg(Color::LightYellow)
                .add_modifier(Modifier::BOLD),
        ))),
        chunks[1],
    );

    let sel = app.settings.focus_right && app.settings.action_cursor == 0;
    let block = account_section_block(" 账户 ", sel, chunks[2]);
    let inner = block.inner(chunks[2]);
    f.render_widget(block, chunks[2]);
    let logout_line = account_logout_line(sel);
    f.render_widget(Paragraph::new(logout_line), inner);
}

/// 个人空间：用量 → 账户（退出登录）→ 登录设备；光标顺序与自上而下视觉一致。
fn render_account_personal(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(4),  // 用户摘要
            Constraint::Length(12), // 用量卡片（含「重新统计」）
            Constraint::Length(5),  // 账户（退出登录）
            Constraint::Min(6),     // 登录设备
        ])
        .split(area);

    render_account_user_header(f, app, chunks[0]);
    render_usage_card(f, app, chunks[1]);

    let logout_sel = app.settings.focus_right && app.settings.action_cursor == 1;
    let block = account_section_block(" 账户 ", logout_sel, chunks[2]);
    let inner = block.inner(chunks[2]);
    f.render_widget(block, chunks[2]);
    let logout_line = account_logout_line(logout_sel);
    f.render_widget(Paragraph::new(logout_line), inner);

    render_devices_card(f, app, chunks[3]);
}

fn render_account_user_header(f: &mut Frame, app: &App, area: Rect) {
    let user = app
        .username
        .clone()
        .unwrap_or_else(|| "(未命名)".to_string());
    let scope_label = match (&app.active_group_id, &app.active_group_name) {
        (None, _) => "个人空间".to_string(),
        (Some(_), Some(name)) => format!("群组 · {name}"),
        (Some(_), None) => "群组".to_string(),
    };

    let info = vec![
        Line::from(vec![
            Span::styled("用户: ", Style::default().fg(Color::DarkGray)),
            Span::styled(
                user,
                Style::default()
                    .add_modifier(Modifier::BOLD)
                    .fg(Color::White),
            ),
        ]),
        Line::from(vec![
            Span::styled("服务器: ", Style::default().fg(Color::DarkGray)),
            Span::raw(truncate_to_width(&app.api.base_url(), area.width as usize)),
        ]),
        Line::from(vec![
            Span::styled("当前空间: ", Style::default().fg(Color::DarkGray)),
            Span::raw(scope_label),
        ]),
    ];
    f.render_widget(Paragraph::new(info), area);
}

fn account_section_block(title: &str, selected: bool, _area: Rect) -> Block<'_> {
    let border = if selected {
        Style::default().fg(Color::LightMagenta)
    } else {
        Style::default().fg(Color::DarkGray)
    };
    Block::default()
        .borders(Borders::ALL)
        .border_style(border)
        .title(title.to_string())
}

fn account_logout_line(selected: bool) -> Line<'static> {
    let sym = if selected { "» " } else { "  " };
    let base = Style::default()
        .fg(Color::LightRed)
        .add_modifier(Modifier::BOLD);
    let st = account_row_style(selected, base);
    Line::from(vec![Span::styled(sym, st), Span::styled("⏻ 退出登录", st)])
}

/// 用量卡片：统计数字 + 单独一行的「重新统计」（光标索引 0）。
fn render_usage_card(f: &mut Frame, app: &App, area: Rect) {
    let sel = app.settings.focus_right && app.settings.action_cursor == 0;
    let block = account_section_block(" 用量数据 ", sel, area);
    let inner = block.inner(area);
    f.render_widget(block, area);

    let body = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(5), Constraint::Length(1)])
        .split(inner);

    let mut stat_lines: Vec<Line> = Vec::new();
    if app.settings.usage_loading {
        stat_lines.push(Line::from(Span::styled(
            "  加载中…",
            Style::default().fg(Color::DarkGray),
        )));
    } else if let Some(ref s) = app.settings.usage {
        stat_lines.push(usage_line("笔记", s.notes_count, None));
        stat_lines.push(usage_line("书签", s.bookmarks_count, None));
        stat_lines.push(usage_line("图片", s.images_count, Some(s.images_size)));
        stat_lines.push(usage_line("文件", s.files_count, Some(s.files_size)));
    } else {
        stat_lines.push(Line::from(Span::styled(
            "  (暂无数据)",
            Style::default().fg(Color::DarkGray),
        )));
    }
    f.render_widget(Paragraph::new(stat_lines), body[0]);

    let rec_style_base = if app.settings.usage_recalculating {
        Style::default().fg(Color::DarkGray)
    } else {
        Style::default().fg(Color::LightGreen)
    };
    let rec_st = account_row_style(sel, rec_style_base.add_modifier(Modifier::BOLD));
    let rec_label = if app.settings.usage_recalculating {
        "↻ 正在重新统计…"
    } else {
        "↻ 重新统计用量"
    };
    let rec_line = Line::from(vec![
        Span::styled(if sel { "» " } else { "  " }, rec_st),
        Span::styled(rec_label, rec_st),
        Span::styled("  Enter", Style::default().fg(Color::DarkGray)),
    ]);
    f.render_widget(Paragraph::new(rec_line), body[1]);
}

fn account_row_style(selected: bool, base: Style) -> Style {
    if selected {
        base.bg(Color::DarkGray)
    } else {
        base
    }
}

/// 登录设备卡片：仅会话列表（光标 2..=n+1，在「账户」板块之下）。
fn render_devices_card(f: &mut Frame, app: &App, area: Rect) {
    let n = app.settings.tokens.len();
    let any_sel = n > 0 && (2..=n + 1).contains(&app.settings.action_cursor);
    let block = account_section_block(" 登录设备 ", app.settings.focus_right && any_sel, area);
    let inner = block.inner(area);
    f.render_widget(block, area);

    let sub = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(2), Constraint::Min(0)])
        .split(inner);

    let status_line = if app.settings.tokens_loading && app.settings.tokens.is_empty() {
        Line::from(Span::styled(
            "  会话列表加载中…",
            Style::default().fg(Color::DarkGray),
        ))
    } else if !app.settings.tokens_loading && app.settings.tokens.is_empty() {
        Line::from(Span::styled(
            "  暂无其它登录会话",
            Style::default().fg(Color::DarkGray),
        ))
    } else {
        Line::default()
    };
    let hint = Paragraph::new(vec![
        Line::from(vec![
            Span::styled("Enter ", Style::default().fg(Color::White)),
            Span::styled("重命名  ", Style::default().fg(Color::DarkGray)),
            Span::styled("d", Style::default().fg(Color::LightRed)),
            Span::styled(" 移除", Style::default().fg(Color::DarkGray)),
        ]),
        status_line,
    ]);
    f.render_widget(hint, sub[0]);

    let mut lines: Vec<Line> = Vec::new();
    for (i, t) in app.settings.tokens.iter().enumerate() {
        let row_cursor = i + 2;
        let sel = app.settings.focus_right && app.settings.action_cursor == row_cursor;
        let title = t
            .alias
            .as_deref()
            .filter(|s| !s.is_empty())
            .unwrap_or("未命名会话");
        let kind = device_kind_label(t.user_agent.as_deref());
        let created = short_datetime(&t.created_at);
        let used = t
            .used_at
            .as_deref()
            .map(short_datetime)
            .map(|u| format!(" · 最近 {u}"))
            .unwrap_or_default();
        let ua_one = t
            .user_agent
            .as_deref()
            .map(|ua| truncate_to_width(ua, 72))
            .unwrap_or_else(|| "无 UA".to_string());

        let st0 = account_row_style(
            sel,
            Style::default()
                .add_modifier(Modifier::BOLD)
                .fg(Color::White),
        );
        let st1 = account_row_style(sel, Style::default().fg(Color::DarkGray));
        lines.push(Line::from(vec![
            Span::styled(if sel { "» " } else { "  " }, st0),
            Span::styled(format!("{kind} "), Style::default().fg(Color::Cyan)),
            Span::styled(truncate_to_width(title, 36), st0),
        ]));
        lines.push(Line::from(vec![
            Span::styled("      ", st1),
            Span::styled(format!("创建于 {created}{used}"), st1),
        ]));
        lines.push(Line::from(vec![
            Span::styled("      ", st1),
            Span::styled(ua_one, st1),
        ]));
    }
    f.render_widget(Paragraph::new(lines), sub[1]);
}

fn usage_line(label: &'static str, count: u64, size: Option<u64>) -> Line<'static> {
    let size_s = size.map(format_bytes).unwrap_or_default();
    Line::from(vec![
        Span::styled(format!("  {label}: "), Style::default().fg(Color::DarkGray)),
        Span::styled(
            format!("{count}"),
            Style::default()
                .add_modifier(Modifier::BOLD)
                .fg(Color::White),
        ),
        Span::styled(size_s, Style::default().fg(Color::DarkGray)),
    ])
}

fn format_bytes(n: u64) -> String {
    if n == 0 {
        return String::new();
    }
    if n < 1024 {
        format!("  {n} B")
    } else if n < 1024 * 1024 {
        format!("  {:.1} KB", n as f64 / 1024.0)
    } else if n < 1024 * 1024 * 1024 {
        format!("  {:.1} MB", n as f64 / (1024.0 * 1024.0))
    } else {
        format!("  {:.2} GB", n as f64 / (1024.0 * 1024.0 * 1024.0))
    }
}

fn device_kind_label(ua: Option<&str>) -> &'static str {
    let Some(ua) = ua.map(str::trim).filter(|s| !s.is_empty()) else {
        return "未知";
    };
    let s = ua.to_ascii_lowercase();
    let s = s.as_str();
    if regex_like_tablet(s) {
        return "平板";
    }
    if regex_like_phone(s) {
        return "手机";
    }
    "电脑"
}

fn regex_like_tablet(s: &str) -> bool {
    if s.contains("ipad") || s.contains("tablet") || s.contains("playbook") || s.contains("kindle")
    {
        return true;
    }
    if s.contains("silk") && !s.contains("silk/") {
        return true;
    }
    s.contains("android") && !s.contains("mobile")
}

fn regex_like_phone(s: &str) -> bool {
    s.contains("iphone")
        || s.contains("ipod")
        || s.contains("windows phone")
        || s.contains("iemobile")
        || s.contains("blackberry")
        || s.contains("bb10")
        || s.contains("opera mini")
        || s.contains("mobile")
        || s.contains("android") && s.contains("mobile")
}

fn short_datetime(s: &str) -> String {
    if let Ok(dt) = chrono::DateTime::parse_from_rfc3339(s) {
        return dt
            .with_timezone(&chrono::Local)
            .format("%Y-%m-%d %H:%M")
            .to_string();
    }
    if let Ok(nd) = chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S") {
        return nd.format("%Y-%m-%d %H:%M").to_string();
    }
    if s.len() >= 16 {
        return s.chars().take(16).collect();
    }
    s.to_string()
}

fn truncate_to_width(s: &str, max_chars: usize) -> String {
    let count = s.chars().count();
    if count <= max_chars {
        return s.to_string();
    }
    let take = max_chars.saturating_sub(1);
    s.chars().take(take).chain(std::iter::once('…')).collect()
}

// ─── Shared bits ─────────────────────────────────────────────────────────

fn highlight_style(app: &App) -> Style {
    // Only paint the selection bar when the right pane is focused, so the
    // user has an unambiguous focus indicator at any moment.
    if app.settings.focus_right {
        Style::default()
            .bg(Color::DarkGray)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default()
    }
}

fn highlight_symbol(app: &App) -> &'static str {
    if app.settings.focus_right {
        "» "
    } else {
        "  "
    }
}

/// Render a small inline color swatch for the given `#rrggbb` / `#rgb`
/// string. Falls back to a neutral gray block when the value can't be
/// parsed (e.g. when nothing is configured yet).
fn color_swatch(hex: &str) -> Span<'static> {
    let color = parse_hex(hex)
        .map(|(r, g, b)| Color::Rgb(r, g, b))
        .unwrap_or(Color::DarkGray);
    Span::styled("██", Style::default().fg(color))
}

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
