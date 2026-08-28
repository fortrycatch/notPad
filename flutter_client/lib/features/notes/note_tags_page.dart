import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class NoteTagsPage extends ConsumerWidget {
  const NoteTagsPage({super.key, this.noteId});

  final String? noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(noteTagsProvider);
    final selected = noteId == null ? null : ref.watch(noteItemTagsProvider(noteId!));
    final selectedIds = {
      for (final tag in selected?.valueOrNull ?? const []) tag.id,
    };
    final canEdit = ref.watch(sessionProvider).canEdit;

    return Scaffold(
      appBar: FrostedAppBar(title: Text(noteId == null ? '笔记标签' : '笔记标签')),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _create(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: AsyncBody(
        value: tags,
        onRetry: () => ref.invalidate(noteTagsProvider),
        builder: (items) {
          if (items.isEmpty) {
            return const EmptyView(icon: Icons.label_outline, message: '还没有标签');
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tag = items[index];
              return ListTile(
                title: Text(tag.name),
                trailing: noteId == null
                    ? (canEdit
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, tag.id),
                          )
                        : null)
                    : Checkbox(
                        value: selectedIds.contains(tag.id),
                        onChanged: canEdit
                            ? (value) => _toggle(context, ref, tag.id, value ?? false)
                            : null,
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await promptText(context, title: '新建标签', hint: '标签名');
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).notepad.createTag(name.trim());
      ref.invalidate(noteTagsProvider);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int id) async {
    final ok = await confirm(
      context,
      title: '删除标签',
      message: '不会删除笔记本身。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).notepad.deleteTag(id);
      ref.invalidate(noteTagsProvider);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    int tagId,
    bool add,
  ) async {
    try {
      final api = ref.read(apiProvider);
      if (add) {
        await api.notepad.addTagToNote(noteId!, tagId);
      } else {
        await api.notepad.removeTagFromNote(noteId!, tagId);
      }
      ref.invalidate(noteItemTagsProvider(noteId!));
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
