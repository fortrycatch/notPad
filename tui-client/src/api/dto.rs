#![allow(dead_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize)]
pub struct LoginInput {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LoginUser {
    pub id: String,
    pub name: String,
    pub email: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LoginResp {
    pub success: bool,
    #[serde(default)]
    pub token: Option<String>,
    #[serde(default)]
    pub user: Option<LoginUser>,
    #[serde(default)]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct VerifyTokenResp {
    pub ok: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct GroupMeta {
    #[serde(default, rename = "primaryColor")]
    pub primary_color: Option<String>,
    #[serde(default)]
    pub avatar: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct GroupItem {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub description: String,
    pub role: String,
    #[serde(default)]
    pub meta: Option<GroupMeta>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ProfileResp {
    pub id: String,
    pub name: String,
    pub email: String,
    #[serde(default)]
    pub meta: serde_json::Value,
}

// ─── timeline ───

#[derive(Debug, Clone, Deserialize)]
pub struct TimelineItem {
    #[serde(rename = "type")]
    pub kind: String,
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub summary: String,
    #[serde(default)]
    pub url: Option<String>,
    #[serde(default)]
    pub size: u64,
    pub created_at: String,
    #[serde(default)]
    pub bookmark_subtype: Option<String>,
    #[serde(default)]
    pub ref_id: Option<String>,
}

// ─── notes ───

#[derive(Debug, Clone, Deserialize)]
pub struct NoteListItem {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub content: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Note {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub content: String,
    pub user_id: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct NoteTag {
    pub id: i64,
    pub name: String,
    #[serde(default)]
    pub user_id: String,
    #[serde(default)]
    pub created_at: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct GetNotesInput {
    pub page: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tag_id: Option<i64>,
}

#[derive(Debug, Clone, Serialize)]
pub struct GetNoteByIdInput {
    pub id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateNoteInput {
    pub title: String,
    pub content: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct UpdateNoteInput {
    pub id: String,
    pub title: String,
    pub content: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct DeleteNoteInput {
    pub id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateTagInput {
    pub name: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct GetNoteTagsInput {
    pub note_id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct NoteTagBindInput {
    pub note_id: String,
    pub tag_id: i64,
}

// ─── todo ───

#[derive(Debug, Clone, Deserialize)]
pub struct TodoList {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub color: String,
    #[serde(default)]
    pub sort_order: i64,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Deserialize, Default)]
#[serde(default)]
pub struct TodoRef {
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(rename = "refId")]
    pub ref_id: String,
    pub title: String,
    pub url: Option<String>,
    #[serde(rename = "mimeType")]
    pub mime_type: Option<String>,
    #[serde(rename = "bookmarkType")]
    pub bookmark_type: Option<String>,
    #[serde(rename = "targetRefId")]
    pub target_ref_id: Option<String>,
}

fn deserialize_refs<'de, D>(d: D) -> Result<Vec<TodoRef>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    use serde::de::Error as _;
    let v = serde_json::Value::deserialize(d)?;
    match v {
        serde_json::Value::Null => Ok(vec![]),
        serde_json::Value::Array(arr) => arr
            .into_iter()
            .map(|item| serde_json::from_value::<TodoRef>(item).map_err(D::Error::custom))
            .collect(),
        serde_json::Value::String(s) => {
            if s.is_empty() {
                return Ok(vec![]);
            }
            let parsed: serde_json::Value =
                serde_json::from_str(&s).map_err(D::Error::custom)?;
            match parsed {
                serde_json::Value::Array(arr) => arr
                    .into_iter()
                    .map(|item| {
                        serde_json::from_value::<TodoRef>(item).map_err(D::Error::custom)
                    })
                    .collect(),
                _ => Ok(vec![]),
            }
        }
        _ => Ok(vec![]),
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct TodoItem {
    pub id: String,
    pub list_id: String,
    pub title: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub done: i64,
    #[serde(default)]
    pub color: Option<String>,
    #[serde(default)]
    pub sort_order: i64,
    #[serde(default, deserialize_with = "deserialize_refs")]
    pub refs: Vec<TodoRef>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct TodoListWithItems {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub color: String,
    #[serde(default)]
    pub sort_order: i64,
    pub created_at: String,
    pub updated_at: String,
    #[serde(default)]
    pub items: Vec<TodoItem>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateListInput {
    pub name: String,
    pub color: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct UpdateListInput {
    pub id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub color: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateItemInput {
    #[serde(rename = "listId")]
    pub list_id: String,
    pub title: String,
    pub description: String,
    pub color: Option<String>,
    pub refs: Vec<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize)]
pub struct UpdateItemInput {
    pub id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub done: Option<i64>,
}

// ─── image bed ───

#[derive(Debug, Clone, Deserialize)]
pub struct ImageItem {
    pub id: i64,
    pub name: String,
    pub url: String,
    #[serde(default)]
    pub size: u64,
    #[serde(default)]
    pub remark: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ImageListInput {
    pub user_id: String,
    pub offset: u32,
    pub sort: String,
    pub search: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tag_id: Option<i64>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ImageRenameInput {
    pub id: i64,
    pub name: String,
}

// ─── file drive ───

#[derive(Debug, Clone, Deserialize)]
pub struct DriveFolder {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub parent_id: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct DriveFile {
    pub id: i64,
    pub name: String,
    pub oss_key: String,
    #[serde(default)]
    pub size: u64,
    #[serde(default)]
    pub mime_type: String,
    #[serde(default)]
    pub folder_id: Option<String>,
    pub created_at: String,
    #[serde(default)]
    pub public_url: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct DriveListResp {
    #[serde(rename = "currentFolder", default)]
    pub current_folder: Option<DriveFolder>,
    #[serde(default)]
    pub breadcrumbs: Vec<DriveFolder>,
    #[serde(default)]
    pub folders: Vec<DriveFolder>,
    #[serde(default)]
    pub files: Vec<DriveFile>,
    #[serde(rename = "hasMore", default)]
    pub has_more: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct DriveListInput {
    pub folder_id: Option<String>,
    pub offset: u32,
    pub sort: String,
    pub search: String,
    pub search_scope: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct DriveGetUploadUrlInput {
    pub filename: String,
    #[serde(rename = "type")]
    pub content_type: String,
    pub folder_id: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct DriveUploadUrlResp {
    pub url: String,
    pub filename: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct DriveAddFileInput {
    pub name: String,
    pub filename: String,
    pub folder_id: Option<String>,
    pub mime_type: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RenameFileInput {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RenameFolderInput {
    pub id: String,
    pub name: String,
}

// ─── account: usage + sessions ───

#[derive(Debug, Clone, Deserialize, Default)]
pub struct UsageStats {
    #[serde(default)]
    pub notes_count: u64,
    #[serde(default)]
    pub bookmarks_count: u64,
    #[serde(default)]
    pub images_count: u64,
    #[serde(default)]
    pub images_size: u64,
    #[serde(default)]
    pub files_count: u64,
    #[serde(default)]
    pub files_size: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AuthTokenRow {
    pub token: String,
    pub created_at: String,
    #[serde(default)]
    pub used_at: Option<String>,
    #[serde(default)]
    pub user_agent: Option<String>,
    #[serde(default)]
    pub alias: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SetTokenAliasInput {
    #[serde(rename = "tokenHash")]
    pub token_hash: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub alias: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct RevokeTokenInput {
    #[serde(rename = "tokenHash")]
    pub token_hash: String,
}
