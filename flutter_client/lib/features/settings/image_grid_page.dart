import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/image_grid.dart';

class ImageGridPage extends ConsumerWidget {
  const ImageGridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageGridProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('图床显示')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('显示名称'),
            subtitle: const Text('叠在图片底部，默认关闭'),
            value: settings.showNames,
            onChanged: (value) {
              ref.read(imageGridProvider.notifier).setShowNames(value);
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('每行数量'),
            subtitle: Text('当前 ${settings.columns} 张'),
          ),
          Slider(
            min: imageGridMinColumns.toDouble(),
            max: imageGridMaxColumns.toDouble(),
            divisions: imageGridMaxColumns - imageGridMinColumns,
            value: settings.columns.toDouble(),
            label: '${settings.columns}',
            onChanged: (value) {
              ref.read(imageGridProvider.notifier).setColumns(value.round());
            },
          ),
        ],
      ),
    );
  }
}
