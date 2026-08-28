import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../widgets/widgets.dart';

class ResourcePickerPage extends ConsumerWidget {
  const ResourcePickerPage({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: switch (type) {
        'note' => _NotesPicker(onPick: (refItem) => Navigator.pop(context, refItem)),
        'image' => _ImagesPicker(onPick: (refItem) => Navigator.pop(context, refItem)),
        'file' => _FilesPicker(onPick: (refItem) => Navigator.pop(context, refItem)),
        'bookmark' => _BookmarksPicker(onPick: (refItem) => Navigator.pop(context, refItem)),
        _ => const EmptyView(icon: Icons.error_outline, message: '不支持的类型'),
      },
    );
  }

  String get _title {
    switch (type) {
      case 'note':
        return '选择笔记';
      case 'image':
        return '选择图片';
      case 'file':
        return '选择文件';
      case 'bookmark':
        return '选择书签';
      default:
        return '选择';
    }
  }
}

class _NotesPicker extends ConsumerWidget {
  const _NotesPicker({required this.onPick});
  final ValueChanged<TodoRef> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notesProvider(const NotesQuery()));
    return AsyncBody(
      value: async,
      builder: (data) {
        if (data.items.isEmpty) {
          return const EmptyView(icon: Icons.sticky_note_2_outlined, message: '没有笔记');
        }
        return ListView.separated(
          itemCount: data.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final note = data.items[index];
            return ListTile(
              title: Text(note.title.isEmpty ? '未命名笔记' : note.title),
              onTap: () => onPick(
                TodoRef(
                  type: 'note',
                  refId: note.id,
                  title: note.title.isEmpty ? '未命名笔记' : note.title,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ImagesPicker extends ConsumerWidget {
  const _ImagesPicker({required this.onPick});
  final ValueChanged<TodoRef> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(imagesProvider(const ImagesQuery()));
    return AsyncBody(
      value: async,
      builder: (data) {
        if (data.items.isEmpty) {
          return const EmptyView(icon: Icons.image_outlined, message: '没有图片');
        }
        return ListView.separated(
          itemCount: data.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final image = data.items[index];
            return ListTile(
              title: Text(image.name),
              onTap: () => onPick(
                TodoRef(
                  type: 'image',
                  refId: '${image.id}',
                  title: image.name,
                  url: image.url,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilesPicker extends ConsumerWidget {
  const _FilesPicker({required this.onPick});
  final ValueChanged<TodoRef> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driveProvider(const DriveQuery()));
    return AsyncBody(
      value: async,
      builder: (data) {
        if (data.files.isEmpty) {
          return const EmptyView(icon: Icons.folder_outlined, message: '当前目录没有文件');
        }
        return ListView.separated(
          itemCount: data.files.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final file = data.files[index];
            return ListTile(
              title: Text(file.name),
              onTap: () => onPick(
                TodoRef(
                  type: 'file',
                  refId: '${file.id}',
                  title: file.name,
                  mimeType: file.mimeType,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BookmarksPicker extends ConsumerWidget {
  const _BookmarksPicker({required this.onPick});
  final ValueChanged<TodoRef> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookmarksProvider(const BookmarksQuery()));
    return AsyncBody(
      value: async,
      builder: (data) {
        if (data.items.isEmpty) {
          return const EmptyView(icon: Icons.bookmark_outline, message: '没有书签');
        }
        return ListView.separated(
          itemCount: data.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final bookmark = data.items[index];
            return ListTile(
              title: Text(bookmark.title),
              onTap: () => onPick(
                TodoRef(
                  type: 'bookmark',
                  refId: '${bookmark.id}',
                  title: bookmark.title,
                  bookmarkType: bookmark.type,
                  url: bookmark.url,
                  targetRefId: bookmark.refId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
