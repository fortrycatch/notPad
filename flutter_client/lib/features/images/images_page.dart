import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';

class ImagesPage extends ConsumerStatefulWidget {
  const ImagesPage({super.key});

  @override
  ConsumerState<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends ConsumerState<ImagesPage> {
  String _sort = 'time_desc';
  String _search = '';
  int? _tagId;
  final _searchController = TextEditingController();
  bool _uploading = false;

  ImagesQuery get _query => ImagesQuery(sort: _sort, search: _search, tagId: _tagId);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(imagesProvider(_query));
    final tags = ref.watch(imageTagsProvider);
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      appBar: AppBar(
        title: const Text('图床'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'tags') {
                context.push('/images/tags');
                return;
              }
              setState(() => _sort = value);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'time_desc', child: Text('最新')),
              PopupMenuItem(value: 'time', child: Text('最早')),
              PopupMenuItem(value: 'name', child: Text('名称')),
              PopupMenuItem(value: 'tags', child: Text('管理标签')),
            ],
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: '搜索图片',
              leading: const Icon(Icons.search),
              onSubmitted: (value) => setState(() => _search = value.trim()),
            ),
          ),
          if (tags.hasValue && tags.requireValue.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  FilterChip(
                    label: const Text('全部'),
                    selected: _tagId == null,
                    onSelected: (_) => setState(() => _tagId = null),
                  ),
                  const SizedBox(width: 8),
                  for (final tag in tags.requireValue)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag.name),
                        selected: _tagId == tag.id,
                        onSelected: (_) => setState(() => _tagId = tag.id),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: AsyncBody(
              value: async,
              onRetry: () => ref.read(imagesProvider(_query).notifier).refresh(),
              builder: (data) {
                if (data.items.isEmpty) {
                  return const EmptyView(icon: Icons.image_outlined, message: '还没有图片');
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 240) {
                      ref.read(imagesProvider(_query).notifier).loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => ref.read(imagesProvider(_query).notifier).refresh(),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: data.items.length,
                      itemBuilder: (context, index) {
                        final image = data.items[index];
                        return InkWell(
                          onTap: () => context.push('/images/${image.id}', extra: image),
                          onLongPress: () => _actions(image),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: CachedNetworkImage(
                                    imageUrl: image.url,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => const Icon(Icons.broken_image),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    image.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upload() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final mime = lookupMimeType(picked.name, headerBytes: bytes) ?? 'image/jpeg';
      final api = ref.read(apiProvider);
      final slot = await api.imageBed.getUploadUrl(filename: picked.name, type: mime);
      await api.uploadBytes(url: slot.url, bytes: bytes, contentType: mime);
      await api.imageBed.addImage(name: picked.name, filename: slot.filename);
      ref.invalidate(imagesProvider(_query));
      ref.invalidate(timelineProvider);
      if (mounted) showMessage(context, '上传完成');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _actions(BedImage image) async {
    final canEdit = ref.read(sessionProvider).canEdit;
    await showActions(context, [
      SheetAction(
        icon: Icons.open_in_new,
        label: '打开',
        onTap: () => context.push('/images/${image.id}', extra: image),
      ),
      if (canEdit)
        SheetAction(
          icon: Icons.edit_outlined,
          label: '重命名',
          onTap: () => _rename(image),
        ),
    ]);
  }

  Future<void> _rename(BedImage image) async {
    final name = await promptText(context, title: '重命名', initial: image.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(apiProvider).imageBed.rename(image.id, name.trim());
      ref.invalidate(imagesProvider(_query));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}
