import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/lists.dart';
import '../../providers/nav_tabs.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class HomeDrawerController extends InheritedWidget {
  const HomeDrawerController({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static void open(BuildContext context) {
    final controller = context.dependOnInheritedWidgetOfExactType<HomeDrawerController>();
    controller?.openDrawer();
  }

  @override
  bool updateShouldNotify(HomeDrawerController oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}

class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: '菜单',
      onPressed: () => HomeDrawerController.open(context),
    );
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final currentGroup = groups.where((item) => item.id == session.groupId).firstOrNull;
    final nav = ref.watch(navTabsProvider);
    final hiddenTabs = nav.order.where((tab) => !nav.enabled.contains(tab)).toList();

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  (user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase(),
                ),
              ),
              title: Text(user?.name ?? '未登录'),
              subtitle: Text(user?.email ?? ''),
              onTap: () => _go(context, '/settings/profile'),
            ),
            const Divider(),
            ExpansionTile(
              leading: Icon(
                session.groupId == null ? Icons.person_outline : Icons.workspaces_outlined,
              ),
              title: Text(currentGroup?.name ?? '个人空间'),
              subtitle: Text(
                currentGroup == null ? '当前空间' : roleLabel(currentGroup.role),
              ),
              children: [
                ListTile(
                  leading: Icon(
                    session.groupId == null ? Icons.person : Icons.person_outline,
                  ),
                  title: const Text('个人空间'),
                  selected: session.groupId == null,
                  onTap: () => _switchSpace(context, ref),
                ),
                for (final group in groups)
                  ListTile(
                    leading: Icon(
                      session.groupId == group.id
                          ? Icons.workspaces
                          : Icons.workspaces_outlined,
                    ),
                    title: Text(group.name),
                    subtitle: Text(roleLabel(group.role)),
                    selected: session.groupId == group.id,
                    onTap: () => _switchSpace(
                      context,
                      ref,
                      groupId: group.id,
                      role: group.role,
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('管理群组'),
                  onTap: () => _go(context, '/groups'),
                ),
              ],
            ),
            if (hiddenTabs.isNotEmpty) ...[
              const Divider(),
              for (final tab in hiddenTabs)
                ListTile(
                  leading: Icon(tab.icon),
                  title: Text(tab.label),
                  onTap: () => _goTab(context, tab.path),
                ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('我的邀请'),
              onTap: () => _go(context, '/invites'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('用量统计'),
              onTap: () => _go(context, '/settings/stats'),
            ),
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: const Text('登录会话'),
              onTap: () => _go(context, '/settings/sessions'),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('主题色'),
              onTap: () => _go(context, '/settings/theme'),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('底部导航'),
              onTap: () => _go(context, '/settings/nav'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              onTap: () => _go(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchSpace(
    BuildContext context,
    WidgetRef ref, {
    String? groupId,
    String? role,
  }) async {
    Navigator.of(context).pop();
    await ref.read(sessionProvider.notifier).setGroup(groupId: groupId, role: role);
  }

  void _go(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.push(location);
  }

  void _goTab(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.go(location);
  }
}
