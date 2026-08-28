import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../providers/todo_selection.dart';
import '../../widgets/list_toolbar.dart';
import '../../widgets/widgets.dart';
import '../home/app_drawer.dart';
import 'todo_list_page.dart';

class TodosPage extends ConsumerWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(todoListsProvider);
    final canEdit = ref.watch(sessionProvider).canEdit;
    final savedId = ref.watch(selectedTodoListProvider);
    final lists = listsAsync.valueOrNull ?? const <TodoList>[];
    final selectedId = ref.read(selectedTodoListProvider.notifier).resolve(lists);
    final selected = lists.where((list) => list.id == selectedId).firstOrNull;

    if (listsAsync.hasValue &&
        lists.isNotEmpty &&
        selectedId != null &&
        selectedId != savedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedTodoListProvider.notifier).select(selectedId);
      });
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: FrostedAppBar(
        leading: const DrawerMenuButton(),
        title: Text(selected?.name ?? '待办'),
        actions: [
          IconButton(
            tooltip: '选择集合',
            onPressed: () => _pickList(context, ref, lists, selectedId, canEdit),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? ShellFab(
              child: FloatingActionButton(
                heroTag: 'todos-fab',
                onPressed: selectedId == null
                    ? () => _createList(context, ref)
                    : () => context.push('/todos/$selectedId/items/create'),
                child: const Icon(Icons.add),
              ),
            )
          : null,
      body: AsyncBody(
        value: listsAsync,
        onRetry: () => ref.invalidate(todoListsProvider),
        builder: (all) {
          if (all.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(todoListsProvider),
              child: ListView(
                children: [
                  const SizedBox(height: 160),
                  const EmptyView(icon: Icons.checklist_outlined, message: '还没有待办集合'),
                  if (canEdit)
                    Center(
                      child: FilledButton(
                        onPressed: () => _createList(context, ref),
                        child: const Text('新建集合'),
                      ),
                    ),
                ],
              ),
            );
          }
          return TodoChecklistView(key: ValueKey(selectedId), listId: selectedId!);
        },
      ),
    );
  }

  Future<void> _pickList(
    BuildContext context,
    WidgetRef ref,
    List<TodoList> lists,
    String? selectedId,
    bool canEdit,
  ) {
    return showListFilterSheet(
      context: context,
      title: '待办集合',
      content: (context, refresh) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final list in lists)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                leading: Icon(
                  selectedId == list.id ? Icons.check_circle : Icons.circle_outlined,
                  color: selectedId == list.id ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(list.name),
                selected: selectedId == list.id,
                onTap: () {
                  ref.read(selectedTodoListProvider.notifier).select(list.id);
                  Navigator.of(context).pop();
                },
                onLongPress: canEdit ? () => _listActions(context, ref, list) : null,
              ),
            if (canEdit)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                leading: const Icon(Icons.add),
                title: const Text('新建集合'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _createList(context, ref);
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final name = await promptText(context, title: '新建集合', hint: '集合名称');
    if (name == null || name.trim().isEmpty) return;
    try {
      final created = await ref.read(apiProvider).todo.createList(name: name.trim());
      ref.invalidate(todoListsProvider);
      await ref.read(selectedTodoListProvider.notifier).select(created.id);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _listActions(BuildContext context, WidgetRef ref, TodoList list) {
    return showActions(context, [
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
    final name = await promptText(context, title: '重命名集合', initial: list.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).todo.updateList(id: list.id, name: name.trim());
      ref.invalidate(todoListsProvider);
      ref.invalidate(todoListProvider(list.id));
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TodoList list) async {
    final ok = await confirm(
      context,
      title: '删除集合',
      message: '将同时删除该集合中的待办。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).todo.deleteList(list.id);
      final selected = ref.read(selectedTodoListProvider);
      if (selected == list.id) {
        await ref.read(selectedTodoListProvider.notifier).select(null);
      }
      ref.invalidate(todoListsProvider);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
