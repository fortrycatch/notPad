mod api;
mod app;
mod config;
mod event;
mod ui;
mod util;

use std::env;

use anyhow::Result;

use crate::api::ApiClient;
use crate::config::AppConfig;

fn parse_args(args: &[String]) -> (Option<String>, bool) {
    let mut server: Option<String> = None;
    let mut logout = false;
    let mut iter = args.iter();
    while let Some(a) = iter.next() {
        match a.as_str() {
            "--server" => {
                if let Some(v) = iter.next() {
                    server = Some(v.clone());
                }
            }
            "--logout" => logout = true,
            "-h" | "--help" => {
                println!("notpad-tui — terminal client for notpad");
                println!();
                println!("USAGE:");
                println!("  notpad-tui [OPTIONS]");
                println!();
                println!("OPTIONS:");
                println!("  --server <URL>   Override server URL (persisted)");
                println!("  --logout         Clear stored token and exit");
                println!("  -h, --help       Show this help");
                std::process::exit(0);
            }
            _ => {}
        }
    }
    (server, logout)
}

#[tokio::main]
async fn main() -> Result<()> {
    let raw: Vec<String> = env::args().skip(1).collect();
    let (server_override, logout) = parse_args(&raw);

    let mut cfg = AppConfig::load().unwrap_or_default();
    if let Some(s) = server_override {
        cfg.set_server_url(s)?;
    }
    if logout {
        cfg.set_token(None)?;
        cfg.set_active_group(None)?;
        println!("token 已清除。");
        return Ok(());
    }

    let api = ApiClient::new(
        cfg.server_url.clone(),
        cfg.token.clone(),
        cfg.active_group_id.clone(),
    )?;
    if let Err(e) = app::run(api, cfg).await {
        eprintln!("程序异常退出: {e:#}");
        std::process::exit(1);
    }
    Ok(())
}
