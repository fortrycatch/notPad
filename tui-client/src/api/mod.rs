#![allow(dead_code)]

pub mod dto;

use std::sync::{Arc, RwLock};
use std::time::Duration;

use anyhow::{Context, Result, anyhow};
use reqwest::Method;
use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::Value;

#[derive(Clone)]
pub struct ApiClient {
    inner: Arc<Inner>,
}

struct Inner {
    http: reqwest::Client,
    base_url: RwLock<String>,
    token: RwLock<Option<String>>,
    group_id: RwLock<Option<String>>,
}

impl ApiClient {
    pub fn new(
        base_url: String,
        token: Option<String>,
        group_id: Option<String>,
    ) -> Result<Self> {
        let http = reqwest::Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .context("build http client")?;
        Ok(Self {
            inner: Arc::new(Inner {
                http,
                base_url: RwLock::new(base_url),
                token: RwLock::new(token),
                group_id: RwLock::new(group_id),
            }),
        })
    }

    pub fn set_token(&self, token: Option<String>) {
        *self.inner.token.write().unwrap() = token;
    }

    pub fn token(&self) -> Option<String> {
        self.inner.token.read().unwrap().clone()
    }

    pub fn base_url(&self) -> String {
        self.inner.base_url.read().unwrap().clone()
    }

    pub fn set_base_url(&self, url: String) {
        *self.inner.base_url.write().unwrap() = url;
    }

    pub fn set_group(&self, group_id: Option<String>) {
        *self.inner.group_id.write().unwrap() = group_id;
    }

    pub fn group_id(&self) -> Option<String> {
        self.inner.group_id.read().unwrap().clone()
    }

    /// Shared HTTP client for ad-hoc operations (e.g. file downloads) that
    /// don't go through the tRPC envelope. Keeps connection pooling but
    /// callers can override per-request timeout.
    pub fn http_client(&self) -> reqwest::Client {
        self.inner.http.clone()
    }

    fn endpoint(&self, path: &str) -> String {
        let base = self.base_url();
        let trimmed = base.trim_end_matches('/');
        format!("{trimmed}/trpc/{path}")
    }

    fn apply_headers(&self, mut req: reqwest::RequestBuilder) -> reqwest::RequestBuilder {
        if let Some(t) = self.token() {
            req = req.header("token", t);
        }
        if let Some(g) = self.group_id() {
            req = req.header("x-group-id", g);
        }
        req
    }

    pub async fn query<I, O>(&self, path: &str, input: Option<&I>) -> Result<O>
    where
        I: Serialize + ?Sized,
        O: DeserializeOwned,
    {
        let mut url = self.endpoint(path);
        if let Some(i) = input {
            let json = serde_json::to_string(i)?;
            url.push_str("?input=");
            url.push_str(&urlencoding::encode(&json));
        }
        let req = self.apply_headers(self.inner.http.request(Method::GET, &url));
        let resp = req.send().await.with_context(|| format!("GET {url}"))?;
        decode_trpc(resp).await
    }

    pub async fn query_no_input<O>(&self, path: &str) -> Result<O>
    where
        O: DeserializeOwned,
    {
        self.query::<(), O>(path, None).await
    }

    pub async fn mutation<I, O>(&self, path: &str, input: &I) -> Result<O>
    where
        I: Serialize + ?Sized,
        O: DeserializeOwned,
    {
        let url = self.endpoint(path);
        let req = self
            .apply_headers(self.inner.http.request(Method::POST, &url))
            .json(input);
        let resp = req.send().await.with_context(|| format!("POST {url}"))?;
        decode_trpc(resp).await
    }
}

async fn decode_trpc<O: DeserializeOwned>(resp: reqwest::Response) -> Result<O> {
    let status = resp.status();
    let text = resp.text().await.context("read response body")?;
    let value: Value = serde_json::from_str(&text)
        .with_context(|| format!("response not JSON ({status}): {text}"))?;

    if !status.is_success() {
        let msg = value
            .get("error")
            .and_then(|e| e.get("message"))
            .and_then(|m| m.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| format!("HTTP {status}: {text}"));
        return Err(anyhow!(msg));
    }

    let data = value
        .get("result")
        .and_then(|r| r.get("data"))
        .ok_or_else(|| anyhow!("missing result.data: {text}"))?;

    let parsed = serde_json::from_value::<O>(data.clone())
        .with_context(|| format!("decode result.data: {data}"))?;
    Ok(parsed)
}

// ─── Typed helpers grouped by router ──────────────────────────────────────

use dto::*;

impl ApiClient {
    // auth
    pub async fn login(&self, username: &str, password: &str) -> Result<LoginResp> {
        let input = LoginInput {
            username: username.to_string(),
            password: password.to_string(),
        };
        self.mutation::<LoginInput, LoginResp>("auth.login", &input)
            .await
    }

    pub async fn verify_token(&self, token: &str) -> Result<VerifyTokenResp> {
        self.query::<str, VerifyTokenResp>("auth.verifyToken", Some(token))
            .await
    }

    pub async fn get_profile(&self) -> Result<ProfileResp> {
        self.query_no_input::<ProfileResp>("auth.getProfile").await
    }

    // group
    pub async fn list_groups(&self) -> Result<Vec<GroupItem>> {
        self.query_no_input::<Vec<GroupItem>>("group.list").await
    }

    // meta updates (used by the in-app settings tab)
    pub async fn update_user_meta(&self, meta: &Value) -> Result<Value> {
        self.mutation::<Value, Value>("auth.updateMeta", meta).await
    }

    pub async fn update_group_meta(&self, group_id: &str, meta: &Value) -> Result<Value> {
        let input = serde_json::json!({ "groupId": group_id, "meta": meta });
        self.mutation::<Value, Value>("group.updateMeta", &input)
            .await
    }

    // timeline
    pub async fn get_timeline(&self, page: u32) -> Result<Vec<TimelineItem>> {
        self.query::<u32, Vec<TimelineItem>>("timeline", Some(&page))
            .await
    }

    // notepad
    pub async fn get_notes(&self, page: u32, tag_id: Option<i64>) -> Result<Vec<NoteListItem>> {
        let input = GetNotesInput { page, tag_id };
        self.query::<GetNotesInput, Vec<NoteListItem>>("notepad.getNotes", Some(&input))
            .await
    }

    pub async fn get_note_by_id(&self, id: &str) -> Result<Note> {
        let input = GetNoteByIdInput { id: id.to_string() };
        self.query::<GetNoteByIdInput, Note>("notepad.getNoteById", Some(&input))
            .await
    }

    pub async fn create_note(&self, title: &str, content: &str) -> Result<Note> {
        let input = CreateNoteInput {
            title: title.to_string(),
            content: content.to_string(),
        };
        self.mutation::<CreateNoteInput, Note>("notepad.createNote", &input)
            .await
    }

    pub async fn update_note(&self, id: &str, title: &str, content: &str) -> Result<Note> {
        let input = UpdateNoteInput {
            id: id.to_string(),
            title: title.to_string(),
            content: content.to_string(),
        };
        self.mutation::<UpdateNoteInput, Note>("notepad.updateNote", &input)
            .await
    }

    pub async fn delete_note(&self, id: &str) -> Result<Value> {
        let input = DeleteNoteInput { id: id.to_string() };
        self.mutation::<DeleteNoteInput, Value>("notepad.deleteNote", &input)
            .await
    }

    pub async fn list_note_tags(&self) -> Result<Vec<NoteTag>> {
        self.query_no_input::<Vec<NoteTag>>("notepad.listTags").await
    }

    pub async fn create_note_tag(&self, name: &str) -> Result<NoteTag> {
        let input = CreateTagInput {
            name: name.to_string(),
        };
        self.mutation::<CreateTagInput, NoteTag>("notepad.createTag", &input)
            .await
    }

    pub async fn get_note_tags(&self, note_id: &str) -> Result<Vec<NoteTag>> {
        let input = GetNoteTagsInput {
            note_id: note_id.to_string(),
        };
        self.query::<GetNoteTagsInput, Vec<NoteTag>>("notepad.getNoteTags", Some(&input))
            .await
    }

    pub async fn add_tag_to_note(&self, note_id: &str, tag_id: i64) -> Result<bool> {
        let input = NoteTagBindInput {
            note_id: note_id.to_string(),
            tag_id,
        };
        self.mutation::<NoteTagBindInput, bool>("notepad.addTagToNote", &input)
            .await
    }

    pub async fn remove_tag_from_note(&self, note_id: &str, tag_id: i64) -> Result<bool> {
        let input = NoteTagBindInput {
            note_id: note_id.to_string(),
            tag_id,
        };
        self.mutation::<NoteTagBindInput, bool>("notepad.removeTagFromNote", &input)
            .await
    }

    // todo
    pub async fn list_todo_lists(&self) -> Result<Vec<TodoList>> {
        self.query_no_input::<Vec<TodoList>>("todo.listLists").await
    }

    pub async fn get_todo_list(&self, id: &str) -> Result<TodoListWithItems> {
        self.query::<str, TodoListWithItems>("todo.getList", Some(id))
            .await
    }

    pub async fn create_todo_list(&self, name: &str, color: &str) -> Result<TodoList> {
        let input = CreateListInput {
            name: name.to_string(),
            color: color.to_string(),
        };
        self.mutation::<CreateListInput, TodoList>("todo.createList", &input)
            .await
    }

    pub async fn update_todo_list(
        &self,
        id: &str,
        name: Option<&str>,
        color: Option<&str>,
    ) -> Result<bool> {
        let input = UpdateListInput {
            id: id.to_string(),
            name: name.map(|s| s.to_string()),
            color: color.map(|s| s.to_string()),
        };
        self.mutation::<UpdateListInput, bool>("todo.updateList", &input)
            .await
    }

    pub async fn delete_todo_list(&self, id: &str) -> Result<bool> {
        self.mutation::<str, bool>("todo.deleteList", id).await
    }

    pub async fn create_todo_item(
        &self,
        list_id: &str,
        title: &str,
        description: &str,
    ) -> Result<TodoItem> {
        let input = CreateItemInput {
            list_id: list_id.to_string(),
            title: title.to_string(),
            description: description.to_string(),
            color: None,
            refs: vec![],
        };
        self.mutation::<CreateItemInput, TodoItem>("todo.createItem", &input)
            .await
    }

    pub async fn update_todo_item(
        &self,
        id: &str,
        title: Option<&str>,
        description: Option<&str>,
        done: Option<i64>,
    ) -> Result<bool> {
        let input = UpdateItemInput {
            id: id.to_string(),
            title: title.map(|s| s.to_string()),
            description: description.map(|s| s.to_string()),
            done,
        };
        self.mutation::<UpdateItemInput, bool>("todo.updateItem", &input)
            .await
    }

    pub async fn delete_todo_item(&self, id: &str) -> Result<bool> {
        self.mutation::<str, bool>("todo.deleteItem", id).await
    }

    // image bed
    pub async fn list_images(
        &self,
        offset: u32,
        sort: &str,
        search: &str,
    ) -> Result<Vec<ImageItem>> {
        let input = ImageListInput {
            user_id: String::new(),
            offset,
            sort: sort.to_string(),
            search: search.to_string(),
            tag_id: None,
        };
        self.query::<ImageListInput, Vec<ImageItem>>("image_bed.list", Some(&input))
            .await
    }

    pub async fn rename_image(&self, id: i64, name: &str) -> Result<bool> {
        let input = ImageRenameInput {
            id,
            name: name.to_string(),
        };
        self.mutation::<ImageRenameInput, bool>("image_bed.rename", &input)
            .await
    }

    // file drive
    pub async fn drive_list(
        &self,
        folder_id: Option<String>,
        offset: u32,
        sort: &str,
        search: &str,
        search_scope: &str,
    ) -> Result<DriveListResp> {
        let input = DriveListInput {
            folder_id,
            offset,
            sort: sort.to_string(),
            search: search.to_string(),
            search_scope: search_scope.to_string(),
        };
        self.query::<DriveListInput, DriveListResp>("file_drive.list", Some(&input))
            .await
    }

    pub async fn rename_file(&self, id: i64, name: &str) -> Result<bool> {
        let input = RenameFileInput {
            id,
            name: name.to_string(),
        };
        self.mutation::<RenameFileInput, bool>("file_drive.renameFile", &input)
            .await
    }

    pub async fn rename_folder(&self, id: &str, name: &str) -> Result<bool> {
        let input = RenameFolderInput {
            id: id.to_string(),
            name: name.to_string(),
        };
        self.mutation::<RenameFolderInput, bool>("file_drive.renameFolder", &input)
            .await
    }

    pub async fn drive_get_upload_url(
        &self,
        local_filename: &str,
        content_type: &str,
        folder_id: Option<String>,
    ) -> Result<DriveUploadUrlResp> {
        let input = DriveGetUploadUrlInput {
            filename: local_filename.to_string(),
            content_type: content_type.to_string(),
            folder_id,
        };
        self.query::<DriveGetUploadUrlInput, DriveUploadUrlResp>("file_drive.getUploadUrl", Some(&input))
            .await
    }

    pub async fn drive_add_file(
        &self,
        name: &str,
        oss_filename: &str,
        folder_id: Option<String>,
        mime_type: &str,
    ) -> Result<DriveFile> {
        let input = DriveAddFileInput {
            name: name.to_string(),
            filename: oss_filename.to_string(),
            folder_id,
            mime_type: mime_type.to_string(),
        };
        self.mutation::<DriveAddFileInput, DriveFile>("file_drive.addFile", &input)
            .await
    }

    // setting (usage)
    pub async fn get_usage_stats(&self) -> Result<UsageStats> {
        self.query_no_input::<UsageStats>("setting.getUsageStats")
            .await
    }

    pub async fn recalculate_usage_stats(&self) -> Result<UsageStats> {
        let empty = serde_json::json!({});
        self.mutation::<serde_json::Value, UsageStats>("setting.recalculateStats", &empty)
            .await
    }

    // auth sessions
    pub async fn get_tokens(&self) -> Result<Vec<AuthTokenRow>> {
        self.query_no_input::<Vec<AuthTokenRow>>("auth.getTokens").await
    }

    pub async fn set_token_alias(
        &self,
        token_hash: &str,
        alias: Option<&str>,
    ) -> Result<serde_json::Value> {
        let input = SetTokenAliasInput {
            token_hash: token_hash.to_string(),
            alias: alias
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string()),
        };
        self.mutation::<SetTokenAliasInput, serde_json::Value>("auth.setTokenAlias", &input)
            .await
    }

    pub async fn revoke_token(&self, token_hash: &str) -> Result<serde_json::Value> {
        let input = RevokeTokenInput {
            token_hash: token_hash.to_string(),
        };
        self.mutation::<RevokeTokenInput, serde_json::Value>("auth.revokeToken", &input)
            .await
    }
}
