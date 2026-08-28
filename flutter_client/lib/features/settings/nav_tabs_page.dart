import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/nav_tabs.dart';
import '../../widgets/widgets.dart';

class NavTabsPage extends ConsumerWidget {
  const NavTabsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navTabsProvider);
    final visible = nav.visible;
    final hidden = nav.order.where((tab) => !nav.enabled.contains(tab)).toList();

    return Scaffold(
      appBar: FrostedAppBar(title: const Text('底部导航')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '长按条目拖动，调整底栏从左到右的顺序。至少保留一项。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              ref.read(navTabsProvider.notifier).reorder(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final tab = visible[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(tab),
                index: index,
                child: ListTile(
                  leading: Icon(tab.icon),
                  title: Text(tab.label),
                  subtitle: Text('第 ${index + 1} 项'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: true,
                        onChanged: (_) async {
                          if (visible.length <= 1) {
                            showMessage(context, '至少保留一个底栏入口');
                            return;
                          }
                          await ref.read(navTabsProvider.notifier).toggle(tab, false);
                        },
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (hidden.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('未显示在底栏', style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final tab in hidden)
              ListTile(
                leading: Icon(tab.icon),
                title: Text(tab.label),
                subtitle: const Text('打开后会出现在底栏末尾'),
                trailing: Switch(
                  value: false,
                  onChanged: (_) {
                    ref.read(navTabsProvider.notifier).toggle(tab, true);
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
