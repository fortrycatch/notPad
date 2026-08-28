import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupsProvider);
    return Scaffold(
      appBar: FrostedAppBar(title: const Text('群组')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/groups/create'),
        child: const Icon(Icons.add),
      ),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(groupsProvider),
        builder: (groups) {
          if (groups.isEmpty) {
            return const EmptyView(icon: Icons.group_outlined, message: '还没有加入群组');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(groupsProvider),
            child: ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.group_outlined)),
                  title: Text(group.name),
                  subtitle: Text(
                    [
                      roleLabel(group.role),
                      if (group.description.isNotEmpty) group.description,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => context.push('/groups/${group.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class GroupCreatePage extends ConsumerStatefulWidget {
  const GroupCreatePage({super.key});

  @override
  ConsumerState<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends ConsumerState<GroupCreatePage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, '请输入群组名称');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).group.create(
            name: _name.text.trim(),
            description: _description.text.trim(),
          );
      ref.invalidate(groupsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FrostedAppBar(
        title: const Text('新建群组'),
        actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('创建'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: '名称')),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '简介'),
          ),
        ],
      ),
    );
  }
}
