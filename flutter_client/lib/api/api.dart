import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import '../core/json.dart';
import '../core/trpc.dart';
import '../models/models.dart';

class Api {
  Api(this.client);

  final TrpcClient client;

  late final AuthApi auth = AuthApi(client);
  late final NotepadApi notepad = NotepadApi(client);
  late final TodoApi todo = TodoApi(client);
  late final BookmarkApi bookmark = BookmarkApi(client);
  late final ImageBedApi imageBed = ImageBedApi(client);
  late final FileDriveApi fileDrive = FileDriveApi(client);
  late final GroupApi group = GroupApi(client);
  late final GroupChatApi groupChat = GroupChatApi(client);
  late final SettingApi setting = SettingApi(client);

  Future<List<TimelineItem>> timeline(int page) {
    return client.query(
      'timeline',
      input: page,
      parse: (json) => asList(json, TimelineItem.fromJson),
    );
  }

  Future<void> uploadBytes({
    required String url,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await client.raw.put<void>(
        url,
        data: bytes,
        options: Options(
          headers: {'content-type': contentType},
          contentType: contentType,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
    } on DioException catch (error) {
      throw TrpcException(
        message: error.message ?? '上传失败',
        httpStatus: error.response?.statusCode,
      );
    }
  }
}

class AuthApi {
  AuthApi(this._c);
  final TrpcClient _c;

  Future<AuthResult> login(String username, String password) {
    return _c.mutate(
      'auth.login',
      input: {'username': username, 'password': password},
      parse: AuthResult.fromJson,
    );
  }

  Future<AuthResult> register({
    required String userId,
    required String name,
    required String email,
    required String password,
  }) {
    return _c.mutate(
      'auth.register',
      input: {
        'user_id': userId,
        'name': name,
        'email': email,
        'password': password,
      },
      parse: AuthResult.fromJson,
    );
  }

  Future<bool> verifyToken(String token) {
    return _c.query(
      'auth.verifyToken',
      input: token,
      parse: (json) => asBool(asMap(json)['ok']),
    );
  }

  Future<UserProfile> getProfile() {
    return _c.query('auth.getProfile', parse: UserProfile.fromJson);
  }

  Future<UserProfile> updateProfile({
    required String name,
    required String email,
    String? password,
  }) {
    return _c.mutate(
      'auth.updateProfile',
      input: {
        'name': name,
        'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
      },
      parse: (json) => UserProfile.fromJson(asMap(json)['user']),
    );
  }

  Future<Map<String, dynamic>> updateMeta(Map<String, dynamic> meta) {
    return _c.mutate('auth.updateMeta', input: meta, parse: asMap);
  }

  Future<List<AuthToken>> getTokens() {
    return _c.query(
      'auth.getTokens',
      parse: (json) => asList(json, AuthToken.fromJson),
    );
  }

  Future<void> setTokenAlias(String tokenHash, String? alias) {
    return _c.mutate(
      'auth.setTokenAlias',
      input: {'tokenHash': tokenHash, if (alias != null) 'alias': alias},
    );
  }

  Future<void> revokeToken(String tokenHash) {
    return _c.mutate('auth.revokeToken', input: {'tokenHash': tokenHash});
  }
}

class NotepadApi {
  NotepadApi(this._c);
  final TrpcClient _c;

  Future<List<NoteListItem>> getNotes({required int page, int? tagId}) {
    return _c.query(
      'notepad.getNotes',
      input: {'page': page, 'tag_id': tagId},
      parse: (json) => asList(json, NoteListItem.fromJson),
    );
  }

  Future<Note> getNoteById(String id) {
    return _c.query(
      'notepad.getNoteById',
      input: {'id': id},
      parse: Note.fromJson,
    );
  }

  Future<Note> createNote({required String title, required String content}) {
    return _c.mutate(
      'notepad.createNote',
      input: {'title': title, 'content': content},
      parse: Note.fromJson,
    );
  }

  Future<Note> updateNote({
    required String id,
    required String title,
    required String content,
  }) {
    return _c.mutate(
      'notepad.updateNote',
      input: {'id': id, 'title': title, 'content': content},
      parse: Note.fromJson,
    );
  }

  Future<void> deleteNote(String id) {
    return _c.mutate('notepad.deleteNote', input: {'id': id});
  }

  Future<List<TagItem>> listTags() {
    return _c.query(
      'notepad.listTags',
      parse: (json) => asList(json, TagItem.fromJson),
    );
  }

  Future<TagItem> createTag(String name) {
    return _c.mutate(
      'notepad.createTag',
      input: {'name': name},
      parse: TagItem.fromJson,
    );
  }

  Future<void> deleteTag(int id) {
    return _c.mutate('notepad.deleteTag', input: {'id': id});
  }

  Future<List<TagItem>> getNoteTags(String noteId) {
    return _c.query(
      'notepad.getNoteTags',
      input: {'note_id': noteId},
      parse: (json) => asList(json, TagItem.fromJson),
    );
  }

  Future<void> addTagToNote(String noteId, int tagId) {
    return _c.mutate(
      'notepad.addTagToNote',
      input: {'note_id': noteId, 'tag_id': tagId},
    );
  }

  Future<void> removeTagFromNote(String noteId, int tagId) {
    return _c.mutate(
      'notepad.removeTagFromNote',
      input: {'note_id': noteId, 'tag_id': tagId},
    );
  }
}

class TodoApi {
  TodoApi(this._c);
  final TrpcClient _c;

  Future<List<TodoList>> listLists() {
    return _c.query(
      'todo.listLists',
      parse: (json) => asList(json, TodoList.fromJson),
    );
  }

  Future<TodoList> getList(String id) {
    return _c.query('todo.getList', input: id, parse: TodoList.fromJson);
  }

  Future<TodoList> createList({required String name, String color = '#9e9e9e'}) {
    return _c.mutate(
      'todo.createList',
      input: {'name': name, 'color': color},
      parse: TodoList.fromJson,
    );
  }

  Future<void> updateList({
    required String id,
    String? name,
    String? color,
    int? sortOrder,
  }) {
    return _c.mutate(
      'todo.updateList',
      input: {
        'id': id,
        if (name != null) 'name': name,
        if (color != null) 'color': color,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    );
  }

  Future<void> deleteList(String id) {
    return _c.mutate('todo.deleteList', input: id);
  }

  Future<TodoItem> createItem({
    required String listId,
    required String title,
    String description = '',
    String? color,
    List<TodoRef> refs = const [],
  }) {
    return _c.mutate(
      'todo.createItem',
      input: {
        'listId': listId,
        'title': title,
        'description': description,
        'color': color,
        'refs': refs.map((ref) => ref.toJson()).toList(),
      },
      parse: TodoItem.fromJson,
    );
  }

  Future<void> updateItem({
    required String id,
    String? title,
    String? description,
    int? done,
    String? color,
    List<TodoRef>? refs,
    int? sortOrder,
  }) {
    return _c.mutate(
      'todo.updateItem',
      input: {
        'id': id,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (done != null) 'done': done,
        if (color != null) 'color': color,
        if (refs != null) 'refs': refs.map((ref) => ref.toJson()).toList(),
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    );
  }

  Future<void> deleteItem(String id) {
    return _c.mutate('todo.deleteItem', input: id);
  }
}

class BookmarkApi {
  BookmarkApi(this._c);
  final TrpcClient _c;

  Future<List<Bookmark>> list({
    required int offset,
    String sort = 'time_desc',
    String search = '',
    int? tagId,
    String? type,
  }) {
    return _c.query(
      'bookmark.list',
      input: {
        'offset': offset,
        'sort': sort,
        if (search.isNotEmpty) 'search': search,
        'tag_id': tagId,
        'type': type,
      },
      parse: (json) => asList(json, Bookmark.fromJson),
    );
  }

  Future<Bookmark> getById(int id) {
    return _c.query(
      'bookmark.getById',
      input: {'id': id},
      parse: Bookmark.fromJson,
    );
  }

  Future<Bookmark> add({
    required String type,
    required String title,
    String description = '',
    String? content,
    String? url,
    String? refId,
    List<int> tagIds = const [],
  }) {
    return _c.mutate(
      'bookmark.add',
      input: {
        'type': type,
        'title': title,
        'description': description,
        if (content != null) 'content': content,
        if (url != null) 'url': url,
        'ref_id': refId,
        if (tagIds.isNotEmpty) 'tag_ids': tagIds,
      },
      parse: Bookmark.fromJson,
    );
  }

  Future<void> remove(int id) {
    return _c.mutate('bookmark.remove', input: {'id': id});
  }

  Future<BookmarkState> isBookmarked({
    required String type,
    required String refId,
  }) {
    return _c.query(
      'bookmark.isBookmarked',
      input: {'type': type, 'ref_id': refId},
      parse: BookmarkState.fromJson,
    );
  }

  Future<UrlPreview> fetchUrl(String url) {
    return _c.query(
      'bookmark.fetchUrl',
      input: {'url': url},
      parse: UrlPreview.fromJson,
    );
  }

  Future<List<TagItem>> listTags() {
    return _c.query(
      'bookmark.listTags',
      parse: (json) => asList(json, TagItem.fromJson),
    );
  }

  Future<TagItem> createTag(String name) {
    return _c.mutate(
      'bookmark.createTag',
      input: {'name': name},
      parse: TagItem.fromJson,
    );
  }

  Future<void> deleteTag(int id) {
    return _c.mutate('bookmark.deleteTag', input: {'id': id});
  }

  Future<List<TagItem>> getBookmarkTags(int bookmarkId) {
    return _c.query(
      'bookmark.getBookmarkTags',
      input: {'bookmark_id': bookmarkId},
      parse: (json) => asList(json, TagItem.fromJson),
    );
  }

  Future<void> addTagToBookmark(int bookmarkId, int tagId) {
    return _c.mutate(
      'bookmark.addTagToBookmark',
      input: {'bookmark_id': bookmarkId, 'tag_id': tagId},
    );
  }

  Future<void> removeTagFromBookmark(int bookmarkId, int tagId) {
    return _c.mutate(
      'bookmark.removeTagFromBookmark',
      input: {'bookmark_id': bookmarkId, 'tag_id': tagId},
    );
  }
}

class ImageBedApi {
  ImageBedApi(this._c);
  final TrpcClient _c;

  Future<UploadSlot> getUploadUrl({
    required String filename,
    required String type,
  }) {
    return _c.query(
      'image_bed.getUploadUrl',
      input: {'filename': filename, 'type': type},
      parse: UploadSlot.fromJson,
    );
  }

  Future<void> addImage({
    required String name,
    required String filename,
    String remark = '',
  }) {
    return _c.mutate(
      'image_bed.addImage',
      input: {'name': name, 'filename': filename, 'remark': remark},
    );
  }

  Future<void> rename(int id, String name) {
    return _c.mutate('image_bed.rename', input: {'id': id, 'name': name});
  }

  Future<List<BedImage>> list({
    required String userId,
    required int offset,
    String sort = 'time_desc',
    String search = '',
    int? tagId,
  }) {
    return _c.query(
      'image_bed.list',
      input: {
        'user_id': userId,
        'offset': offset,
        'sort': sort,
        if (search.isNotEmpty) 'search': search,
        'tag_id': tagId,
      },
      parse: (json) => asList(json, BedImage.fromJson),
    );
  }

  Future<List<TagItem>> listTags() {
    return _c.query(
      'image_bed.listTags',
      parse: (json) => asList(json, TagItem.fromJson),
    );
  }

  Future<TagItem> createTag(String name) {
    return _c.mutate(
      'image_bed.createTag',
      input: {'name': name},
      parse: TagItem.fromJson,
    );
  }

  Future<void> deleteTag(int id) {
    return _c.mutate('image_bed.deleteTag', input: {'id': id});
  }

  Future<List<TagItem>> getImageTags(int imageId) {
    return _c.query(
      'image_bed.getImageTags',
      input: {'image_id': imageId},
      parse: (json) => asList(json, TagItem.fromJson),
    );
  }

  Future<void> addTagToImage(int imageId, int tagId) {
    return _c.mutate(
      'image_bed.addTagToImage',
      input: {'image_id': imageId, 'tag_id': tagId},
    );
  }

  Future<void> removeTagFromImage(int imageId, int tagId) {
    return _c.mutate(
      'image_bed.removeTagFromImage',
      input: {'image_id': imageId, 'tag_id': tagId},
    );
  }
}

class FileDriveApi {
  FileDriveApi(this._c);
  final TrpcClient _c;

  Future<UploadSlot> getUploadUrl({
    required String filename,
    String type = 'application/octet-stream',
    String? folderId,
  }) {
    return _c.query(
      'file_drive.getUploadUrl',
      input: {
        'filename': filename,
        'type': type,
        'folder_id': folderId,
      },
      parse: UploadSlot.fromJson,
    );
  }

  Future<DriveFile> addFile({
    required String name,
    required String filename,
    String? folderId,
    String mimeType = 'application/octet-stream',
  }) {
    return _c.mutate(
      'file_drive.addFile',
      input: {
        'name': name,
        'filename': filename,
        'folder_id': folderId,
        'mime_type': mimeType,
      },
      parse: DriveFile.fromJson,
    );
  }

  Future<DriveFolder> createFolder({required String name, String? parentId}) {
    return _c.mutate(
      'file_drive.createFolder',
      input: {'name': name, 'parent_id': parentId},
      parse: DriveFolder.fromJson,
    );
  }

  Future<DriveListing> list({
    String? folderId,
    int offset = 0,
    String sort = 'time_desc',
    String search = '',
    String searchScope = 'current',
  }) {
    return _c.query(
      'file_drive.list',
      input: {
        'folder_id': folderId,
        'offset': offset,
        'sort': sort,
        if (search.isNotEmpty) 'search': search,
        'search_scope': searchScope,
      },
      parse: DriveListing.fromJson,
    );
  }

  Future<void> renameFile(int id, String name) {
    return _c.mutate('file_drive.renameFile', input: {'id': id, 'name': name});
  }

  Future<void> renameFolder(String id, String name) {
    return _c.mutate('file_drive.renameFolder', input: {'id': id, 'name': name});
  }

  Future<({String name, String url})> getDownloadUrl(int fileId) {
    return _c.query(
      'file_drive.getDownloadUrl',
      input: {'file_id': fileId},
      parse: (json) {
        final map = asMap(json);
        return (name: asString(map['name']), url: asString(map['url']));
      },
    );
  }
}

class GroupApi {
  GroupApi(this._c);
  final TrpcClient _c;

  Future<Group> create({required String name, String description = ''}) {
    return _c.mutate(
      'group.create',
      input: {'name': name, 'description': description},
      parse: Group.fromJson,
    );
  }

  Future<List<Group>> list() {
    return _c.query('group.list', parse: (json) => asList(json, Group.fromJson));
  }

  Future<Group> getById(String id) {
    return _c.query('group.getById', input: id, parse: Group.fromJson);
  }

  Future<Group> update({
    required String groupId,
    required String name,
    String description = '',
  }) {
    return _c.mutate(
      'group.update',
      input: {'groupId': groupId, 'name': name, 'description': description},
      parse: Group.fromJson,
    );
  }

  Future<void> delete(String groupId) {
    return _c.mutate('group.delete', input: groupId);
  }

  Future<List<GroupMember>> listMembers(String groupId) {
    return _c.query(
      'group.listMembers',
      input: groupId,
      parse: (json) => asList(json, GroupMember.fromJson),
    );
  }

  Future<GroupInvite> inviteUser({
    required String groupId,
    required String userId,
    String role = 'editor',
  }) {
    return _c.mutate(
      'group.inviteUser',
      input: {'groupId': groupId, 'userId': userId, 'role': role},
      parse: GroupInvite.fromJson,
    );
  }

  Future<GroupInvite> createInviteLink({
    required String groupId,
    String role = 'editor',
    int? expiresInHours,
  }) {
    return _c.mutate(
      'group.createInviteLink',
      input: {
        'groupId': groupId,
        'role': role,
        'expiresInHours': expiresInHours,
      },
      parse: GroupInvite.fromJson,
    );
  }

  Future<Group> acceptInvite({String? inviteCode, String? inviteId}) {
    return _c.mutate(
      'group.acceptInvite',
      input: {
        if (inviteCode != null) 'inviteCode': inviteCode,
        if (inviteId != null) 'inviteId': inviteId,
      },
      parse: Group.fromJson,
    );
  }

  Future<InviteInfo> getInviteInfo(String code) {
    return _c.query(
      'group.getInviteInfo',
      input: code,
      parse: InviteInfo.fromJson,
    );
  }

  Future<List<GroupInvite>> listPendingInvites(String groupId) {
    return _c.query(
      'group.listPendingInvites',
      input: groupId,
      parse: (json) => asList(json, GroupInvite.fromJson),
    );
  }

  Future<List<GroupInvite>> listInviteCodes(String groupId) {
    return _c.query(
      'group.listInviteCodes',
      input: groupId,
      parse: (json) => asList(json, GroupInvite.fromJson),
    );
  }

  Future<List<GroupInvite>> myInvites() {
    return _c.query(
      'group.myInvites',
      parse: (json) => asList(json, GroupInvite.fromJson),
    );
  }

  Future<void> removeInvite(String inviteId) {
    return _c.mutate('group.removeInvite', input: inviteId);
  }

  Future<void> removeMember({required String groupId, required String userId}) {
    return _c.mutate(
      'group.removeMember',
      input: {'groupId': groupId, 'userId': userId},
    );
  }

  Future<void> updateMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) {
    return _c.mutate(
      'group.updateMemberRole',
      input: {'groupId': groupId, 'userId': userId, 'role': role},
    );
  }

  Future<void> leave(String groupId) {
    return _c.mutate('group.leave', input: groupId);
  }

  Future<void> transferOwnership({
    required String groupId,
    required String newOwnerId,
  }) {
    return _c.mutate(
      'group.transferOwnership',
      input: {'groupId': groupId, 'newOwnerId': newOwnerId},
    );
  }
}

class GroupChatApi {
  GroupChatApi(this._c);
  final TrpcClient _c;

  Future<List<ChatMessage>> list({
    required String groupId,
    String? beforeId,
    int limit = 50,
  }) {
    return _c.query(
      'groupChat.list',
      input: {
        'groupId': groupId,
        'beforeId': beforeId,
        'limit': limit,
      },
      parse: (json) => asList(json, ChatMessage.fromJson),
    );
  }

  Future<ChatMessage> send({
    required String groupId,
    required String content,
  }) {
    return _c.mutate(
      'groupChat.send',
      input: {'groupId': groupId, 'content': content},
      parse: ChatMessage.fromJson,
    );
  }
}

class SettingApi {
  SettingApi(this._c);
  final TrpcClient _c;

  Future<Map<String, String>> getAll() {
    return _c.query(
      'setting.getAll',
      parse: (json) => asMap(json).map((key, value) => MapEntry(key, asString(value))),
    );
  }

  Future<void> set(String key, String value) {
    return _c.mutate('setting.set', input: {'key': key, 'value': value});
  }

  Future<void> remove(String key) {
    return _c.mutate('setting.remove', input: {'key': key});
  }

  Future<UsageStats> getUsageStats() {
    return _c.query('setting.getUsageStats', parse: UsageStats.fromJson);
  }

  Future<UsageStats> recalculateStats() {
    return _c.mutate('setting.recalculateStats', parse: UsageStats.fromJson);
  }
}

String guessMime(String filename, {String fallback = 'application/octet-stream'}) {
  return lookupMimeType(filename) ?? fallback;
}
