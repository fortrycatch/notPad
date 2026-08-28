import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/widgets.dart';

class BookmarkDetailPage extends ConsumerWidget {
  const BookmarkDetailPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookmarkProvider(id));
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      appBar: FrostedAppBar(
        title: const Text('书签'),
        actions: [
          IconButton(
            tooltip: '标签',
            onPressed: () => context.push('/bookmarks/tags', extra: id),
            icon: const Icon(Icons.label_outline),
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(bookmarkProvider(id)),
        builder: (item) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${_typeLabel(item.type)} · ${formatDateTime(item.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(item.description),
              ],
              if (item.url.isNotEmpty) ...[
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: Text(item.url),
                  onTap: () => launchUrl(
                    Uri.parse(item.url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
              if (item.type == 'image' && item.url.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: ZoomableImage(url: item.url),
                ),
              ],
              if (item.refId != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => _openRef(context, item),
                  child: const Text('打开原内容'),
                ),
              ],
              if (item.content != null && item.content!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('正文', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SelectableText(item.content!),
              ],
            ],
          );
        },
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'url':
        return '链接';
      case 'note':
        return '笔记';
      case 'image':
        return '图片';
      case 'file':
        return '文件';
      default:
        return type;
    }
  }

  void _openRef(BuildContext context, Bookmark item) {
    final refId = item.refId;
    if (refId == null) return;
    switch (item.type) {
      case 'note':
        context.push('/notes/$refId');
      case 'image':
        context.push(
          '/images/$refId',
          extra: BedImage(
            id: int.tryParse(refId) ?? 0,
            name: item.title,
            url: item.url,
            size: 0,
            userId: item.userId,
            createdAt: item.createdAt,
            remark: '',
          ),
        );
      case 'file':
        context.push('/drive/files/$refId');
      default:
        break;
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: '删除书签',
      message: '删除后无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).bookmark.remove(id);
      if (context.mounted) {
        showMessage(context, '已删除');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
