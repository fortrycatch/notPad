import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class ImageDetailPage extends ConsumerWidget {
  const ImageDetailPage({super.key, required this.id, this.initial});

  final int id;
  final BedImage? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(imagesProvider(const ImagesQuery()));
    final image = initial ??
        query.valueOrNull?.items.where((item) => item.id == id).firstOrNull;
    final canEdit = ref.watch(sessionProvider).canEdit;

    if (image == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('图片')),
        body: query.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyView(icon: Icons.broken_image_outlined, message: '找不到图片'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(image.name),
        actions: [
          IconButton(
            tooltip: '收藏',
            onPressed: () => _toggleBookmark(context, ref, image),
            icon: const Icon(Icons.star_outline),
          ),
          IconButton(
            tooltip: '标签',
            onPressed: () => context.push('/images/tags', extra: image.id),
            icon: const Icon(Icons.label_outline),
          ),
          if (canEdit)
            IconButton(
              onPressed: () => _rename(context, ref, image),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: image.url,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 64),
            ),
          ),
          ListTile(
            title: const Text('大小'),
            subtitle: Text(formatBytes(image.size)),
          ),
          ListTile(
            title: const Text('时间'),
            subtitle: Text(formatDateTime(image.createdAt)),
          ),
          if (image.remark.isNotEmpty)
            ListTile(
              title: const Text('备注'),
              subtitle: Text(image.remark),
            ),
          ListTile(
            title: const Text('打开原图'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(Uri.parse(image.url), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, BedImage image) async {
    final name = await promptText(context, title: '重命名', initial: image.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).imageBed.rename(image.id, name.trim());
      ref.invalidate(imagesProvider(const ImagesQuery()));
      if (context.mounted) showMessage(context, '已重命名');
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _toggleBookmark(BuildContext context, WidgetRef ref, BedImage image) async {
    try {
      final api = ref.read(apiProvider);
      final state = await api.bookmark.isBookmarked(type: 'image', refId: '${image.id}');
      if (state.bookmarked && state.id != null) {
        await api.bookmark.remove(state.id!);
        if (context.mounted) showMessage(context, '已取消收藏');
      } else {
        await api.bookmark.add(
          type: 'image',
          title: image.name,
          url: image.url,
          refId: '${image.id}',
        );
        if (context.mounted) showMessage(context, '已收藏');
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
