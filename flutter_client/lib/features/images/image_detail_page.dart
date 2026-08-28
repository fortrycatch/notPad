import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/media.dart';
import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/widgets.dart';

class ImageDetailPage extends ConsumerStatefulWidget {
  const ImageDetailPage({super.key, required this.id, this.initial});

  final int id;
  final BedImage? initial;

  @override
  ConsumerState<ImageDetailPage> createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends ConsumerState<ImageDetailPage> {
  BedImage? _image;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _image = widget.initial;
    if (_image == null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cached = ref.read(imagesProvider(const ImagesQuery())).valueOrNull?.items;
      final hit = cached?.where((item) => item.id == widget.id).firstOrNull;
      if (hit != null) {
        setState(() => _image = hit);
        return;
      }
      final userId = ref.read(sessionProvider).user?.id ?? '';
      for (var page = 0; page < 8; page++) {
        final items = await ref.read(apiProvider).imageBed.list(
              userId: userId,
              offset: page,
            );
        final found = items.where((item) => item.id == widget.id).firstOrNull;
        if (found != null) {
          if (mounted) setState(() => _image = found);
          return;
        }
        if (items.length < pageSize) break;
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final canEdit = ref.watch(sessionProvider).canEdit;

    if (image == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('图片')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyView(icon: Icons.broken_image_outlined, message: '找不到图片'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(image.name),
        actions: [
          IconButton(
            tooltip: '全屏查看',
            onPressed: () => context.push(
              '/viewer',
              extra: ImageViewerArgs(url: image.url, title: image.name),
            ),
            icon: const Icon(Icons.fullscreen),
          ),
          IconButton(
            tooltip: '收藏',
            onPressed: () => _toggleBookmark(image),
            icon: const Icon(Icons.star_outline),
          ),
          IconButton(
            tooltip: '标签',
            onPressed: () => context.push('/images/tags', extra: image.id),
            icon: const Icon(Icons.label_outline),
          ),
          if (canEdit)
            IconButton(
              onPressed: () => _rename(image),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ZoomableImage(url: image.url),
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
        ],
      ),
    );
  }

  Future<void> _rename(BedImage image) async {
    final name = await promptText(context, title: '重命名', initial: image.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).imageBed.rename(image.id, name.trim());
      ref.invalidate(imagesProvider(const ImagesQuery()));
      if (mounted) {
        setState(() {
          _image = BedImage(
            id: image.id,
            name: name.trim(),
            url: image.url,
            size: image.size,
            userId: image.userId,
            createdAt: image.createdAt,
            remark: image.remark,
          );
        });
        showMessage(context, '已重命名');
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _toggleBookmark(BedImage image) async {
    try {
      final api = ref.read(apiProvider);
      final state = await api.bookmark.isBookmarked(type: 'image', refId: '${image.id}');
      if (state.bookmarked && state.id != null) {
        await api.bookmark.remove(state.id!);
        if (mounted) showMessage(context, '已取消收藏');
      } else {
        await api.bookmark.add(
          type: 'image',
          title: image.name,
          url: resolveMediaUrl(image.url),
          refId: '${image.id}',
        );
        if (mounted) showMessage(context, '已收藏');
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}
