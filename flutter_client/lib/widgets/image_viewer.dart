import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../core/media.dart';

class ImageViewerArgs {
  const ImageViewerArgs({required this.url, this.title});

  final String url;
  final String? title;
}

class ZoomableImage extends StatelessWidget {
  const ZoomableImage({
    super.key,
    required this.url,
    this.heroTag,
    this.backgroundColor,
  });

  final String url;
  final Object? heroTag;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMediaUrl(url);
    return PhotoView(
      imageProvider: CachedNetworkImageProvider(imageUrl),
      heroAttributes: heroTag == null ? null : PhotoViewHeroAttributes(tag: heroTag!),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      ),
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title ?? '图片'),
      ),
      body: ZoomableImage(
        url: url,
        backgroundColor: Colors.black,
      ),
    );
  }
}
