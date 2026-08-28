import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';
import '../home/app_drawer.dart';

class TodosPage extends ConsumerWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todoListsProvider);
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: FrostedAppBar(
        leading: const DrawerMenuButton(),
        title: const Text('待办'),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _create(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(todoListsProvider),
        builder: (lists) {
          if (lists.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(todoListsProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 160),
                  EmptyView(icon: Icons.check_circle_outline, message: '还没有待办列表'),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todoListsProvider),
            child: ListView.separated(
              itemCount: lists.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final list = lists[index];
                final color = _parseColor(list.color);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(Icons.list_alt, color: color),
                  ),
                  title: Text(list.name),
                  onTap: () => context.push('/todos/${list.id}'),
                  onLongPress: canEdit ? () => _actions(context, ref, list) : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await promptText(context, title: '新建列表', hint: '列表名称');
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).todo.createList(name: name.trim());
      ref.invalidate(todoListsProvider);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _actions(BuildContext context, WidgetRef ref, TodoList list) {
    return showActions(context, [
      SheetAction(
        icon: Icons.open_in_new,
        label: '打开',
        onTap: () => context.push('/todos/${list.id}'),
      ),
      SheetAction(
        icon: Icons.edit_outlined,
        label: '重命名',
        onTap: () => _rename(context, ref, list),
      ),
      SheetAction(
        icon: Icons.delete_outline,
        label: '删除',
        destructive: true,
        onTap: () => _delete(context, ref, list),
      ),
    ]);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, TodoList list) async {
    final name = await promptText(context, title: '重命名列表', initial: list.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).todo.updateList(id: list.id, name: name.trim());
      ref.invalidate(todoListsProvider);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TodoList list) async {
    final ok = await confirm(
      context,
      title: '删除列表',
      message: '将同时删除该列表中的待办。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).todo.deleteList(list.id);
      ref.invalidate(todoListsProvider);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}

Color _parseColor(String raw) {
  var hex = raw.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return Colors.grey;
  return Color(value);
}
