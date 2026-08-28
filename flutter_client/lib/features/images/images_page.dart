import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../core/media.dart';
import '../../models/models.dart';
import '../../providers/image_grid.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/list_toolbar.dart';
import '../../widgets/widgets.dart';
import '../home/app_drawer.dart';

class ImagesPage extends ConsumerStatefulWidget {
  const ImagesPage({super.key});

  @override
  ConsumerState<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends ConsumerState<ImagesPage> {
  String _sort = 'time_desc';
  String _search = '';
  int? _tagId;
  bool _searching = false;
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
    final grid = ref.watch(imageGridProvider);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: ListSearchAppBar(
        title: '图床',
        leading: const DrawerMenuButton(),
        searching: _searching,
        searchController: _searchController,
        searchHint: '搜索图片',
        searchActive: _search.isNotEmpty,
        filterActive: _tagId != null,
        onSearch: (value) => setState(() => _search = value),
        onOpenSearch: () => setState(() => _searching = true),
        onCloseSearch: () => setState(() {
          _searching = false;
          _search = _searchController.text.trim();
        }),
        onFilter: () => _showFilters(tags.valueOrNull ?? const []),
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
          ? ShellFab(
              child: FloatingActionButton(
                heroTag: 'images-fab',
                tooltip: '上传图片',
                onPressed: _uploading ? null : _upload,
                child: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
              ),
            )
          : null,
      body: AsyncBody(
        value: async,
        onRetry: () => ref.read(imagesProvider(_query).notifier).refresh(),
        builder: (data) {
          if (data.items.isEmpty) {
            return EmptyView(
              icon: Icons.image_outlined,
              message: _search.isNotEmpty || _tagId != null ? '没有符合条件的图片' : '还没有图片',
            );
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
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top,
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: grid.columns,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                ),
                itemCount: data.items.length,
                itemBuilder: (context, index) {
                  final image = data.items[index];
                  return _ImageTile(
                    image: image,
                    showName: grid.showNames,
                    onTap: () => context.push('/images/${image.id}', extra: image),
                    onLongPress: () => _actions(image),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showFilters(List<TagItem> tags) {
    return showListFilterSheet(
      context: context,
      title: '筛选图片',
      canClear: _tagId != null,
      onReset: () => setState(() => _tagId = null),
      content: (context, refresh) {
        if (tags.isEmpty) {
          return Text('还没有标签', style: Theme.of(context).textTheme.bodyMedium);
        }
        return FilterChipWrap(
          children: [
            FilterChip(
              label: const Text('全部'),
              selected: _tagId == null,
              onSelected: (_) {
                setState(() => _tagId = null);
                refresh();
              },
            ),
            for (final tag in tags)
              FilterChip(
                label: Text(tag.name),
                selected: _tagId == tag.id,
                onSelected: (_) {
                  setState(() => _tagId = tag.id);
                  refresh();
                },
              ),
          ],
        );
      },
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

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.image,
    required this.showName,
    required this.onTap,
    required this.onLongPress,
  });

  final BedImage image;
  final bool showName;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: thumbnailUrl(image.url, width: 480),
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image),
            ),
          ),
          if (showName && image.name.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 20, 6, 6),
                  child: Text(
                    image.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(blurRadius: 6, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
