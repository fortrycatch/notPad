import 'dart:convert';

import '../core/json.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.meta = const {},
  });

  final String id;
  final String name;
  final String email;
  final Map<String, dynamic> meta;

  String get avatar => asString(meta['avatar']);

  String get primaryColor => asString(meta['primaryColor']);

  factory UserProfile.fromJson(Object? json) {
    final map = asMap(json);
    return UserProfile(
      id: asString(map['id']),
      name: asString(map['name']),
      email: asString(map['email']),
      meta: asMeta(map['meta']),
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.success,
    this.token,
    this.user,
    this.message,
  });

  final bool success;
  final String? token;
  final UserProfile? user;
  final String? message;

  factory AuthResult.fromJson(Object? json) {
    final map = asMap(json);
    return AuthResult(
      success: asBool(map['success']),
      token: asStringOrNull(map['token']),
      user: map['user'] == null ? null : UserProfile.fromJson(map['user']),
      message: asStringOrNull(map['message']),
    );
  }
}

class AuthToken {
  const AuthToken({
    required this.token,
    required this.createdAt,
    this.usedAt,
    this.userAgent,
    this.alias,
  });

  final String token;
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? userAgent;
  final String? alias;

  factory AuthToken.fromJson(Object? json) {
    final map = asMap(json);
    return AuthToken(
      token: asString(map['token']),
      createdAt: asDate(map['created_at']),
      usedAt: map['used_at'] == null ? null : asDate(map['used_at']),
      userAgent: asStringOrNull(map['user_agent']),
      alias: asStringOrNull(map['alias']),
    );
  }
}

class NoteListItem {
  const NoteListItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory NoteListItem.fromJson(Object? json) {
    final map = asMap(json);
    return NoteListItem(
      id: asString(map['id']),
      title: asString(map['title']),
      content: asString(map['content']),
      createdAt: asDate(map['created_at']),
      updatedAt: asDate(map['updated_at']),
    );
  }
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Note.fromJson(Object? json) {
    final map = asMap(json);
    return Note(
      id: asString(map['id']),
      title: asString(map['title']),
      content: asString(map['content']),
      userId: asString(map['user_id']),
      createdAt: asDate(map['created_at']),
      updatedAt: asDate(map['updated_at']),
    );
  }
}

class TagItem {
  const TagItem({required this.id, required this.name});

  final int id;
  final String name;

  factory TagItem.fromJson(Object? json) {
    final map = asMap(json);
    return TagItem(id: asInt(map['id']), name: asString(map['name']));
  }
}

class TimelineItem {
  const TimelineItem({
    required this.type,
    required this.id,
    required this.name,
    required this.summary,
    this.url,
    required this.size,
    required this.createdAt,
    this.bookmarkSubtype,
    this.refId,
  });

  final String type;
  final String id;
  final String name;
  final String summary;
  final String? url;
  final int size;
  final DateTime createdAt;
  final String? bookmarkSubtype;
  final String? refId;

  factory TimelineItem.fromJson(Object? json) {
    final map = asMap(json);
    return TimelineItem(
      type: asString(map['type']),
      id: asString(map['id']),
      name: asString(map['name']),
      summary: asString(map['summary']),
      url: asStringOrNull(map['url']),
      size: asInt(map['size']),
      createdAt: asDate(map['created_at']),
      bookmarkSubtype: asStringOrNull(map['bookmark_subtype']),
      refId: asStringOrNull(map['ref_id']),
    );
  }
}

class TodoRef {
  const TodoRef({
    required this.type,
    required this.refId,
    required this.title,
    this.url,
    this.mimeType,
    this.bookmarkType,
    this.targetRefId,
  });

  final String type;
  final String refId;
  final String title;
  final String? url;
  final String? mimeType;
  final String? bookmarkType;
  final String? targetRefId;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'refId': refId,
      if (title.isNotEmpty) 'title': title,
      if (url != null) 'url': url,
      if (mimeType != null) 'mimeType': mimeType,
      if (bookmarkType != null) 'bookmarkType': bookmarkType,
      if (targetRefId != null) 'targetRefId': targetRefId,
    };
  }

  factory TodoRef.fromJson(Object? json) {
    final map = asMap(json);
    return TodoRef(
      type: asString(map['type']),
      refId: asString(map['refId'] ?? map['ref_id']),
      title: asString(map['title']),
      url: asStringOrNull(map['url']),
      mimeType: asStringOrNull(map['mimeType'] ?? map['mime_type']),
      bookmarkType: asStringOrNull(map['bookmarkType'] ?? map['bookmark_type']),
      targetRefId: asStringOrNull(map['targetRefId'] ?? map['target_ref_id']),
    );
  }
}

class TodoList {
  const TodoList({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String id;
  final String name;
  final String color;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TodoItem> items;

  TodoList copyWith({List<TodoItem>? items}) {
    return TodoList(
      id: id,
      name: name,
      color: color,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: items ?? this.items,
    );
  }

  factory TodoList.fromJson(Object? json) {
    final map = asMap(json);
    return TodoList(
      id: asString(map['id']),
      name: asString(map['name']),
      color: asString(map['color'], '#9e9e9e'),
      sortOrder: asInt(map['sort_order']),
      createdAt: asDate(map['created_at']),
      updatedAt: asDate(map['updated_at']),
      items: asList(map['items'], TodoItem.fromJson),
    );
  }
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.listId,
    required this.title,
    required this.description,
    required this.done,
    this.color,
    this.refs = const [],
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listId;
  final String title;
  final String description;
  final bool done;
  final String? color;
  final List<TodoRef> refs;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoItem copyWith({bool? done}) {
    return TodoItem(
      id: id,
      listId: listId,
      title: title,
      description: description,
      done: done ?? this.done,
      color: color,
      refs: refs,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory TodoItem.fromJson(Object? json) {
    final map = asMap(json);
    Object? rawRefs = map['refs'];
    if (rawRefs is String && rawRefs.isNotEmpty) {
      try {
        rawRefs = jsonDecode(rawRefs);
      } catch (_) {
        rawRefs = const [];
      }
    }
    final refs = rawRefs is List ? rawRefs.map(TodoRef.fromJson).toList() : const <TodoRef>[];
    return TodoItem(
      id: asString(map['id']),
      listId: asString(map['list_id']),
      title: asString(map['title']),
      description: asString(map['description']),
      done: asBool(map['done']),
      color: asStringOrNull(map['color']),
      refs: refs,
      sortOrder: asInt(map['sort_order']),
      createdAt: asDate(map['created_at']),
      updatedAt: asDate(map['updated_at']),
    );
  }
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.content,
    required this.url,
    this.refId,
    required this.userId,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String description;
  final String? content;
  final String url;
  final String? refId;
  final String userId;
  final DateTime createdAt;

  factory Bookmark.fromJson(Object? json) {
    final map = asMap(json);
    return Bookmark(
      id: asInt(map['id']),
      type: asString(map['type']),
      title: asString(map['title']),
      description: asString(map['description']),
      content: asStringOrNull(map['content']),
      url: asString(map['url']),
      refId: asStringOrNull(map['ref_id']),
      userId: asString(map['user_id']),
      createdAt: asDate(map['created_at']),
    );
  }
}

class UrlPreview {
  const UrlPreview({
    required this.title,
    required this.description,
    required this.content,
    required this.url,
  });

  final String title;
  final String description;
  final String content;
  final String url;

  factory UrlPreview.fromJson(Object? json) {
    final map = asMap(json);
    return UrlPreview(
      title: asString(map['title']),
      description: asString(map['description']),
      content: asString(map['content']),
      url: asString(map['url']),
    );
  }
}

class BookmarkState {
  const BookmarkState({required this.bookmarked, this.id});

  final bool bookmarked;
  final int? id;

  factory BookmarkState.fromJson(Object? json) {
    final map = asMap(json);
    return BookmarkState(
      bookmarked: asBool(map['bookmarked']),
      id: map['id'] == null ? null : asInt(map['id']),
    );
  }
}

class BedImage {
  const BedImage({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.userId,
    required this.createdAt,
    required this.remark,
  });

  final int id;
  final String name;
  final String url;
  final int size;
  final String userId;
  final DateTime createdAt;
  final String remark;

  factory BedImage.fromTimeline(TimelineItem item) {
    return BedImage(
      id: asInt(item.id),
      name: item.name,
      url: item.url ?? '',
      size: item.size,
      userId: '',
      createdAt: item.createdAt,
      remark: '',
    );
  }

  factory BedImage.fromJson(Object? json) {
    final map = asMap(json);
    return BedImage(
      id: asInt(map['id']),
      name: asString(map['name']),
      url: asString(map['url']),
      size: asInt(map['size']),
      userId: asString(map['user_id']),
      createdAt: asDate(map['created_at']),
      remark: asString(map['remark']),
    );
  }
}

class UploadSlot {
  const UploadSlot({required this.url, required this.filename});

  final String url;
  final String filename;

  factory UploadSlot.fromJson(Object? json) {
    final map = asMap(json);
    return UploadSlot(
      url: asString(map['url']),
      filename: asString(map['filename']),
    );
  }
}

class DriveFolder {
  const DriveFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.userId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? parentId;
  final String userId;
  final DateTime createdAt;

  factory DriveFolder.fromJson(Object? json) {
    final map = asMap(json);
    return DriveFolder(
      id: asString(map['id']),
      name: asString(map['name']),
      parentId: asStringOrNull(map['parent_id']),
      userId: asString(map['user_id']),
      createdAt: asDate(map['created_at']),
    );
  }
}

class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.ossKey,
    required this.size,
    required this.mimeType,
    this.folderId,
    required this.userId,
    required this.createdAt,
    this.publicUrl,
  });

  final int id;
  final String name;
  final String ossKey;
  final int size;
  final String mimeType;
  final String? folderId;
  final String userId;
  final DateTime createdAt;
  final String? publicUrl;

  factory DriveFile.fromJson(Object? json) {
    final map = asMap(json);
    return DriveFile(
      id: asInt(map['id']),
      name: asString(map['name']),
      ossKey: asString(map['oss_key']),
      size: asInt(map['size']),
      mimeType: asString(map['mime_type']),
      folderId: asStringOrNull(map['folder_id']),
      userId: asString(map['user_id']),
      createdAt: asDate(map['created_at']),
      publicUrl: asStringOrNull(map['public_url']),
    );
  }
}

class DriveListing {
  const DriveListing({
    this.currentFolder,
    this.breadcrumbs = const [],
    this.folders = const [],
    this.files = const [],
    this.hasMore = false,
  });

  final DriveFolder? currentFolder;
  final List<DriveFolder> breadcrumbs;
  final List<DriveFolder> folders;
  final List<DriveFile> files;
  final bool hasMore;

  factory DriveListing.fromJson(Object? json) {
    final map = asMap(json);
    return DriveListing(
      currentFolder: map['currentFolder'] == null
          ? null
          : DriveFolder.fromJson(map['currentFolder']),
      breadcrumbs: asList(map['breadcrumbs'], DriveFolder.fromJson),
      folders: asList(map['folders'], DriveFolder.fromJson),
      files: asList(map['files'], DriveFile.fromJson),
      hasMore: asBool(map['hasMore']),
    );
  }
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.role,
    this.meta = const {},
  });

  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? role;
  final Map<String, dynamic> meta;

  String get primaryColor => asString(meta['primaryColor']);

  factory Group.fromJson(Object? json) {
    final map = asMap(json);
    return Group(
      id: asString(map['id']),
      name: asString(map['name']),
      description: asString(map['description']),
      createdBy: asString(map['created_by']),
      createdAt: asDate(map['created_at']),
      updatedAt: asDate(map['updated_at']),
      role: asStringOrNull(map['role']),
      meta: asMeta(map['meta']),
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.userName,
    this.userEmail,
  });

  final String groupId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String? userName;
  final String? userEmail;

  factory GroupMember.fromJson(Object? json) {
    final map = asMap(json);
    return GroupMember(
      groupId: asString(map['group_id']),
      userId: asString(map['user_id']),
      role: asString(map['role']),
      joinedAt: asDate(map['joined_at']),
      userName: asStringOrNull(map['user_name']),
      userEmail: asStringOrNull(map['user_email']),
    );
  }
}

class GroupInvite {
  const GroupInvite({
    required this.id,
    required this.groupId,
    this.inviteCode,
    this.invitedUserId,
    required this.role,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
    this.usedAt,
    this.groupName,
  });

  final String id;
  final String groupId;
  final String? inviteCode;
  final String? invitedUserId;
  final String role;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final String? groupName;

  factory GroupInvite.fromJson(Object? json) {
    final map = asMap(json);
    return GroupInvite(
      id: asString(map['id']),
      groupId: asString(map['group_id'] ?? map['groupId']),
      inviteCode: asStringOrNull(map['invite_code'] ?? map['inviteCode']),
      invitedUserId: asStringOrNull(map['invited_user_id']),
      role: asString(map['role']),
      createdBy: asString(map['created_by']),
      createdAt: asDate(map['created_at']),
      expiresAt: map['expires_at'] == null ? null : asDate(map['expires_at']),
      usedAt: map['used_at'] == null ? null : asDate(map['used_at']),
      groupName: asStringOrNull(map['group_name'] ?? map['groupName']),
    );
  }
}

class InviteInfo {
  const InviteInfo({
    required this.groupName,
    required this.groupId,
    required this.role,
  });

  final String groupName;
  final String groupId;
  final String role;

  factory InviteInfo.fromJson(Object? json) {
    final map = asMap(json);
    return InviteInfo(
      groupName: asString(map['groupName']),
      groupId: asString(map['groupId']),
      role: asString(map['role']),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Object? json) {
    final map = asMap(json);
    return ChatMessage(
      id: asString(map['id']),
      groupId: asString(map['group_id']),
      userId: asString(map['user_id']),
      userName: asString(map['user_name']),
      userAvatar: asString(map['user_avatar']),
      content: asString(map['content']),
      createdAt: asDate(map['created_at']),
    );
  }
}

class UsageStats {
  const UsageStats({
    required this.notesCount,
    required this.bookmarksCount,
    required this.imagesCount,
    required this.imagesSize,
    required this.filesCount,
    required this.filesSize,
  });

  final int notesCount;
  final int bookmarksCount;
  final int imagesCount;
  final int imagesSize;
  final int filesCount;
  final int filesSize;

  factory UsageStats.fromJson(Object? json) {
    final map = asMap(json);
    return UsageStats(
      notesCount: asInt(map['notes_count']),
      bookmarksCount: asInt(map['bookmarks_count']),
      imagesCount: asInt(map['images_count']),
      imagesSize: asInt(map['images_size']),
      filesCount: asInt(map['files_count']),
      filesSize: asInt(map['files_size']),
    );
  }
}
