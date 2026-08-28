import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('个人资料'),
            onTap: () => context.push('/settings/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题色'),
            onTap: () => context.push('/settings/theme'),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('底部导航'),
            subtitle: const Text('选择底栏显示的页面'),
            onTap: () => context.push('/settings/nav'),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('服务器地址'),
            subtitle: Text(session.baseUrl),
            onTap: () => context.push('/server'),
          ),
          ListTile(
            leading: const Icon(Icons.workspaces_outlined),
            title: const Text('当前空间'),
            subtitle: Text(session.groupId == null ? '个人空间' : roleLabel(session.groupRole)),
            onTap: () => context.push('/groups'),
          ),
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
            leading: const Icon(Icons.tune_outlined),
            title: const Text('键值设置'),
            onTap: () => context.push('/settings/keys'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('退出登录', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              final ok = await confirm(context, title: '退出登录', message: '确定退出当前账号？');
              if (!ok) return;
              await ref.read(sessionProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _avatar = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    _name.text = user?.name ?? '';
    _email.text = user?.email ?? '';
    _avatar.text = user?.avatar ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiProvider);
      await api.auth.updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (_avatar.text.trim().isNotEmpty) {
        await api.auth.updateMeta({'avatar': _avatar.text.trim()});
      }
      await ref.read(sessionProvider.notifier).refreshProfile();
      if (mounted) {
        showMessage(context, '已保存');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人资料'),
        actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('用户 ID'),
            subtitle: Text(user?.id ?? ''),
          ),
          TextField(controller: _name, decoration: const InputDecoration(labelText: '昵称')),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: const InputDecoration(labelText: '邮箱')),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '新密码（可选）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avatar,
            decoration: const InputDecoration(labelText: '头像 URL（可选）'),
          ),
        ],
      ),
    );
  }
}

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(usageStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('用量统计'),
        actions: [
          IconButton(
            tooltip: '重新计算',
            onPressed: () async {
              try {
                await ref.read(apiProvider).setting.recalculateStats();
                ref.invalidate(usageStatsProvider);
                if (context.mounted) showMessage(context, '已重新计算');
              } catch (error) {
                if (context.mounted) showError(context, error);
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(usageStatsProvider),
        builder: (stats) {
          return ListView(
            children: [
              ListTile(title: const Text('笔记'), trailing: Text('${stats.notesCount}')),
              ListTile(title: const Text('书签'), trailing: Text('${stats.bookmarksCount}')),
              ListTile(title: const Text('图片'), trailing: Text('${stats.imagesCount}')),
              ListTile(title: const Text('图片体积'), trailing: Text(formatBytes(stats.imagesSize))),
              ListTile(title: const Text('文件'), trailing: Text('${stats.filesCount}')),
              ListTile(title: const Text('文件体积'), trailing: Text(formatBytes(stats.filesSize))),
            ],
          );
        },
      ),
    );
  }
}

class SettingKeysPage extends ConsumerStatefulWidget {
  const SettingKeysPage({super.key});

  @override
  ConsumerState<SettingKeysPage> createState() => _SettingKeysPageState();
}

class _SettingKeysPageState extends ConsumerState<SettingKeysPage> {
  Map<String, String> _items = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ref.read(apiProvider).setting.getAll();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.entries.where((entry) => !entry.key.startsWith('stat_')).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('键值设置')),
      floatingActionButton: FloatingActionButton(
        onPressed: _edit,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: visible.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        EmptyView(icon: Icons.tune_outlined, message: '没有自定义设置'),
                      ],
                    )
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = visible[index];
                        return ListTile(
                          title: Text(entry.key),
                          subtitle: Text(entry.value),
                          onTap: () => _edit(key: entry.key, value: entry.value),
                          onLongPress: () => _remove(entry.key),
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _edit({String? key, String? value}) async {
    final nextKey = key ?? await promptText(context, title: '设置键', hint: 'key');
    if (nextKey == null || nextKey.trim().isEmpty || !mounted) return;
    final nextValue = await promptText(context, title: '设置值', initial: value);
    if (nextValue == null) return;
    try {
      await ref.read(apiProvider).setting.set(nextKey.trim(), nextValue);
      await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _remove(String key) async {
    final ok = await confirm(
      context,
      title: '删除设置',
      message: '确定删除 $key？',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).setting.remove(key);
      await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}

class SessionsPage extends ConsumerWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tokensProvider);
    final current = ref.watch(sessionProvider).token;
    return Scaffold(
      appBar: AppBar(title: const Text('登录会话')),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(tokensProvider),
        builder: (tokens) {
          if (tokens.isEmpty) {
            return const EmptyView(icon: Icons.devices_outlined, message: '没有会话');
          }
          return ListView.separated(
            itemCount: tokens.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final token = tokens[index];
              final isCurrent = current != null && token.token == current;
              return ListTile(
                title: Text(token.alias?.isNotEmpty == true ? token.alias! : '未命名会话'),
                subtitle: Text(
                  [
                    if (isCurrent) '当前设备',
                    formatDateTime(token.createdAt),
                    if (token.userAgent != null) token.userAgent!,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _actions(context, ref, token.token, isCurrent),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _actions(
    BuildContext context,
    WidgetRef ref,
    String tokenHash,
    bool isCurrent,
  ) {
    return showActions(context, [
      SheetAction(
        icon: Icons.edit_outlined,
        label: '设置别名',
        onTap: () async {
          final alias = await promptText(context, title: '会话别名');
          if (alias == null) return;
          try {
            await ref.read(apiProvider).auth.setTokenAlias(tokenHash, alias.trim());
            ref.invalidate(tokensProvider);
          } catch (error) {
            if (context.mounted) showError(context, error);
          }
        },
      ),
      if (!isCurrent)
        SheetAction(
          icon: Icons.logout,
          label: '撤销会话',
          destructive: true,
          onTap: () async {
            final ok = await confirm(
              context,
              title: '撤销会话',
              message: '该设备将需要重新登录。',
              destructive: true,
            );
            if (!ok) return;
            try {
              await ref.read(apiProvider).auth.revokeToken(tokenHash);
              ref.invalidate(tokensProvider);
            } catch (error) {
              if (context.mounted) showError(context, error);
            }
          },
        ),
    ]);
  }
}
