import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/nav_tabs.dart';
import '../../widgets/widgets.dart';

class NavTabsPage extends ConsumerWidget {
  const NavTabsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navTabsProvider);
    return Scaffold(
      appBar: FrostedAppBar(title: const Text('底部导航')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '选择显示在底部的页面，长按拖动调整顺序。至少保留一项。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: nav.order.length,
              onReorder: (oldIndex, newIndex) {
                ref.read(navTabsProvider.notifier).reorder(oldIndex, newIndex);
              },
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                final tab = nav.order[index];
                final enabled = nav.enabled.contains(tab);
                return ListTile(
                  key: ValueKey(tab),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text(tab.label),
                  subtitle: enabled ? const Text('显示在底栏') : const Text('仅侧边栏'),
                  trailing: Switch(
                    value: enabled,
                    onChanged: (value) async {
                      if (!value && nav.enabled.length <= 1) {
                        showMessage(context, '至少保留一个底栏入口');
                        return;
                      }
                      await ref.read(navTabsProvider.notifier).toggle(tab, value);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
