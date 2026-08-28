import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/server_page.dart';
import '../features/bookmarks/bookmark_create_page.dart';
import '../features/bookmarks/bookmark_detail_page.dart';
import '../features/bookmarks/bookmarks_page.dart';
import '../features/drive/drive_page.dart';
import '../features/feed/feed_page.dart';
import '../features/groups/group_chat_page.dart';
import '../features/groups/group_detail_page.dart';
import '../features/groups/groups_page.dart';
import '../features/home/home_shell.dart';
import '../features/images/image_detail_page.dart';
import '../features/images/images_page.dart';
import '../features/notes/note_detail_page.dart';
import '../features/notes/note_edit_page.dart';
import '../features/notes/note_tags_page.dart';
import '../features/notes/notes_page.dart';
import '../features/pickers/resource_picker_page.dart';
import '../features/settings/settings_pages.dart';
import '../features/settings/theme_page.dart';
import '../features/splash/splash_page.dart';
import '../features/tags/tag_manager_page.dart';
import '../widgets/image_viewer.dart';
import '../features/todos/todo_item_page.dart';
import '../features/todos/todo_list_page.dart';
import '../features/todos/todos_page.dart';
import '../models/models.dart';
import '../providers/session.dart';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (previous, next) => refresh.ping());

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/feed',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final authPage = loc == '/login' || loc == '/register';
      if (!session.ready) {
        return loc == '/splash' ? null : '/splash';
      }
      if (!session.isLoggedIn && !authPage && loc != '/server') {
        return '/login';
      }
      if (session.isLoggedIn && (authPage || loc == '/splash' || loc == '/more')) {
        return '/feed';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/server', builder: (context, state) => const ServerPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                pageBuilder: (context, state) => const NoTransitionPage(child: FeedPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notes',
                pageBuilder: (context, state) => const NoTransitionPage(child: NotesPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/todos',
                pageBuilder: (context, state) => const NoTransitionPage(child: TodosPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookmarks',
                pageBuilder: (context, state) => const NoTransitionPage(child: BookmarksPage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/notes/create',
        builder: (context, state) => const NoteEditPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/notes/tags',
        builder: (context, state) => const NoteTagsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/notes/:id',
        builder: (context, state) => NoteDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/notes/:id/edit',
        builder: (context, state) => NoteEditPage(id: state.pathParameters['id']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/notes/:id/tags',
        builder: (context, state) => NoteTagsPage(noteId: state.pathParameters['id']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/todos/:listId',
        builder: (context, state) => TodoListPage(listId: state.pathParameters['listId']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/todos/:listId/items/create',
        builder: (context, state) => TodoItemPage(listId: state.pathParameters['listId']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/todos/:listId/items/:itemId',
        builder: (context, state) => TodoItemPage(
          listId: state.pathParameters['listId']!,
          itemId: state.pathParameters['itemId'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/bookmarks/create',
        builder: (context, state) => const BookmarkCreatePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/bookmarks/tags',
        builder: (context, state) {
          final extra = state.extra;
          final bookmarkId = extra is int ? extra : null;
          return TagManagerPage(
            title: '书签标签',
            listTags: () => ref.read(apiProvider).bookmark.listTags(),
            createTag: (name) => ref.read(apiProvider).bookmark.createTag(name),
            deleteTag: (id) => ref.read(apiProvider).bookmark.deleteTag(id),
            loadSelected: bookmarkId == null
                ? null
                : () async {
                    final tags = await ref.read(apiProvider).bookmark.getBookmarkTags(bookmarkId);
                    return {for (final tag in tags) tag.id};
                  },
            onToggle: bookmarkId == null
                ? null
                : (tagId, add) async {
                    final api = ref.read(apiProvider);
                    if (add) {
                      await api.bookmark.addTagToBookmark(bookmarkId, tagId);
                    } else {
                      await api.bookmark.removeTagFromBookmark(bookmarkId, tagId);
                    }
                  },
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/bookmarks/:id',
        builder: (context, state) => BookmarkDetailPage(
          id: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/images',
        builder: (context, state) => const ImagesPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/images/tags',
        builder: (context, state) {
          final extra = state.extra;
          final imageId = extra is int ? extra : null;
          return TagManagerPage(
            title: '图片标签',
            listTags: () => ref.read(apiProvider).imageBed.listTags(),
            createTag: (name) => ref.read(apiProvider).imageBed.createTag(name),
            deleteTag: (id) => ref.read(apiProvider).imageBed.deleteTag(id),
            loadSelected: imageId == null
                ? null
                : () async {
                    final tags = await ref.read(apiProvider).imageBed.getImageTags(imageId);
                    return {for (final tag in tags) tag.id};
                  },
            onToggle: imageId == null
                ? null
                : (tagId, add) async {
                    final api = ref.read(apiProvider);
                    if (add) {
                      await api.imageBed.addTagToImage(imageId, tagId);
                    } else {
                      await api.imageBed.removeTagFromImage(imageId, tagId);
                    }
                  },
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/images/:id',
        builder: (context, state) => ImageDetailPage(
          id: int.parse(state.pathParameters['id']!),
          initial: state.extra is BedImage ? state.extra as BedImage : null,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/viewer',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ImageViewerArgs) {
            return ImageViewerPage(url: extra.url, title: extra.title);
          }
          return const ImageViewerPage(url: '');
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/drive',
        builder: (context, state) => const DrivePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/drive/folders/:folderId',
        builder: (context, state) => DrivePage(folderId: state.pathParameters['folderId']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/drive/files/:id',
        builder: (context, state) => DriveFilePage(
          id: int.parse(state.pathParameters['id']!),
          initial: state.extra is DriveFile ? state.extra as DriveFile : null,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/groups',
        builder: (context, state) => const GroupsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/groups/create',
        builder: (context, state) => const GroupCreatePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/groups/:id',
        builder: (context, state) => GroupDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/groups/:id/members',
        builder: (context, state) => GroupMembersPage(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/groups/:id/invites',
        builder: (context, state) => GroupInvitesPage(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/groups/:id/chat',
        builder: (context, state) => GroupChatPage(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/invites',
        builder: (context, state) => const MyInvitesPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/settings/theme',
        builder: (context, state) => const ThemePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/settings/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/settings/stats',
        builder: (context, state) => const StatsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/settings/sessions',
        builder: (context, state) => const SessionsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/settings/keys',
        builder: (context, state) => const SettingKeysPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/pick/:type',
        builder: (context, state) => ResourcePickerPage(type: state.pathParameters['type']!),
      ),
    ],
  );
});
