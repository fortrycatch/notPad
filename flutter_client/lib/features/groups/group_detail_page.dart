import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class GroupDetailPage extends ConsumerWidget {
  const GroupDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupProvider(id));
    return Scaffold(
      appBar: FrostedAppBar(title: const Text('群组')),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(groupProvider(id)),
        builder: (group) {
          final role = group.role;
          final isAdmin = role == 'owner' || role == 'admin';
          final isOwner = role == 'owner';
          return ListView(
            children: [
              ListTile(
                title: Text(group.name, style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text(group.description.isEmpty ? '暂无简介' : group.description),
              ),
              ListTile(
                title: const Text('我的角色'),
                subtitle: Text(roleLabel(role)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('群聊'),
                onTap: () => context.push('/groups/$id/chat'),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('成员'),
                onTap: () => context.push('/groups/$id/members'),
              ),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('邀请'),
                  onTap: () => context.push('/groups/$id/invites'),
                ),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('编辑资料'),
                  onTap: () => _edit(context, ref, group),
                ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('切换到此空间'),
                onTap: () async {
                  await ref.read(sessionProvider.notifier).setGroup(
                        groupId: group.id,
                        role: group.role,
                      );
                  if (context.mounted) showMessage(context, '已切换');
                },
              ),
              if (!isOwner)
                ListTile(
                  leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                  title: Text('退出群组', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () => _leave(context, ref),
                ),
              if (isOwner)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  title: Text('解散群组', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () => _delete(context, ref),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Group group) async {
    final name = await promptText(context, title: '群组名称', initial: group.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).group.update(
            groupId: id,
            name: name.trim(),
            description: group.description,
          );
      ref.invalidate(groupProvider(id));
      ref.invalidate(groupsProvider);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(context, title: '退出群组', message: '确定要离开这个群组吗？');
    if (!ok) return;
    try {
      await ref.read(apiProvider).group.leave(id);
      final session = ref.read(sessionProvider);
      if (session.groupId == id) {
        await ref.read(sessionProvider.notifier).setGroup();
      }
      ref.invalidate(groupsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: '解散群组',
      message: '此操作不可恢复。',
      confirmLabel: '解散',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).group.delete(id);
      final session = ref.read(sessionProvider);
      if (session.groupId == id) {
        await ref.read(sessionProvider.notifier).setGroup();
      }
      ref.invalidate(groupsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}

class GroupMembersPage extends ConsumerWidget {
  const GroupMembersPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(groupId));
    final group = ref.watch(groupProvider(groupId));
    final myRole = group.valueOrNull?.role;
    final isAdmin = myRole == 'owner' || myRole == 'admin';
    final isOwner = myRole == 'owner';
    return Scaffold(
      appBar: FrostedAppBar(
        title: const Text('成员'),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () => _invite(context, ref),
              icon: const Icon(Icons.person_add_outlined),
            ),
        ],
      ),
      body: AsyncBody(
        value: members,
        onRetry: () => ref.invalidate(groupMembersProvider(groupId)),
        builder: (items) {
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = items[index];
              return ListTile(
                title: Text(member.userName ?? member.userId),
                subtitle: Text('${roleLabel(member.role)} · ${member.userId}'),
                onTap: isAdmin && member.role != 'owner'
                    ? () => _memberActions(context, ref, member, isOwner)
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final userId = await promptText(context, title: '邀请用户', hint: '对方用户 ID');
    if (userId == null || userId.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).group.inviteUser(
            groupId: groupId,
            userId: userId.trim(),
          );
      if (context.mounted) showMessage(context, '已发送邀请');
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _memberActions(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
    bool isOwner,
  ) {
    return showActions(context, [
      SheetAction(
        icon: Icons.manage_accounts_outlined,
        label: '修改角色',
        onTap: () => _changeRole(context, ref, member),
      ),
      if (isOwner)
        SheetAction(
          icon: Icons.workspace_premium_outlined,
          label: '转让所有权',
          onTap: () => _transfer(context, ref, member),
        ),
      SheetAction(
        icon: Icons.person_remove_outlined,
        label: '移出群组',
        destructive: true,
        onTap: () => _remove(context, ref, member),
      ),
    ]);
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, GroupMember member) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in const ['admin', 'editor', 'viewer'])
                ListTile(
                  title: Text(roleLabel(value)),
                  onTap: () => Navigator.pop(context, value),
                ),
            ],
          ),
        );
      },
    );
    if (role == null) return;
    try {
      await ref.read(apiProvider).group.updateMemberRole(
            groupId: groupId,
            userId: member.userId,
            role: role,
          );
      ref.invalidate(groupMembersProvider(groupId));
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref, GroupMember member) async {
    final ok = await confirm(
      context,
      title: '转让所有权',
      message: '确定将所有权转给 ${member.userName ?? member.userId}？',
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).group.transferOwnership(
            groupId: groupId,
            newOwnerId: member.userId,
          );
      ref.invalidate(groupMembersProvider(groupId));
      ref.invalidate(groupProvider(groupId));
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, GroupMember member) async {
    final ok = await confirm(
      context,
      title: '移出成员',
      message: '确定移出 ${member.userName ?? member.userId}？',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).group.removeMember(
            groupId: groupId,
            userId: member.userId,
          );
      ref.invalidate(groupMembersProvider(groupId));
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}

class GroupInvitesPage extends ConsumerStatefulWidget {
  const GroupInvitesPage({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupInvitesPage> createState() => _GroupInvitesPageState();
}

class _GroupInvitesPageState extends ConsumerState<GroupInvitesPage> {
  List<GroupInvite> _pending = const [];
  List<GroupInvite> _links = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      final pending = await api.group.listPendingInvites(widget.groupId);
      final links = await api.group.listInviteCodes(widget.groupId);
      if (mounted) {
        setState(() {
          _pending = pending;
          _links = links;
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FrostedAppBar(title: const Text('邀请')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createLink,
        child: const Icon(Icons.add_link),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  const ListTile(title: Text('邀请链接')),
                  if (_links.isEmpty)
                    const ListTile(subtitle: Text('还没有邀请链接')),
                  for (final invite in _links)
                    ListTile(
                      title: Text(invite.inviteCode ?? invite.id),
                      subtitle: Text(roleLabel(invite.role)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: invite.inviteCode ?? ''));
                          showMessage(context, '已复制邀请码');
                        },
                      ),
                      onLongPress: () => _remove(invite.id),
                    ),
                  const Divider(),
                  const ListTile(title: Text('待处理邀请')),
                  if (_pending.isEmpty)
                    const ListTile(subtitle: Text('没有待处理邀请')),
                  for (final invite in _pending)
                    ListTile(
                      title: Text(invite.invitedUserId ?? invite.id),
                      subtitle: Text(roleLabel(invite.role)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _remove(invite.id),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _createLink() async {
    try {
      await ref.read(apiProvider).group.createInviteLink(groupId: widget.groupId);
      await _load();
      if (mounted) showMessage(context, '已创建邀请链接');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await ref.read(apiProvider).group.removeInvite(id);
      await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}

class MyInvitesPage extends ConsumerWidget {
  const MyInvitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myInvitesProvider);
    return Scaffold(
      appBar: FrostedAppBar(
        title: const Text('我的邀请'),
        actions: [
          IconButton(
            onPressed: () => _acceptCode(context, ref),
            icon: const Icon(Icons.add),
            tooltip: '输入邀请码',
          ),
        ],
      ),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(myInvitesProvider),
        builder: (items) {
          if (items.isEmpty) {
            return const EmptyView(icon: Icons.mail_outline, message: '没有待处理邀请');
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final invite = items[index];
              return ListTile(
                title: Text(invite.groupName ?? invite.groupId),
                subtitle: Text(roleLabel(invite.role)),
                trailing: TextButton(
                  onPressed: () => _accept(context, ref, invite.id),
                  child: const Text('接受'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref, String inviteId) async {
    try {
      await ref.read(apiProvider).group.acceptInvite(inviteId: inviteId);
      ref.invalidate(myInvitesProvider);
      ref.invalidate(groupsProvider);
      if (context.mounted) showMessage(context, '已加入群组');
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _acceptCode(BuildContext context, WidgetRef ref) async {
    final code = await promptText(context, title: '邀请码', hint: '粘贴邀请码');
    if (code == null || code.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).group.acceptInvite(inviteCode: code.trim());
      ref.invalidate(myInvitesProvider);
      ref.invalidate(groupsProvider);
      if (context.mounted) showMessage(context, '已加入群组');
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
