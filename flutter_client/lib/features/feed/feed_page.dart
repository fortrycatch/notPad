import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/media.dart';
import '../../models/models.dart';
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
          final rows = _feedRows(data.items);
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 240) {
                ref.read(timelineProvider.notifier).loadMore();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => ref.read(timelineProvider.notifier).refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: rows.length + (data.loadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= rows.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return switch (rows[index]) {
                    _DayHeader(:final label) => Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    _FeedEntry(:final item) => _FeedCard(item: item),
                  };
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

sealed class _FeedRow {
  const _FeedRow();
}

class _DayHeader extends _FeedRow {
  const _DayHeader(this.label);
  final String label;
}

class _FeedEntry extends _FeedRow {
  const _FeedEntry(this.item);
  final TimelineItem item;
}

List<_FeedRow> _feedRows(List<TimelineItem> items) {
  final rows = <_FeedRow>[];
  String? lastDay;
  for (final item in items) {
    final day = formatDayLabel(item.createdAt);
    if (day != lastDay) {
      rows.add(_DayHeader(day));
      lastDay = day;
    }
    rows.add(_FeedEntry(item));
  }
  return rows;
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = _FeedKind.of(item);
    final preview = kind.preview;
    final meta = kind.meta;
    final imageUrl = kind.imageUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => openTimelineItem(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null)
              SizedBox(
                height: 168,
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl(imageUrl, width: 720),
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(kind.icon, size: 40, color: kind.color(theme)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl == null) ...[
                    _TypeTile(kind: kind),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _TypeChip(kind: kind),
                            const Spacer(),
                            Text(
                              formatRelativeTime(item.createdAt),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.name.isEmpty ? kind.emptyTitle : item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.kind});

  final _FeedKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = kind.color(theme);
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: kind.fileExt == null
          ? Icon(kind.icon, color: color)
          : Text(
              kind.fileExt!,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.kind});

  final _FeedKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = kind.color(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            kind.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedKind {
  const _FeedKind({
    required this.label,
    required this.icon,
    required this.emptyTitle,
    required this.color,
    this.preview = '',
    this.meta = '',
    this.imageUrl,
    this.fileExt,
  });

  final String label;
  final IconData icon;
  final String emptyTitle;
  final Color Function(ThemeData theme) color;
  final String preview;
  final String meta;
  final String? imageUrl;
  final String? fileExt;

  factory _FeedKind.of(TimelineItem item) {
    return switch (item.type) {
      'note' => _FeedKind(
          label: '笔记',
          icon: Icons.sticky_note_2_outlined,
          emptyTitle: '未命名笔记',
          color: (theme) => theme.colorScheme.primary,
          preview: _plainText(item.summary),
        ),
      'image' => _FeedKind(
          label: '图片',
          icon: Icons.image_outlined,
          emptyTitle: '未命名图片',
          color: (theme) => theme.colorScheme.tertiary,
          meta: item.size > 0 ? formatBytes(item.size) : '',
          imageUrl: item.url,
        ),
      'file' => _FeedKind(
          label: '文件',
          icon: Icons.insert_drive_file_outlined,
          emptyTitle: '未命名文件',
          color: (theme) => theme.colorScheme.secondary,
          preview: _mimeLabel(item.summary),
          meta: [
            if (item.size > 0) formatBytes(item.size),
          ].join(' · '),
          fileExt: _fileExt(item.name),
        ),
      'bookmark' => _FeedKind(
          label: _bookmarkLabel(item.bookmarkSubtype),
          icon: switch (item.bookmarkSubtype) {
            'note' => Icons.sticky_note_2_outlined,
            'image' => Icons.image_outlined,
            'file' => Icons.insert_drive_file_outlined,
            _ => Icons.bookmark_outline,
          },
          emptyTitle: '未命名书签',
          color: (theme) => theme.colorScheme.primary,
          preview: _plainText(item.summary),
          meta: _urlHost(item.url) ?? '',
          imageUrl: _isDirectImageUrl(item.url) ? item.url : null,
        ),
      _ => _FeedKind(
          label: item.type,
          icon: Icons.article_outlined,
          emptyTitle: '未命名',
          color: (theme) => theme.colorScheme.outline,
          preview: _plainText(item.summary),
        ),
    };
  }
}

String _plainText(String raw) {
  return raw
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (match) => match[1] ?? '')
      .replaceAll(RegExp(r'[#*_`>~]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _mimeLabel(String mime) {
  if (mime.isEmpty) return '';
  if (mime.startsWith('image/')) return '图片文件';
  if (mime.startsWith('video/')) return '视频';
  if (mime.startsWith('audio/')) return '音频';
  if (mime.contains('pdf')) return 'PDF';
  if (mime.contains('zip') || mime.contains('compressed')) return '压缩包';
  if (mime.contains('word') || mime.endsWith('document')) return '文档';
  if (mime.contains('sheet') || mime.contains('excel')) return '表格';
  return mime;
}

String? _fileExt(String name) {
  final index = name.lastIndexOf('.');
  if (index < 0 || index == name.length - 1) return null;
  final ext = name.substring(index + 1).toUpperCase();
  if (ext.length > 5) return null;
  return ext;
}

bool _isDirectImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final lower = url.toLowerCase();
  const exts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'];
  return exts.any(lower.contains);
}

String _bookmarkLabel(String? subtype) {
  return switch (subtype) {
    'note' => '书签 · 笔记',
    'image' => '书签 · 图片',
    'file' => '书签 · 文件',
    'url' => '书签 · 链接',
    _ => '书签',
  };
}

String? _urlHost(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  return uri.host;
}
