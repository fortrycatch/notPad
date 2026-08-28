import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class TodoListPage extends ConsumerWidget {
  const TodoListPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todoListProvider(listId));
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.name ?? '待办'),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => context.push('/todos/$listId/items/create'),
              child: const Icon(Icons.add),
            )
          : null,
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(todoListProvider(listId)),
        builder: (list) {
          if (list.items.isEmpty) {
            return const EmptyView(icon: Icons.check_circle_outline, message: '还没有待办');
          }
          final pending = list.items.where((item) => !item.done).toList();
          final done = list.items.where((item) => item.done).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todoListProvider(listId)),
            child: ListView(
              children: [
                for (final item in pending) _tile(context, ref, item, canEdit),
                if (done.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('已完成'),
                  ),
                  for (final item in done) _tile(context, ref, item, canEdit),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, TodoItem item, bool canEdit) {
    return ListTile(
      leading: Checkbox(
        value: item.done,
        onChanged: canEdit ? (value) => _toggle(context, ref, item, value ?? false) : null,
      ),
      title: Text(
        item.title,
        style: item.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: item.description.isEmpty && item.refs.isEmpty
          ? null
          : Text(
              [
                if (item.description.isNotEmpty) item.description,
                if (item.refs.isNotEmpty) '${item.refs.length} 个引用',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () => context.push('/todos/$listId/items/${item.id}'),
      onLongPress: canEdit
          ? () => showActions(context, [
                SheetAction(
                  icon: Icons.edit_outlined,
                  label: '编辑',
                  onTap: () => context.push('/todos/$listId/items/${item.id}'),
                ),
                SheetAction(
                  icon: Icons.delete_outline,
                  label: '删除',
                  destructive: true,
                  onTap: () => _delete(context, ref, item),
                ),
              ])
          : null,
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    TodoItem item,
    bool done,
  ) async {
    try {
      await ref.read(apiProvider).todo.updateItem(id: item.id, done: done ? 1 : 0);
      ref.invalidate(todoListProvider(listId));
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TodoItem item) async {
    final ok = await confirm(
      context,
      title: '删除待办',
      message: '删除后无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).todo.deleteItem(item.id);
      ref.invalidate(todoListProvider(listId));
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
