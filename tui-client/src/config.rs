use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result};
use directories::ProjectDirs;
use serde::{Deserialize, Serialize};

pub const DEFAULT_SERVER_URL: &str = "https://note.kt.sb/";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub server_url: String,
    pub token: Option<String>,
    #[serde(default)]
    pub active_group_id: Option<String>,
    #[serde(default)]
    pub download_dir: Option<String>,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            server_url: DEFAULT_SERVER_URL.to_string(),
            token: None,
            active_group_id: None,
            download_dir: None,
        }
    }
}

fn config_dir() -> Result<PathBuf> {
    let dirs = ProjectDirs::from("", "", "notpad-tui")
        .context("could not resolve platform config directory")?;
    Ok(dirs.config_dir().to_path_buf())
}

pub fn config_path() -> Result<PathBuf> {
    Ok(config_dir()?.join("config.json"))
}

impl AppConfig {
    pub fn load() -> Result<Self> {
        let path = config_path()?;
        if !path.exists() {
            return Ok(Self::default());
        }
        let raw = fs::read_to_string(&path)
            .with_context(|| format!("read config: {}", path.display()))?;
        let cfg: AppConfig = serde_json::from_str(&raw)
            .with_context(|| format!("parse config: {}", path.display()))?;
        Ok(cfg)
    }

    pub fn save(&self) -> Result<()> {
        let dir = config_dir()?;
        fs::create_dir_all(&dir)
            .with_context(|| format!("create config dir: {}", dir.display()))?;
        let path = dir.join("config.json");
        let raw = serde_json::to_string_pretty(self)?;
        fs::write(&path, raw).with_context(|| format!("write config: {}", path.display()))?;
        Ok(())
    }

    pub fn set_server_url(&mut self, url: String) -> Result<()> {
        self.server_url = url;
        self.save()
    }

    pub fn set_token(&mut self, token: Option<String>) -> Result<()> {
        self.token = token;
        self.save()
    }

    pub fn set_active_group(&mut self, group_id: Option<String>) -> Result<()> {
        self.active_group_id = group_id;
        self.save()
    }

    pub fn set_download_dir(&mut self, dir: Option<String>) -> Result<()> {
        self.download_dir = dir.map(|s| s.trim().to_string()).filter(|s| !s.is_empty());
        self.save()
    }
}
