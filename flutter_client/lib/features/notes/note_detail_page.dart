import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(noteProvider(id));
    final tags = ref.watch(noteItemTagsProvider(id));
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
        actions: [
          IconButton(
            tooltip: '收藏',
            onPressed: () => _toggleBookmark(context, ref),
            icon: const Icon(Icons.star_outline),
          ),
          if (canEdit)
            IconButton(
              tooltip: '编辑',
              onPressed: () => context.push('/notes/$id/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  await _delete(context, ref);
                } else if (value == 'tags') {
                  await context.push('/notes/$id/tags');
                  ref.invalidate(noteItemTagsProvider(id));
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'tags', child: Text('标签')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
        ],
      ),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(noteProvider(id)),
        builder: (note) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                note.title.isEmpty ? '未命名笔记' : note.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '更新于 ${formatDateTime(note.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (tags.hasValue && tags.requireValue.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in tags.requireValue) Chip(label: Text(tag.name)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SelectableText(
                note.content.isEmpty ? '（空）' : note.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleBookmark(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(apiProvider);
      final state = await api.bookmark.isBookmarked(type: 'note', refId: id);
      if (state.bookmarked && state.id != null) {
        await api.bookmark.remove(state.id!);
        if (context.mounted) showMessage(context, '已取消收藏');
      } else {
        final note = await api.notepad.getNoteById(id);
        await api.bookmark.add(
          type: 'note',
          title: note.title.isEmpty ? '未命名笔记' : note.title,
          description: note.content.length > 200 ? note.content.substring(0, 200) : note.content,
          refId: id,
        );
        if (context.mounted) showMessage(context, '已收藏');
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: '删除笔记',
      message: '删除后无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).notepad.deleteNote(id);
      ref.invalidate(timelineProvider);
      if (context.mounted) {
        showMessage(context, '已删除');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
