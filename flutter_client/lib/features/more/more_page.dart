import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final groups = ref.watch(groupsProvider);
    final currentGroup = groups.maybeWhen(
      data: (items) => items.where((item) => item.id == session.groupId).firstOrNull,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text((user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase()),
            ),
            title: Text(user?.name ?? '未登录'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.workspaces_outlined),
            title: const Text('当前空间'),
            subtitle: Text(
              session.groupId == null
                  ? '个人空间'
                  : '${currentGroup?.name ?? '群组'} · ${roleLabel(session.groupRole)}',
            ),
            onTap: () => showScopeSheet(context, ref, groups.valueOrNull ?? const []),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('图床'),
            onTap: () => context.push('/images'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('网盘'),
            onTap: () => context.push('/drive'),
          ),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('群组'),
            onTap: () => context.push('/groups'),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('我的邀请'),
            onTap: () => context.push('/invites'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('用量统计'),
            onTap: () => context.push('/settings/stats'),
          ),
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: const Text('登录会话'),
            onTap: () => context.push('/settings/sessions'),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('设置'),
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}
