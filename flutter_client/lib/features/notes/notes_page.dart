import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';
import '../home/app_drawer.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  int? _tagId;

  NotesQuery get _query => NotesQuery(tagId: _tagId);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notesProvider(_query));
    final tags = ref.watch(noteTagsProvider);
    final canEdit = ref.watch(sessionProvider).canEdit;

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('笔记'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: '标签',
              onPressed: _manageTags,
              icon: const Icon(Icons.label_outline),
            ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => context.push('/notes/create'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          if (tags.hasValue && tags.requireValue.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('全部'),
                      selected: _tagId == null,
                      onSelected: (_) => setState(() => _tagId = null),
                    ),
                  ),
                  for (final tag in tags.requireValue)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag.name),
                        selected: _tagId == tag.id,
                        onSelected: (_) => setState(() => _tagId = tag.id),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: AsyncBody(
              value: async,
              onRetry: () => ref.read(notesProvider(_query).notifier).refresh(),
              builder: (data) {
                if (data.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(notesProvider(_query).notifier).refresh(),
                    child: ListView(
                      children: const [
                        SizedBox(height: 160),
                        EmptyView(icon: Icons.sticky_note_2_outlined, message: '还没有笔记'),
                      ],
                    ),
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 240) {
                      ref.read(notesProvider(_query).notifier).loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => ref.read(notesProvider(_query).notifier).refresh(),
                    child: ListView.separated(
                      itemCount: data.items.length + (data.loadingMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index >= data.items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final note = data.items[index];
                        return ListTile(
                          title: Text(note.title.isEmpty ? '未命名笔记' : note.title),
                          subtitle: Text(
                            [
                              formatDateTime(note.updatedAt),
                              if (note.content.isNotEmpty) note.content,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => context.push('/notes/${note.id}'),
                          onLongPress: () => _actions(note),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _actions(NoteListItem note) async {
    final canEdit = ref.read(sessionProvider).canEdit;
    await showActions(context, [
      SheetAction(
        icon: Icons.open_in_new,
        label: '打开',
        onTap: () => context.push('/notes/${note.id}'),
      ),
      if (canEdit)
        SheetAction(
          icon: Icons.edit_outlined,
          label: '编辑',
          onTap: () => context.push('/notes/${note.id}/edit'),
        ),
      if (canEdit)
        SheetAction(
          icon: Icons.delete_outline,
          label: '删除',
          destructive: true,
          onTap: () => _delete(note.id),
        ),
    ]);
  }

  Future<void> _delete(String id) async {
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
      ref.invalidate(notesProvider(_query));
      ref.invalidate(timelineProvider);
      if (mounted) showMessage(context, '已删除');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _manageTags() async {
    await context.push('/notes/tags');
    ref.invalidate(noteTagsProvider);
  }
}
