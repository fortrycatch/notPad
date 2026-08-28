import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'session.dart';

const pageSize = 30;

class PagedItems<T> {
  const PagedItems({
    required this.items,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  PagedItems<T> copyWith({
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return PagedItems<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class TimelineController extends AutoDisposeAsyncNotifier<PagedItems<TimelineItem>> {
  @override
  Future<PagedItems<TimelineItem>> build() async {
    ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
    final items = await ref.read(apiProvider).timeline(0);
    return PagedItems(items: items, page: 0, hasMore: items.length >= pageSize);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final extra = await ref.read(apiProvider).timeline(nextPage);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...extra],
          page: nextPage,
          hasMore: extra.length >= pageSize,
          loadingMore: false,
        ),
      );
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

final timelineProvider =
    AutoDisposeAsyncNotifierProvider<TimelineController, PagedItems<TimelineItem>>(
  TimelineController.new,
);

class NotesQuery {
  const NotesQuery({this.tagId});
  final int? tagId;

  @override
  bool operator ==(Object other) => other is NotesQuery && other.tagId == tagId;

  @override
  int get hashCode => tagId.hashCode;
}

class NotesController extends AutoDisposeFamilyAsyncNotifier<PagedItems<NoteListItem>, NotesQuery> {
  @override
  Future<PagedItems<NoteListItem>> build(NotesQuery arg) async {
    ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
    final items = await ref.read(apiProvider).notepad.getNotes(page: 0, tagId: arg.tagId);
    return PagedItems(items: items, page: 0, hasMore: items.length >= pageSize);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final extra = await ref.read(apiProvider).notepad.getNotes(
            page: nextPage,
            tagId: arg.tagId,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...extra],
          page: nextPage,
          hasMore: extra.length >= pageSize,
          loadingMore: false,
        ),
      );
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

final notesProvider = AutoDisposeAsyncNotifierProvider.family<
    NotesController, PagedItems<NoteListItem>, NotesQuery>(NotesController.new);

final noteTagsProvider = FutureProvider.autoDispose<List<TagItem>>((ref) {
  ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
  return ref.read(apiProvider).notepad.listTags();
});

final noteProvider = FutureProvider.autoDispose.family<Note, String>((ref, id) {
  return ref.read(apiProvider).notepad.getNoteById(id);
});

final noteItemTagsProvider =
    FutureProvider.autoDispose.family<List<TagItem>, String>((ref, noteId) {
  return ref.read(apiProvider).notepad.getNoteTags(noteId);
});

final todoListsProvider = FutureProvider.autoDispose<List<TodoList>>((ref) {
  ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
  return ref.read(apiProvider).todo.listLists();
});

final todoListProvider = FutureProvider.autoDispose.family<TodoList, String>((ref, id) {
  ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
  return ref.read(apiProvider).todo.getList(id);
});

class BookmarksQuery {
  const BookmarksQuery({this.sort = 'time_desc', this.search = '', this.tagId, this.type});
  final String sort;
  final String search;
  final int? tagId;
  final String? type;

  @override
  bool operator ==(Object other) =>
      other is BookmarksQuery &&
      other.sort == sort &&
      other.search == search &&
      other.tagId == tagId &&
      other.type == type;

  @override
  int get hashCode => Object.hash(sort, search, tagId, type);
}

class BookmarksController
    extends AutoDisposeFamilyAsyncNotifier<PagedItems<Bookmark>, BookmarksQuery> {
  @override
  Future<PagedItems<Bookmark>> build(BookmarksQuery arg) async {
    ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
    final items = await ref.read(apiProvider).bookmark.list(
          offset: 0,
          sort: arg.sort,
          search: arg.search,
          tagId: arg.tagId,
          type: arg.type,
        );
    return PagedItems(items: items, page: 0, hasMore: items.length >= pageSize);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final extra = await ref.read(apiProvider).bookmark.list(
            offset: nextPage,
            sort: arg.sort,
            search: arg.search,
            tagId: arg.tagId,
            type: arg.type,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...extra],
          page: nextPage,
          hasMore: extra.length >= pageSize,
          loadingMore: false,
        ),
      );
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

final bookmarksProvider = AutoDisposeAsyncNotifierProvider.family<
    BookmarksController, PagedItems<Bookmark>, BookmarksQuery>(BookmarksController.new);

final bookmarkTagsProvider = FutureProvider.autoDispose<List<TagItem>>((ref) {
  ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
  return ref.read(apiProvider).bookmark.listTags();
});

final bookmarkProvider = FutureProvider.autoDispose.family<Bookmark, int>((ref, id) {
  return ref.read(apiProvider).bookmark.getById(id);
});

class ImagesQuery {
  const ImagesQuery({this.sort = 'time_desc', this.search = '', this.tagId});
  final String sort;
  final String search;
  final int? tagId;

  @override
  bool operator ==(Object other) =>
      other is ImagesQuery &&
      other.sort == sort &&
      other.search == search &&
      other.tagId == tagId;

  @override
  int get hashCode => Object.hash(sort, search, tagId);
}

class ImagesController extends AutoDisposeFamilyAsyncNotifier<PagedItems<BedImage>, ImagesQuery> {
  @override
  Future<PagedItems<BedImage>> build(ImagesQuery arg) async {
    final session = ref.watch(sessionProvider);
    final userId = session.user?.id ?? '';
    final items = await ref.read(apiProvider).imageBed.list(
          userId: userId,
          offset: 0,
          sort: arg.sort,
          search: arg.search,
          tagId: arg.tagId,
        );
    return PagedItems(items: items, page: 0, hasMore: items.length >= pageSize);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final extra = await ref.read(apiProvider).imageBed.list(
            userId: ref.read(sessionProvider).user?.id ?? '',
            offset: nextPage,
            sort: arg.sort,
            search: arg.search,
            tagId: arg.tagId,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...extra],
          page: nextPage,
          hasMore: extra.length >= pageSize,
          loadingMore: false,
        ),
      );
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

final imagesProvider = AutoDisposeAsyncNotifierProvider.family<
    ImagesController, PagedItems<BedImage>, ImagesQuery>(ImagesController.new);

final imageTagsProvider = FutureProvider.autoDispose<List<TagItem>>((ref) {
  ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
  return ref.read(apiProvider).imageBed.listTags();
});

class DriveQuery {
  const DriveQuery({
    this.folderId,
    this.sort = 'time_desc',
    this.search = '',
    this.searchScope = 'current',
  });
  final String? folderId;
  final String sort;
  final String search;
  final String searchScope;

  @override
  bool operator ==(Object other) =>
      other is DriveQuery &&
      other.folderId == folderId &&
      other.sort == sort &&
      other.search == search &&
      other.searchScope == searchScope;

  @override
  int get hashCode => Object.hash(folderId, sort, search, searchScope);
}

class DriveController extends AutoDisposeFamilyAsyncNotifier<DriveListing, DriveQuery> {
  @override
  Future<DriveListing> build(DriveQuery arg) async {
    ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
    return ref.read(apiProvider).fileDrive.list(
          folderId: arg.folderId,
          offset: 0,
          sort: arg.sort,
          search: arg.search,
          searchScope: arg.searchScope,
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

final driveProvider =
    AutoDisposeAsyncNotifierProvider.family<DriveController, DriveListing, DriveQuery>(
  DriveController.new,
);

final groupsProvider = FutureProvider.autoDispose<List<Group>>((ref) {
  ref.watch(sessionProvider.select((s) => s.token));
  return ref.read(apiProvider).group.list();
});

final groupProvider = FutureProvider.autoDispose.family<Group, String>((ref, id) {
  return ref.read(apiProvider).group.getById(id);
});

final groupMembersProvider =
    FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, id) {
  return ref.read(apiProvider).group.listMembers(id);
});

final myInvitesProvider = FutureProvider.autoDispose<List<GroupInvite>>((ref) {
  ref.watch(sessionProvider.select((s) => s.token));
  return ref.read(apiProvider).group.myInvites();
});

final usageStatsProvider = FutureProvider.autoDispose<UsageStats>((ref) {
  ref.watch(sessionProvider.select((s) => '${s.groupId}|${s.token}'));
  return ref.read(apiProvider).setting.getUsageStats();
});

final tokensProvider = FutureProvider.autoDispose<List<AuthToken>>((ref) {
  ref.watch(sessionProvider.select((s) => s.token));
  return ref.read(apiProvider).auth.getTokens();
});
