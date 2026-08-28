import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/lists.dart';
import '../../providers/session.dart';
import '../../widgets/widgets.dart';
import '../home/app_drawer.dart';

class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  String _sort = 'time_desc';
  String _search = '';
  int? _tagId;
  String? _type;
  final _searchController = TextEditingController();

  BookmarksQuery get _query => BookmarksQuery(
        sort: _sort,
        search: _search,
        tagId: _tagId,
        type: _type,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookmarksProvider(_query));
    final tags = ref.watch(bookmarkTagsProvider);
    final canEdit = ref.watch(sessionProvider).canEdit;
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('书签'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'tags') {
                context.push('/bookmarks/tags');
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
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => context.push('/bookmarks/create'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _searchController,
              hintText: '搜索书签',
              leading: const Icon(Icons.search),
              onSubmitted: (value) => setState(() => _search = value.trim()),
              trailing: [
                if (_search.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip(null, '全部类型', _type == null, () => setState(() => _type = null)),
                _chip('url', '链接', _type == 'url', () => setState(() => _type = 'url')),
                _chip('note', '笔记', _type == 'note', () => setState(() => _type = 'note')),
                _chip('image', '图片', _type == 'image', () => setState(() => _type = 'image')),
                _chip('file', '文件', _type == 'file', () => setState(() => _type = 'file')),
              ],
            ),
          ),
          if (tags.hasValue && tags.requireValue.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('全部标签'),
                      selected: _tagId == null,
                      onSelected: (_) => setState(() => _tagId = null),
                    ),
                  ),
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
              onRetry: () => ref.read(bookmarksProvider(_query).notifier).refresh(),
              builder: (data) {
                if (data.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(bookmarksProvider(_query).notifier).refresh(),
                    child: ListView(
                      children: const [
                        SizedBox(height: 160),
                        EmptyView(icon: Icons.bookmark_outline, message: '还没有书签'),
                      ],
                    ),
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 240) {
                      ref.read(bookmarksProvider(_query).notifier).loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => ref.read(bookmarksProvider(_query).notifier).refresh(),
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
                          leading: Icon(typeIcon(item.type)),
                          title: Text(item.title),
                          subtitle: Text(
                            [
                              formatDateTime(item.createdAt),
                              if (item.description.isNotEmpty) item.description,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => context.push('/bookmarks/${item.id}'),
                          onLongPress: () => _actions(item),
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

  Widget _chip(String? value, String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }

  Future<void> _actions(Bookmark item) async {
    final canEdit = ref.read(sessionProvider).canEdit;
    await showActions(context, [
      SheetAction(
        icon: Icons.open_in_new,
        label: '打开',
        onTap: () => context.push('/bookmarks/${item.id}'),
      ),
      if (canEdit)
        SheetAction(
          icon: Icons.delete_outline,
          label: '删除',
          destructive: true,
          onTap: () => _delete(item.id),
        ),
    ]);
  }

  Future<void> _delete(int id) async {
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
      ref.invalidate(bookmarksProvider(_query));
      if (mounted) showMessage(context, '已删除');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }
}
