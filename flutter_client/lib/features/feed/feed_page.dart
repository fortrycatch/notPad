import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../providers/lists.dart';
import '../../widgets/widgets.dart';
import '../home/app_drawer.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timelineProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('动态'),
      ),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.read(timelineProvider.notifier).refresh(),
        builder: (data) {
          if (data.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(timelineProvider.notifier).refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 160),
                  EmptyView(icon: Icons.dynamic_feed_outlined, message: '还没有动态'),
                ],
              ),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 240) {
                ref.read(timelineProvider.notifier).loadMore();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => ref.read(timelineProvider.notifier).refresh(),
              child: ListView.separated(
                itemCount: data.items.length + (data.loadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= data.items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final item = data.items[index];
                  return ListTile(
                    leading: CircleAvatar(child: Icon(typeIcon(item.type))),
                    title: Text(item.name.isEmpty ? '未命名' : item.name),
                    subtitle: Text(
                      [
                        _typeLabel(item.type),
                        formatDateTime(item.createdAt),
                        if (item.summary.isNotEmpty) item.summary,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => openTimelineItem(context, item),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'note':
        return '笔记';
      case 'image':
        return '图片';
      case 'file':
        return '文件';
      case 'bookmark':
        return '书签';
      default:
        return type;
    }
  }
}
